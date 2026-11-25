"""Authenticated loopback daemon. HTTP/notification activity cannot arm the game."""
import asyncio
import contextlib
import ipaddress
import json
import secrets
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict

from .controller import BridgeController
from .notifications import NotificationDispatcher, RoastRequest
from .transports import MockTransport, PhysicalTransport


class LocalAction(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    confirm: bool


def is_loopback(host):
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def create_app(settings, *, controller=None):
    kind = settings.transport.split("-", 1)[1]
    adapter = MockTransport(kind) if settings.transport.startswith("mock-") else PhysicalTransport(kind)
    control = controller if controller is not None else BridgeController(adapter)
    dispatcher = NotificationDispatcher(settings)
    active_socket = None

    async def watchdog():
        while True:
            try:
                control.tick()
            except Exception:
                control.trip("transport-error")
            await asyncio.sleep(0.01)

    @asynccontextmanager
    async def lifespan(_app):
        task = asyncio.create_task(watchdog())
        try:
            yield
        finally:
            control.disconnect()
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
            await dispatcher.close()

    app = FastAPI(lifespan=lifespan, docs_url=None, redoc_url=None)
    app.state.controller = control
    app.state.dispatcher = dispatcher

    def valid_token(value, expected):
        return isinstance(expected, str) and isinstance(value, str) and value.isascii() and len(value) <= 263 and secrets.compare_digest(value, "Bearer " + expected)

    def authorize_telemetry(authorization: str | None = Header(default=None)):
        if not valid_token(authorization, settings.token):
            raise HTTPException(401, "Telemetry authentication required")

    def authorize_operator(authorization: str | None = Header(default=None)):
        if not valid_token(authorization, settings.operator_token):
            raise HTTPException(401, "Separate local operator authentication required")

    def authorize_any(authorization: str | None = Header(default=None)):
        if not (valid_token(authorization, settings.token) or valid_token(authorization, settings.operator_token)):
            raise HTTPException(401, "Authentication required")

    def local_action(request, action=None):
        if request.client is None or not is_loopback(request.client.host):
            raise HTTPException(403, "Only a local action is allowed")
        if action is not None and not action.confirm:
            raise HTTPException(400, "Explicit local action required")

    @app.get("/api/v1/status", dependencies=[Depends(authorize_any)])
    async def status():
        return dict(armed=control.armed, fault=control.fault, outputs=control.outputs, transport=settings.transport, physical_operation=False)

    @app.post("/api/v1/arm", dependencies=[Depends(authorize_operator)])
    async def arm(request: Request, action: LocalAction):
        local_action(request, action)
        if not control.arm():
            raise HTTPException(409, "Fresh healthy telemetry and verified mock safeguards required")
        return dict(armed=True)

    @app.post("/api/v1/disarm", dependencies=[Depends(authorize_operator)])
    async def disarm(request: Request):
        local_action(request)
        control.trip("explicit-local-disarm")
        return dict(armed=False)

    @app.post("/api/v1/estop", dependencies=[Depends(authorize_operator)])
    async def estop(request: Request):
        local_action(request)
        control.emergency_stop()
        return dict(armed=False)

    @app.post("/api/v1/estop/clear", dependencies=[Depends(authorize_operator)])
    async def clear_estop(request: Request, action: LocalAction):
        local_action(request, action)
        control.clear_estop()
        return dict(armed=False, requires_fresh_frame=True)

    @app.post("/api/v1/psyops/roast", dependencies=[Depends(authorize_telemetry)])
    async def private_alert(body: RoastRequest):
        result = await dispatcher.dispatch(body)
        return JSONResponse(result, status_code=202 if result["status"] == "sent" else 200)

    @app.websocket("/api/v1/telemetry")
    async def telemetry(socket: WebSocket):
        nonlocal active_socket
        if not valid_token(socket.headers.get("authorization"), settings.token) or socket.client is None or not is_loopback(socket.client.host) or active_socket is not None:
            await socket.close(code=1008)
            return
        active_socket = socket  # Reserve ownership before accepting another connection.
        try:
            await socket.accept()
            control.connect()
            await socket.send_json(dict(transport=settings.transport, armed=False, protocol=1))
            while True:
                message = await socket.receive()
                if message["type"] == "websocket.disconnect":
                    return
                raw = message.get("text")
                if not isinstance(raw, str):
                    control.trip("malformed-frame")
                    await socket.send_json(dict(ok=False, armed=False, fault=control.fault))
                    continue
                if len(raw.encode()) > 4096:
                    control.trip("oversized-frame")
                    await socket.close(code=1009)
                    return
                try:
                    packet = json.loads(raw)
                    accepted = control.ingest(packet)
                except (ValueError, TypeError):
                    accepted = control.trip("malformed-frame")
                await socket.send_json(dict(ok=accepted, armed=control.armed, fault=control.fault))
        except (WebSocketDisconnect, RuntimeError):
            pass
        finally:
            if active_socket is socket:
                active_socket = None
                control.disconnect()

    return app
