//// Wrapper around the runtime Erlang compilation FFI.
////
//// The pad compiles user-typed Erlang source each time the user saves
//// and renders the resulting widget tree into the preview pane. This
//// module narrows the FFI boundary to a single `compile_and_render`
//// call returning `Result(Node, String)`.

import plushie/node.{type Node}

@external(erlang, "plushie_pad_compile_ffi", "compile_and_render")
pub fn compile_and_render(source: String) -> Result(Node, String)
