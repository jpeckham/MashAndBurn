"""Disabled-by-default private alerts; no public bot or account API integration."""
import asyncio
import time
from collections import defaultdict, deque
from typing import Annotated

import httpx
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field


class RoastRequest(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", allow_inf_nan=False)
    event_id: Annotated[str, Field(pattern=r"^[A-Za-z0-9._-]{1,64}$")]
    destination: Annotated[str, Field(pattern=r"^[A-Za-z0-9_-]{1,32}$")]
    beer_name: Annotated[str, Field(min_length=1, max_length=80)]
    score: Annotated[float, Field(ge=0, le=100)]
    flaws: Annotated[list[Annotated[str, Field(min_length=1, max_length=100)]], Field(max_length=16)]


class NotificationDispatcher:
    def __init__(self, settings, *, clock=time.monotonic):
        self.settings = settings
        self.clock = clock
        self.client = httpx.AsyncClient(timeout=2.0, follow_redirects=False, trust_env=False)
        self.seen = {}
        self.rate = defaultdict(deque)
        self.global_rate = deque()
        self.last_time = clock()

    async def close(self):
        await self.client.aclose()

    async def dispatch(self, request):
        cfg = self.settings
        destination = cfg.destinations.get(request.destination)
        if not cfg.notifications_enabled or not cfg.notification_consent or destination is None or not destination.consent or not destination.private:
            raise HTTPException(403, "Private notifications are disabled or not explicitly consented")
        now = self.clock()
        if now < self.last_time:
            raise HTTPException(503, "Notification clock unavailable")
        self.last_time = now
        self.seen = {key: item for key, item in self.seen.items() if now - item["at"] <= 3600}
        key = (request.destination, request.event_id)
        if key in self.seen:
            return dict(status="duplicate", previous=self.seen[key]["status"])
        channel = self.rate[request.destination]
        for history in (channel, self.global_rate):
            while history and now - history[0] >= 60:
                history.popleft()
        if len(channel) >= cfg.rate_per_minute or len(self.global_rate) >= 20 or len(self.seen) >= 1024:
            raise HTTPException(429, "Private notification rate/history limit reached")
        # Reserve before the first await: simultaneous duplicate callers cannot send twice.
        self.seen[key] = dict(at=now, status="pending")
        channel.append(now)
        self.global_rate.append(now)
        text = f"Fictional Mash & Burn tasting: {request.beer_name} scored {request.score:.1f}/100. " + "; ".join(request.flaws)
        payload = dict(event_id=request.event_id, text=text[:2000], fictional=True)
        for attempt in range(3):
            try:
                response = await self.client.post(destination.url, json=payload, headers={"Idempotency-Key": request.event_id})
                if 200 <= response.status_code < 300:
                    self.seen[key]["status"] = "sent"
                    return dict(status="sent", attempts=attempt + 1)
                if 300 <= response.status_code < 500:
                    break  # Redirects and client errors are never followed/retried.
            except httpx.HTTPError:
                pass
            if attempt < 2:
                await asyncio.sleep(0.02 * (attempt + 1))
        self.seen[key]["status"] = "failed"
        raise HTTPException(502, "Private delivery failed after bounded attempts")
