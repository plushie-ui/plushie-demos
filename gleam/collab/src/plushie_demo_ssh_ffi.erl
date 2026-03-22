-module(plushie_demo_ssh_ffi).

%% Public API called from Gleam
-export([start_daemon/2]).

%% ssh_server_channel callbacks
-behaviour(ssh_server_channel).
-export([init/1, handle_ssh_msg/2, handle_msg/2, terminate/2]).

%%====================================================================
%% Public API
%%====================================================================

%% Start the SSH daemon on the given port.
%% Shared is a Gleam Subject(SharedMsg) for the shared state actor.
start_daemon(Shared, Port) ->
    ok = application:ensure_started(crypto),
    ok = application:ensure_started(asn1),
    ok = application:ensure_started(public_key),
    ok = application:ensure_started(ssh),

    SystemDir = ensure_host_keys(),

    {ok, _Pid} = ssh:daemon(Port, [
        {system_dir, SystemDir},
        {no_auth_needed, true},
        {subsystems, [
            {"plushie", {?MODULE, [Shared]}}
        ]},
        {auth_methods, "none"}
    ]),
    nil.

%%====================================================================
%% ssh_server_channel callbacks
%%====================================================================

-record(ch_state, {
    shared,          %% Gleam Subject(SharedMsg) -- the shared state actor
    client_id,       %% Binary -- unique client ID for this connection
    client_subject,  %% Gleam Subject(ClientMsg) -- receives model updates
    conn,            %% SSH connection ref
    channel,         %% SSH channel ID
    buffer = <<>>,   %% Partial JSONL line buffer
    dark_mode = false,
    relay_pid        %% PID of the model relay helper process
}).

init([Shared]) ->
    ClientId = <<"ssh-", (integer_to_binary(erlang:unique_integer([positive]))/binary)>>,
    {ok, #ch_state{shared = Shared, client_id = ClientId}}.

%% SSH channel is ready -- register with shared actor
handle_msg({ssh_channel_up, Channel, Conn}, State) ->
    #ch_state{shared = Shared, client_id = ClientId} = State,

    %% Create a Gleam subject for receiving ClientMsg
    ClientSubject = 'gleam@erlang@process':new_subject(),

    %% Register with the shared actor
    'gleam@erlang@process':send(Shared, {client_connect, ClientId, ClientSubject}),

    NewState = State#ch_state{
        conn = Conn,
        channel = Channel,
        client_subject = ClientSubject
    },

    %% Start a helper process that relays ClientMsg to this channel process
    Self = self(),
    RelayPid = spawn_link(fun() -> model_relay(ClientSubject, Self) end),

    {ok, NewState#ch_state{relay_pid = RelayPid}};

%% Model update from the shared actor (relayed by helper process)
handle_msg({model_changed, Model}, State) ->
    #ch_state{conn = Conn, channel = Channel, dark_mode = DarkMode} = State,
    %% Model is {model, Name, Notes, Count, DarkMode, Status}
    %% Apply per-client dark_mode (field 5)
    ClientModel = setelement(5, Model, DarkMode),
    %% Render the view and encode as snapshot JSONL
    Tree = 'demo@collab':view(ClientModel),
    case 'plushie@protocol@encode':encode_snapshot(Tree, <<>>, json) of
        {ok, JsonBytes} ->
            ssh_connection:send(Conn, Channel, JsonBytes);
        {error, _} ->
            ok
    end,
    {ok, State};

%% Send data to the SSH client (called from Gleam)
handle_msg({send_data, Data}, State) ->
    #ch_state{conn = Conn, channel = Channel} = State,
    ssh_connection:send(Conn, Channel, Data),
    {ok, State};

handle_msg(_Msg, State) ->
    {ok, State}.

%% Data arrived from the SSH client (the native plushie binary)
handle_ssh_msg({ssh_cm, _Conn, {data, _Channel, 0, Data}}, State) ->
    #ch_state{buffer = Buf} = State,
    Combined = <<Buf/binary, Data/binary>>,
    {Lines, NewBuf} = split_lines(Combined),
    NewState = lists:foldl(fun handle_line/2, State, Lines),
    {ok, NewState#ch_state{buffer = NewBuf}};

handle_ssh_msg({ssh_cm, _Conn, {eof, _Channel}}, State) ->
    {ok, State};

handle_ssh_msg({ssh_cm, _Conn, {closed, _Channel}}, State) ->
    disconnect_client(State),
    {stop, State#ch_state.channel, State};

handle_ssh_msg(_Msg, State) ->
    {ok, State}.

terminate(_Reason, State) ->
    disconnect_client(State),
    ok.

%%====================================================================
%% Internal helpers
%%====================================================================

disconnect_client(#ch_state{shared = Shared, client_id = ClientId, relay_pid = Relay}) ->
    'gleam@erlang@process':send(Shared, {client_disconnect, ClientId}),
    case is_pid(Relay) of
        true -> exit(Relay, kill);
        false -> ok
    end.

%% Process a single JSONL line from the SSH client
handle_line(Line, State) ->
    %% Try to decode as a plushie wire protocol message
    LineWithNewline = <<Line/binary, "\n">>,
    case 'plushie@protocol@decode':decode_message(LineWithNewline, json) of
        {ok, {event_message, Event}} ->
            #ch_state{shared = Shared, client_id = ClientId} = State,
            'gleam@erlang@process':send(Shared, {client_event, ClientId, Event}),
            %% Check if this is a dark_mode toggle (theme widget)
            case Event of
                {widget_toggle, <<"theme">>, _, Checked} ->
                    State#ch_state{dark_mode = Checked};
                _ ->
                    State
            end;
        {ok, {hello, _, _, _, _, _, _}} ->
            %% Renderer sent hello -- send initial settings response.
            %% The native plushie binary sends settings first and expects
            %% hello back. But we're acting as the "host" here, so the
            %% client sends hello after receiving our settings.
            %% Just acknowledge.
            State;
        _ ->
            %% Could be a settings message or something we don't handle.
            %% Check if it looks like settings and respond with hello.
            case is_settings_message(Line) of
                true -> send_hello(State), State;
                false -> State
            end
    end.

%% Check if a JSON line is a settings message
is_settings_message(Line) ->
    case catch jsx:decode(Line) of
        _ ->
            %% Simple string match since we don't have jsx
            binary:match(Line, <<"\"type\":\"settings\"">>) =/= nomatch
    end.

%% Send hello message to the SSH client
send_hello(#ch_state{conn = Conn, channel = Channel}) ->
    Hello = <<"{\"type\":\"hello\",\"protocol\":1,\"version\":\"0.1.0\","
              "\"name\":\"plushie-demo\",\"backend\":\"gleam\","
              "\"extensions\":[],\"transport\":\"ssh\"}\n">>,
    ssh_connection:send(Conn, Channel, Hello).

%% Split a binary buffer on newline boundaries.
split_lines(Buffer) ->
    split_lines(Buffer, []).

split_lines(Buffer, Acc) ->
    case binary:split(Buffer, <<"\n">>) of
        [Line, Rest] when byte_size(Line) > 0 ->
            split_lines(Rest, [Line | Acc]);
        [<<>>, Rest] ->
            split_lines(Rest, Acc);
        [Remainder] ->
            {lists:reverse(Acc), Remainder}
    end.

%% Helper process that relays ClientMsg from the shared actor
%% to the SSH channel process via regular Erlang messages.
model_relay(ClientSubject, ChannelPid) ->
    Selector = 'gleam@erlang@process':new_selector(),
    Selector2 = 'gleam@erlang@process':select(Selector, ClientSubject),
    model_relay_loop(Selector2, ChannelPid).

model_relay_loop(Selector, ChannelPid) ->
    Msg = 'gleam@erlang@process':selector_receive_forever(Selector),
    %% Msg is {model_changed, Model} -- forward to channel process
    ChannelPid ! Msg,
    model_relay_loop(Selector, ChannelPid).

%% Ensure SSH host keys exist in a temp directory.
ensure_host_keys() ->
    Dir = filename:join(["/tmp", "plushie_demo_ssh_keys"]),
    ok = filelib:ensure_dir(filename:join(Dir, "dummy")),
    RsaKey = filename:join(Dir, "ssh_host_rsa_key"),
    case filelib:is_file(RsaKey) of
        true ->
            Dir;
        false ->
            os:cmd("ssh-keygen -t rsa -b 2048 -f " ++ RsaKey ++ " -N '' -q"),
            Dir
    end.
