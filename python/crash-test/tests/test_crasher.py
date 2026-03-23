"""Tests for the crasher extension definition and builder functions."""

from crash_test.crasher import crasher, crasher_def, trigger_panic


class TestCrasherDef:
    """Extension definition is well-formed."""

    def test_kind(self) -> None:
        assert crasher_def.kind == "crasher"

    def test_props(self) -> None:
        names = [p.name for p in crasher_def.props]
        assert "message" in names
        assert "panic_on_render" in names

    def test_commands(self) -> None:
        names = [c.name for c in crasher_def.commands]
        assert "panic" in names

    def test_rust_constructor(self) -> None:
        assert "CrasherExtension::new()" in crasher_def.rust_constructor


class TestCrasherBuilder:
    """Builder produces correct node dicts."""

    def test_defaults(self) -> None:
        node = crasher("test-id")
        assert node["id"] == "test-id"
        assert node["type"] == "crasher"
        assert node["props"]["message"] == "Crasher widget (alive)"
        assert node["props"]["panic_on_render"] is False

    def test_custom_message(self) -> None:
        node = crasher("w", message="hello")
        assert node["props"]["message"] == "hello"

    def test_panic_on_render(self) -> None:
        node = crasher("w", panic_on_render=True)
        assert node["props"]["panic_on_render"] is True


class TestTriggerPanic:
    """Command builder produces extension commands."""

    def test_command_type(self) -> None:
        cmd = trigger_panic("my-widget")
        assert cmd.type == "extension_command"

    def test_command_payload(self) -> None:
        cmd = trigger_panic("my-widget")
        assert cmd.payload["node_id"] == "my-widget"
        assert cmd.payload["op"] == "panic"
