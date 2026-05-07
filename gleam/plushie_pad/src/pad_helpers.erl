%% @doc Ergonomic Erlang-side wrappers around the Gleam SDK's widget builders.
%%
%% Plushie Pad experiments are Erlang modules compiled at runtime. The
%% raw plushie@ui and plushie@widget@* call sites are unergonomic
%% (`'plushie@widget@button':new(Id, Label)' and so on), so this helper
%% module exposes friendlier names. It is the recommended shape for
%% any Erlang-side code talking to Plushie; see the erlang-interop
%% reference for the underlying mapping.

-module(pad_helpers).

-export([
    %% Leaf widgets
    text/2, text_size/3,
    button/2,
    %% Container widgets
    column/3, row/3, container/3,
    %% Padding helpers
    padding_all/1, padding_xy/2
]).

%% --- Leaf widgets ----------------------------------------------------------

text(Id, Content) ->
    'plushie@ui':text_(Id, Content).

text_size(Id, Content, Size) ->
    'plushie@ui':text(Id, Content, [{size, Size}]).

button(Id, Label) ->
    'plushie@ui':button_(Id, Label).

%% --- Container widgets -----------------------------------------------------

column(Id, Opts, Children) ->
    'plushie@ui':column(Id, Opts, Children).

row(Id, Opts, Children) ->
    'plushie@ui':row(Id, Opts, Children).

container(Id, Opts, Children) ->
    'plushie@ui':container(Id, Opts, Children).

%% --- Padding helpers -------------------------------------------------------

padding_all(N) ->
    'plushie@prop@padding':all(N).

padding_xy(V, H) ->
    'plushie@prop@padding':xy(V, H).
