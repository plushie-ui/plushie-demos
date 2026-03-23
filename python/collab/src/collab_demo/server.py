"""Combined server entry point for the collaborative demo.

Starts both an SSH server (port 2222) and a WebSocket + HTTP server
(port 8080) sharing a single SharedState. All connected clients --
whether native desktop over SSH or browser over WebSocket -- see the
same counter, name, and notes in real time.
"""

from __future__ import annotations

import asyncio
import logging
import mimetypes
import os
from pathlib import Path
from typing import Any

import websockets
from websockets.datastructures import Headers
from websockets.http11 import Request, Response

from collab_demo.collab import Collab
from collab_demo.shared import SharedState
from collab_demo.ssh_handler import start_ssh_server
from collab_demo.ws_handler import handle_ws

logger = logging.getLogger(__name__)


def _find_static_dir() -> str:
    """Locate the static/ directory relative to the package."""
    # Check relative to this file first (development layout)
    here = Path(__file__).resolve().parent.parent.parent / "static"
    if here.is_dir():
        return str(here)
    # Fallback: current working directory
    cwd = Path.cwd() / "static"
    if cwd.is_dir():
        return str(cwd)
    return str(here)


def _serve_static(request: Request, static_dir: str) -> Response | None:
    """Serve static files for non-WebSocket HTTP requests.

    Returns a Response for static file requests, or None to let
    websockets proceed with the WebSocket handshake for /ws.

    Args:
        request: The incoming HTTP request.
        static_dir: Path to the static file directory.

    Returns:
        An HTTP response for static files, or None for WebSocket paths.
    """
    path = request.path

    # Let /ws proceed to the WebSocket handler
    if path == "/ws":
        return None

    if path == "/":
        path = "/index.html"

    file_path = os.path.join(static_dir, path.lstrip("/"))
    file_path = os.path.realpath(file_path)

    # Security: ensure we stay within static_dir
    if not file_path.startswith(os.path.realpath(static_dir)):
        return Response(403, "Forbidden", Headers())

    if os.path.isfile(file_path):
        content_type, _ = mimetypes.guess_type(file_path)
        if content_type is None:
            content_type = "application/octet-stream"

        with open(file_path, "rb") as f:
            body = f.read()

        headers = Headers([("Content-Type", content_type)])
        return Response(200, "OK", headers, body)

    return Response(404, "Not Found", Headers())


async def start_ws_server(
    shared: SharedState,
    *,
    port: int = 8080,
    static_dir: str | None = None,
) -> Any:
    """Start the WebSocket + HTTP server.

    Args:
        shared: The shared state server.
        port: TCP port to listen on.
        static_dir: Path to static file directory.

    Returns:
        The websockets server object.
    """
    if static_dir is None:
        static_dir = _find_static_dir()

    resolved_static_dir = static_dir

    async def handler(ws: Any) -> None:
        """Handle WebSocket connections to /ws."""
        await handle_ws(ws, shared)

    def process_request(
        connection: Any,  # noqa: ARG001
        request: Request,
    ) -> Response | None:
        """Intercept HTTP requests to serve static files."""
        return _serve_static(request, resolved_static_dir)

    return await websockets.serve(  # type: ignore[attr-defined]
        handler,
        "127.0.0.1",
        port,
        process_request=process_request,
    )


async def main() -> None:
    """Entry point: start SSH + WebSocket servers and run forever."""
    logging.basicConfig(level=logging.INFO)

    app = Collab()
    shared = SharedState(app)

    # Start SSH server on port 2222
    await start_ssh_server(shared, port=2222)

    # Start WebSocket + HTTP server on port 8080
    await start_ws_server(shared, port=8080)

    print("SSH server on localhost:2222")
    print("WebSocket server on http://localhost:8080")
    print("Open http://localhost:8080/websocket.html in a browser")

    await asyncio.Event().wait()  # run forever


if __name__ == "__main__":
    asyncio.run(main())
