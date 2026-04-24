from plushie import ui


def view():
    return ui.column(
        ui.text("greeting", "Hello, Plushie!", size=24),
        ui.button("btn", "Click Me"),
        padding=16,
        spacing=8,
    )
