"""Thread-safe shared state server for collaborative modes.

Holds the authoritative model and a set of connected clients. When any
client sends an event, the server runs update(), re-renders the view,
and broadcasts the new model to ALL connected clients.

Python equivalent of the Elixir GenServer in ``Collab.Shared``.
"""

from __future__ import annotations

import threading
from collections.abc import Callable
from dataclasses import replace
from typing import Any

from collab_demo.collab import Collab, Model


def _unwrap_model(result: Any) -> Model:
    """Extract the model from an init/update return value.

    Returns may be a bare Model or (Model, Command).
    """
    if isinstance(result, tuple):
        return result[0]  # type: ignore[no-any-return]
    return result  # type: ignore[no-any-return]


class SharedState:
    """Thread-safe shared state coordinating all connected clients.

    Args:
        app: The Collab app instance used for init/update/view.
    """

    def __init__(self, app: Collab) -> None:
        self._lock = threading.Lock()
        self._model: Model = _unwrap_model(app.init())
        self._app = app
        self._clients: dict[str, Callable[[Model], None]] = {}

    @property
    def model(self) -> Model:
        """The current shared model (read-only snapshot)."""
        with self._lock:
            return self._model

    def connect(self, client_id: str, callback: Callable[[Model], None]) -> Model:
        """Register a client. callback(model) is called on broadcasts.

        Args:
            client_id: Unique identifier for this client.
            callback: Called with the current model on every broadcast.

        Returns:
            The current model (for sending the initial snapshot).
        """
        with self._lock:
            self._clients[client_id] = callback
            self._model = replace(self._model, status=self._status_text())
            self._broadcast()
            return self._model

    def disconnect(self, client_id: str) -> None:
        """Unregister a client.

        Args:
            client_id: The client to remove.
        """
        with self._lock:
            self._clients.pop(client_id, None)
            self._model = replace(self._model, status=self._status_text())
            self._broadcast()

    def handle_event(self, client_id: str, event: Any) -> None:
        """Forward an event, update model, broadcast to all.

        Args:
            client_id: The client that sent the event.
            event: The decoded event to process.
        """
        with self._lock:
            new_model = _unwrap_model(self._app.update(self._model, event))
            # Preserve status (managed by the server, not the app)
            new_model = replace(new_model, status=self._status_text())
            self._model = new_model
            self._broadcast()

    def _broadcast(self) -> None:
        """Send current model to all connected clients. Must hold lock."""
        for callback in self._clients.values():
            callback(self._model)

    def _status_text(self) -> str:
        """Format the connection count status string. Must hold lock."""
        count = len(self._clients)
        return f"{count} connected"
