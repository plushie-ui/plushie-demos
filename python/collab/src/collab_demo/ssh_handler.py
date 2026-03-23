"""SSH subsystem handler for the collaborative demo.

Each SSH channel registers with the SharedState server, decodes
incoming msgpack wire messages (4-byte length-prefixed framing),
and forwards events. Model changes are broadcast back as framed
msgpack snapshots.

The protocol handshake is:
1. We send settings on channel open
2. Renderer replies with hello
3. We register with shared (which sends the first snapshot)

The dark_mode toggle is handled locally (per-client, not shared).
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

import asyncssh

from plushie import protocol, tree
from plushie.events import Toggle
from plushie.framing import MsgpackFraming
from plushie.types import HelloInfo

from collab_demo.collab import Collab, Model
from collab_demo.shared import SharedState

logger = logging.getLogger(__name__)

_client_counter = 0


def _next_client_id() -> str:
    global _client_counter
    _client_counter += 1
    return f"ssh-{_client_counter}"


def _encode_snapshot_bytes(model: Model) -> bytes:
    """Render the model to a view tree, normalize, and encode as framed msgpack."""
    app = Collab()
    raw_tree = app.view(model)
    normalized = tree.normalize(raw_tree)
    msg = protocol.snapshot(normalized)
    return MsgpackFraming.encode(msg)


def _encode_settings_bytes() -> bytes:
    """Build and frame the settings message."""
    msg = protocol.settings(
        {
            "antialiasing": True,
            "default_text_size": 16.0,
            "default_event_rate": 30,
        }
    )
    return MsgpackFraming.encode(msg)


class PlushieSubsystemSession(asyncssh.SSHServerSession[bytes]):  # type: ignore[misc]
    """SSH session handler speaking the plushie wire protocol."""

    def __init__(self, shared: SharedState) -> None:
        self._shared = shared
        self._client_id = _next_client_id()
        self._dark_mode = False
        self._handshake_done = False
        self._framing = MsgpackFraming()
        self._loop: asyncio.AbstractEventLoop | None = None
        self._chan: Any = None

    def connection_made(self, chan: Any) -> None:
        """Called when the SSH channel opens."""
        self._chan = chan
        self._loop = asyncio.get_running_loop()

    def subsystem_requested(self, subsystem: str) -> bool:
        """Accept the plushie subsystem, reject everything else."""
        return subsystem == "plushie"

    def session_started(self) -> None:
        """Called when the subsystem session starts. Send settings."""
        settings_data = _encode_settings_bytes()
        if self._chan is not None:
            self._chan.write(settings_data)

    def data_received(self, data: bytes, datatype: Any = None) -> None:
        """Called when data arrives on the channel."""
        messages = self._framing.feed(data)
        for msg in messages:
            self._handle_message(msg)

    def _handle_message(self, msg: dict[str, Any]) -> None:
        """Process a single decoded wire message."""
        event = protocol.decode_message(msg)

        # Dark mode toggle: handle locally
        if isinstance(event, Toggle) and event.id == "theme":
            self._dark_mode = event.value
            return

        # Hello: complete handshake, register with shared
        if isinstance(event, HelloInfo):
            self._handshake_done = True
            self._shared.connect(self._client_id, self._on_model_changed)
            return

        # Skip raw dicts (unrecognized message types)
        if isinstance(event, dict):
            return

        # Forward to shared state
        if self._handshake_done:
            self._shared.handle_event(self._client_id, event)

    def _on_model_changed(self, model: Any) -> None:
        """Called from SharedState broadcast (possibly from another thread)."""
        if not self._handshake_done:
            return
        client_model = Model(
            name=model.name,
            notes=model.notes,
            count=model.count,
            dark_mode=self._dark_mode,
            status=model.status,
        )
        data = _encode_snapshot_bytes(client_model)
        if self._loop is not None:
            self._loop.call_soon_threadsafe(self._write_data, data)

    def _write_data(self, data: bytes) -> None:
        """Write data to the channel (must be called from the event loop)."""
        try:
            if self._chan is not None:
                self._chan.write(data)
        except Exception:
            logger.debug("Failed to write to SSH channel", exc_info=True)

    def connection_lost(self, exc: Exception | None) -> None:
        """Called when the SSH channel closes."""
        if self._handshake_done:
            self._shared.disconnect(self._client_id)


class CollabSSHServer(asyncssh.SSHServer):  # type: ignore[misc]
    """SSH server that provides the plushie subsystem."""

    def __init__(self, shared: SharedState) -> None:
        super().__init__()
        self._shared = shared

    def begin_auth(self, username: str) -> bool:
        """Allow all connections without authentication."""
        return False

    def session_requested(self) -> PlushieSubsystemSession:
        """Return a subsystem session handler for each incoming connection."""
        return PlushieSubsystemSession(self._shared)


async def start_ssh_server(shared: SharedState, *, port: int = 2222) -> Any:
    """Start the SSH daemon.

    Auto-generates host keys in /tmp if they don't exist.

    Args:
        shared: The shared state server.
        port: TCP port to listen on.

    Returns:
        The asyncssh server object.
    """
    import os
    import subprocess
    import tempfile

    key_dir = os.path.join(tempfile.gettempdir(), "plushie_demo_ssh_keys")
    os.makedirs(key_dir, exist_ok=True)
    rsa_key = os.path.join(key_dir, "ssh_host_rsa_key")

    if not os.path.exists(rsa_key):
        subprocess.run(
            ["ssh-keygen", "-t", "rsa", "-b", "2048", "-f", rsa_key, "-N", "", "-q"],
            check=True,
        )

    def _server_factory() -> CollabSSHServer:
        return CollabSSHServer(shared)

    return await asyncssh.create_server(
        _server_factory,
        "127.0.0.1",
        port,
        server_host_keys=[rsa_key],
    )
