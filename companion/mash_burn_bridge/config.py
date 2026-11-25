"""Explicit configuration only. Never loads .env files or prints credentials."""
import ipaddress
import json
import os
import re
from dataclasses import dataclass, field
from urllib.parse import urlsplit


@dataclass(frozen=True)
class Destination:
    url: str = field(repr=False)
    consent: bool = False
    private: bool = False

    def __post_init__(self):
        parsed = urlsplit(self.url)
        if len(self.url) > 2048 or (parsed.port is not None and not 1 <= parsed.port <= 65535):
            raise ValueError("Invalid private destination configuration")
        if parsed.username or parsed.password or parsed.fragment or not parsed.hostname:
            raise ValueError("Invalid private destination configuration")
        loopback = parsed.hostname == "localhost"
        try:
            loopback = loopback or ipaddress.ip_address(parsed.hostname).is_loopback
        except ValueError:
            pass
        if parsed.scheme != "https" and not (parsed.scheme == "http" and loopback):
            raise ValueError("Private destinations require HTTPS; HTTP is allowed only for loopback tests")
        if type(self.consent) is not bool or type(self.private) is not bool:
            raise ValueError("Consent and privacy flags must be explicit booleans")


@dataclass(frozen=True)
class Settings:
    token: str = field(repr=False)
    transport: str = "mock-serial"
    notifications_enabled: bool = False
    notification_consent: bool = False
    destinations: dict[str, Destination] = field(default_factory=dict, repr=False)
    rate_per_minute: int = 5

    def __post_init__(self):
        if not self.token.isascii() or not 32 <= len(self.token) <= 256 or any(ord(char) < 33 or ord(char) > 126 for char in self.token):
            raise ValueError("MAB_BRIDGE_TOKEN must contain32–256 characters")
        if self.transport not in {f"{mode}-{kind}" for mode in ("mock", "physical") for kind in ("serial", "mqtt", "websocket")}:
            raise ValueError("Unsupported transport configuration")
        if type(self.notifications_enabled) is not bool or type(self.notification_consent) is not bool:
            raise ValueError("Notification flags must be booleans")
        if type(self.rate_per_minute) is not int or not 1 <= self.rate_per_minute <= 10 or len(self.destinations) > 16:
            raise ValueError("Unbounded notification configuration")
        if any(not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", key) or not isinstance(value, Destination) for key, value in self.destinations.items()):
            raise ValueError("Invalid private destination allowlist")

    @classmethod
    def from_environment(cls):
        channels = json.loads(os.environ.get("MAB_PRIVATE_CHANNELS_JSON", "{}"))
        return cls(
            token=os.environ.get("MAB_BRIDGE_TOKEN", ""),
            transport=os.environ.get("MAB_TRANSPORT", "mock-serial"),
            notifications_enabled=os.environ.get("MAB_NOTIFICATIONS_ENABLED", "false") == "true",
            notification_consent=os.environ.get("MAB_NOTIFICATION_CONSENT", "false") == "true",
            destinations={name: Destination(**options) for name, options in channels.items()},
        )
