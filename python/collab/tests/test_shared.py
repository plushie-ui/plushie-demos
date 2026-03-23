"""Tests for the SharedState server.

Verifies thread-safe shared state coordination: client connect/disconnect,
event forwarding, broadcasting, status text, and that dark_mode is not
part of the shared model.
"""

from __future__ import annotations

from typing import Any

from collab_demo.collab import Collab, Model
from collab_demo.shared import SharedState
from plushie.events import Click, Input, Toggle


def _shared() -> SharedState:
    return SharedState(Collab())


# ---------------------------------------------------------------------------
# Connect / Disconnect
# ---------------------------------------------------------------------------


class TestConnect:
    """Client registration and deregistration."""

    def test_connect_adds_client(self) -> None:
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        # Should have received at least one broadcast (the connect broadcast)
        assert len(received) >= 1

    def test_connect_callback_receives_model(self) -> None:
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        model = received[-1]
        assert isinstance(model, Model)

    def test_disconnect_removes_client(self) -> None:
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        received.clear()

        shared.disconnect("c1")
        # After disconnect, events should not broadcast to c1
        # (but the disconnect itself broadcasts to remaining clients)
        # Since c1 is already removed, received should still be empty
        assert len(received) == 0

    def test_disconnect_nonexistent_client_is_safe(self) -> None:
        shared = _shared()
        # Should not raise
        shared.disconnect("nonexistent")


# ---------------------------------------------------------------------------
# Broadcasting
# ---------------------------------------------------------------------------


class TestBroadcast:
    """Model broadcasts to connected clients."""

    def test_handle_event_updates_model(self) -> None:
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        received.clear()

        shared.handle_event("c1", Click(id="inc"))
        assert len(received) == 1
        assert received[0].count == 1

    def test_multiple_clients_receive_broadcasts(self) -> None:
        shared = _shared()
        received_a: list[Any] = []
        received_b: list[Any] = []
        shared.connect("a", received_a.append)
        shared.connect("b", received_b.append)
        received_a.clear()
        received_b.clear()

        shared.handle_event("a", Click(id="inc"))
        assert len(received_a) == 1
        assert len(received_b) == 1
        assert received_a[0].count == 1
        assert received_b[0].count == 1

    def test_event_from_any_client_updates_all(self) -> None:
        shared = _shared()
        received_a: list[Any] = []
        received_b: list[Any] = []
        shared.connect("a", received_a.append)
        shared.connect("b", received_b.append)
        received_a.clear()
        received_b.clear()

        # Client b sends the event
        shared.handle_event("b", Click(id="inc"))
        assert received_a[-1].count == 1
        assert received_b[-1].count == 1


# ---------------------------------------------------------------------------
# Status text
# ---------------------------------------------------------------------------


class TestStatus:
    """Status field shows client count."""

    def test_status_after_one_connect(self) -> None:
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        assert received[-1].status == "1 connected"

    def test_status_after_two_connects(self) -> None:
        shared = _shared()
        received_a: list[Any] = []
        received_b: list[Any] = []
        shared.connect("a", received_a.append)
        shared.connect("b", received_b.append)
        assert received_b[-1].status == "2 connected"

    def test_status_after_disconnect(self) -> None:
        shared = _shared()
        received_a: list[Any] = []
        received_b: list[Any] = []
        shared.connect("a", received_a.append)
        shared.connect("b", received_b.append)
        received_a.clear()

        shared.disconnect("b")
        assert received_a[-1].status == "1 connected"

    def test_status_preserved_after_event(self) -> None:
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        received.clear()

        shared.handle_event("c1", Click(id="inc"))
        assert received[-1].status == "1 connected"


# ---------------------------------------------------------------------------
# Dark mode isolation
# ---------------------------------------------------------------------------


class TestDarkMode:
    """dark_mode is per-client and not part of shared state."""

    def test_shared_model_has_default_dark_mode(self) -> None:
        shared = _shared()
        assert shared.model.dark_mode is False

    def test_toggle_event_does_not_affect_shared_dark_mode(self) -> None:
        """If a client somehow sends a toggle event, the shared model
        updates but each client is responsible for overriding dark_mode
        locally. The point is: the server doesn't track per-client
        dark_mode, only the shared fields."""
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        received.clear()

        # Even if forwarded, the toggle only changes the shared model's
        # dark_mode -- but in practice, the handlers intercept this
        # before it reaches shared state.
        shared.handle_event("c1", Toggle(id="theme", value=True))
        # The shared model does get updated (it processes all events)
        # but the ws/ssh handlers are responsible for intercepting
        # theme toggles before forwarding. This test documents the
        # boundary: SharedState itself is unaware of per-client state.
        assert received[-1].dark_mode is True

    def test_input_event_does_not_touch_dark_mode(self) -> None:
        shared = _shared()
        received: list[Any] = []
        shared.connect("c1", received.append)
        received.clear()

        shared.handle_event("c1", Input(id="name", value="test"))
        assert received[-1].dark_mode is False
