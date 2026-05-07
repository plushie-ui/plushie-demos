-module(hello).
-export([view/0]).

view() ->
    pad_helpers:column(<<"root">>,
        [{padding, pad_helpers:padding_all(16.0)}, {spacing, 8.0}],
        [
            pad_helpers:text_size(<<"greeting">>, <<"Hello, Plushie!">>, 24.0),
            pad_helpers:button(<<"btn">>, <<"Click Me">>)
        ]).
