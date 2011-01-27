-module (socketio_utils).

-export ([encode/1, decode/2, get_heartbeat/1, ref_to_msg/1, random/0]).

% Encode messages to Socket.IO format
encode({json, Message}) ->
  encode(binary:list_to_bin([<<"\~j\~">>, Message]));
encode(Message) ->
  Len = binary:list_to_bin(integer_to_list(erlang:size(Message))), % Yuck
  binary:list_to_bin([<<"\~m\~">>, Len, <<"\~m\~">>, Message]).

% Messages look like:
% ~m~MSGLENGTH~m~MESSAGE or
% ~m~MSGLENGTH~m~~j~JSON
% TODO: REWRITE FOR BUFFERED MSGS
decode(<<"\~m\~", Message/binary>>, Buffer) ->
	[_|[Message0]] = binary:split(Message, <<"\~m\~">>), % Get past the length
	case binary:split(Message, <<"\~m\~">>) of
		[_|[Message0]] ->
			case binary:match(Message0, <<"\~m\~">>) of
				{Beginning, _} ->
					<<Message1:Beginning/binary, Rest/binary>> = Message0,
					NewBuffer = Buffer ++ [Message1],
					decode(Rest, NewBuffer);
				nomatch ->
					Buffer ++ [Message0]
			end
	end;
decode(_, Buffer) ->
  Buffer.

get_heartbeat(Number) ->
	binary:list_to_bin([<<"\~h\~">>, integer_to_list(Number)]).

ref_to_msg(Ref) ->
	socketio_utils:encode(binary:list_to_bin(erlang:ref_to_list(Ref))).

% TODO: Code from CouchDB - Apache license. Check conciquence
random() ->
	Now = {_, _, Micro} = now(),
 	Nowish = calendar:now_to_universal_time(Now),
 	Nowsecs = calendar:datetime_to_gregorian_seconds(Nowish),
 	Then = calendar:datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}}),
 	Prefix = io_lib:format("~14.16.0b", [(Nowsecs - Then) * 1000000 + Micro]),
 	list_to_binary(Prefix ++ to_hex(crypto:rand_bytes(9))).

to_hex([]) -> [];
to_hex(Bin) when is_binary(Bin) ->
	to_hex(binary_to_list(Bin));
to_hex([H|T]) ->
	[to_digit(H div 16), to_digit(H rem 16) | to_hex(T)].

to_digit(N) when N < 10 ->
	$0 + N;
to_digit(N) ->
	$a + N-10.