"""WebSocket connection handler for the collaborative demo.

Each WebSocket connection registers with the SharedState server,
decodes incoming JSON wire messages, and forwards events. Model
changes are broadcast back as JSON snapshots.

The dark_mode toggle is handled locally (per-client, not shared).
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

from plushie import protocol, tree
from plushie.events import Toggle
from plushie.types import HelloInfo

from collab_demo.collab import Collab, Model
from collab_demo.shared import SharedState

logger = logging.getLogger(__name__)

_client_counter = 0


def _next_client_id() -> str:
    global _client_counter
    _client_counter += 1
    return f"ws-{_client_counter}"


def _encode_snapshot(model: Model) -> str:
    """Render the model to a view tree, normalize, and encode as JSON."""
    app = Collab()
    raw_tree = app.view(model)
    normalized = tree.normalize(raw_tree)
    msg = protocol.snapshot(normalized)
    return json.dumps(msg, separators=(",", ":"), ensure_ascii=False)


async def handle_ws(ws: Any, shared: SharedState) -> None:
    """Handle a single WebSocket connection lifecycle.

    Args:
        ws: The websockets connection object.
        shared: The shared state server.
    """
    import websockets

    client_id = _next_client_id()
    dark_mode = False
    last_model = Collab().init()
    loop = asyncio.get_running_loop()

    # Queue for model updates from the shared state broadcast thread
    queue: asyncio.Queue[Any] = asyncio.Queue()

    def on_model_changed(model: Any) -> None:
        """Called from SharedState (possibly from another thread)."""
        loop.call_soon_threadsafe(queue.put_nowait, model)

    shared.connect(client_id, on_model_changed)

    async def send_snapshots() -> None:
        nonlocal last_model, dark_mode
        while True:
            model = await queue.get()
            last_model = model
            client_model = Model(
                name=model.name,
                notes=model.notes,
                count=model.count,
                dark_mode=dark_mode,
                status=model.status,
            )
            try:
                await ws.send(_encode_snapshot(client_model))
            except websockets.ConnectionClosed:
                return

    sender_task = asyncio.create_task(send_snapshots())

    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except (json.JSONDecodeError, TypeError):
                continue

            event = protocol.decode_message(msg)

            # Dark mode toggle: handle locally (per-client)
            if isinstance(event, Toggle) and event.id == "theme":
                dark_mode = event.value
                client_model = Model(
                    name=last_model.name,
                    notes=last_model.notes,
                    count=last_model.count,
                    dark_mode=dark_mode,
                    status=last_model.status,
                )
                await ws.send(_encode_snapshot(client_model))
                continue

            # Hello messages from WASM renderer
            if isinstance(event, HelloInfo):
                continue

            # Skip raw dicts (unrecognized message types)
            if isinstance(event, dict):
                continue

            # Forward everything else to shared state
            shared.handle_event(client_id, event)

    except Exception:
        logger.debug("WebSocket connection error", exc_info=True)
    finally:
        sender_task.cancel()
        shared.disconnect(client_id)
