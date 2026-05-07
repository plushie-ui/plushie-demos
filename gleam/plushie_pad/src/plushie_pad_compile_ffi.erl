%% @doc Runtime Erlang compilation for Plushie Pad experiments.
%%
%% Takes source text, parses it, compiles it, loads the module, and
%% invokes the module's `view/0' function. Errors at any stage are
%% returned as `{error, Reason}' tuples so the Gleam side can render
%% them as text in the preview pane.

-module(plushie_pad_compile_ffi).

-export([compile_and_render/1]).

%% Compile the given Erlang source text and call the resulting
%% module's view/0 function. Returns {ok, Node} on success or
%% {error, Message} on any failure (parse, compile, load, missing
%% export, runtime error).
compile_and_render(Source) when is_binary(Source) ->
    SourceStr = binary_to_list(Source),
    case erl_scan:string(SourceStr) of
        {ok, Tokens, _End} ->
            compile_tokens(Tokens);
        {error, {_Line, erl_scan, Reason}, _} ->
            {error, format_error(scan, Reason)}
    end.

compile_tokens(Tokens) ->
    Forms = split_forms(Tokens, [], []),
    case parse_forms(Forms, []) of
        {ok, Parsed} ->
            compile_forms(Parsed);
        {error, Message} ->
            {error, Message}
    end.

%% Split a flat token list into a list of per-form token lists,
%% splitting on dot tokens.
split_forms([], [], Acc) ->
    lists:reverse(Acc);
split_forms([], Current, Acc) ->
    lists:reverse([lists:reverse(Current) | Acc]);
split_forms([{dot, _} = Dot | Rest], Current, Acc) ->
    Form = lists:reverse([Dot | Current]),
    split_forms(Rest, [], [Form | Acc]);
split_forms([Tok | Rest], Current, Acc) ->
    split_forms(Rest, [Tok | Current], Acc).

parse_forms([], Acc) ->
    {ok, lists:reverse(Acc)};
parse_forms([Form | Rest], Acc) ->
    case erl_parse:parse_form(Form) of
        {ok, Parsed} ->
            parse_forms(Rest, [Parsed | Acc]);
        {error, {_Line, erl_parse, Reason}} ->
            {error, format_error(parse, Reason)}
    end.

compile_forms(Forms) ->
    case compile:forms(Forms, [return_errors]) of
        {ok, Module, Binary} ->
            load_and_render(Module, Binary);
        {ok, Module, Binary, _Warnings} ->
            load_and_render(Module, Binary);
        {error, Errors, _Warnings} ->
            {error, format_compile_errors(Errors)};
        error ->
            {error, <<"compile error">>}
    end.

load_and_render(Module, Binary) ->
    %% Allow re-defining the module each save cycle.
    code:purge(Module),
    case code:load_binary(Module, atom_to_list(Module) ++ ".erl", Binary) of
        {module, Module} ->
            case erlang:function_exported(Module, view, 0) of
                true ->
                    safe_call_view(Module);
                false ->
                    {error, <<"module must export view/0">>}
            end;
        {error, What} ->
            {error, format_error(load, What)}
    end.

safe_call_view(Module) ->
    try Module:view() of
        Node ->
            {ok, Node}
    catch
        Class:Reason:_Stack ->
            Text = io_lib:format("~p: ~p", [Class, Reason]),
            {error, iolist_to_binary(Text)}
    end.

format_error(Stage, Reason) ->
    Text = io_lib:format("~p: ~p", [Stage, Reason]),
    iolist_to_binary(Text).

format_compile_errors(Errors) ->
    Text =
        lists:map(
            fun({_File, Reasons}) ->
                lists:map(
                    fun({Line, Module, Desc}) ->
                        io_lib:format("line ~p: ~s~n", [
                            Line, Module:format_error(Desc)
                        ])
                    end,
                    Reasons
                )
            end,
            Errors
        ),
    iolist_to_binary(Text).
