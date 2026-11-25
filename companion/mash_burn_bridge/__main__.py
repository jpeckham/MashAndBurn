import argparse

import uvicorn

from .app import create_app
from .config import Settings


def main():
    parser = argparse.ArgumentParser(description="Optional local Mash & Burn mock companion")
    parser.add_argument("--host", choices=["127.0.0.1", "::1"], default="127.0.0.1")
    parser.add_argument("--port", type=int, default=27842)
    options = parser.parse_args()
    if not 1024 <= options.port <= 65535:
        parser.error("Port must be1024–65535")
    uvicorn.run(create_app(Settings.from_environment()), host=options.host, port=options.port, ws_max_size=4096, access_log=False, log_level="warning")


if __name__ == "__main__":
    main()
