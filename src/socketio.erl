% Socket.IO server for Erlang
% 
% Copyright (C) 2011, Kóði ehf, Ómar Yasin <omar@kodiak.is>
% 
% All rights reserved.
% 
% BSD License
% 
% Redistribution and use in source and binary forms, with or without modification, are permitted provided
% that the following conditions are met:
% 
%  * Redistributions of source code must retain the above copyright notice, this list of conditions and the
%    following disclaimer.
%  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
%    the following disclaimer in the documentation and/or other materials provided with the distribution.
%  * Neither the name of the authors nor the names of its contributors may be used to endorse or promote
%    products derived from this software without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
% WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
% ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
% TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
-module (socketio).
-include ("socketio.hrl").

%% API
-export ([create/5, broadcast/1]).

broadcast(_) ->
	void.

create(<<"websocket">>, Req, AutoExit, Options, Loop) ->
	case mochiweb_websocket_server:check(Req:get(headers)) of
		{true, Version} ->
			socketio_ws:start_link(Req, Version, AutoExit, Options, Loop);
		_ ->
			Req:ok("No WS")
	end;

% For a strange reason xhr-pooling request end with a double slash..
create(<<"xhr-polling/", Rest/binary>>, Req, AutoExit, Options, Loop) ->
	[Session|Tail] = binary:split(Rest, <<"/">>),
	case binary:referenced_byte_size(Session) of
		0 -> % No session, create new session
			SessionId = socketio_utils:random(),
			socketio_xhrpolling:start_link(Req, SessionId, AutoExit, Options, Loop);
		_ -> % Some session, look it up and pid it
			case socketio_xhrpolling:find_process(Session) of
				undefined ->
					Req:ok({_ContentType = "text/plain",
						_Headers = [{"Access-Control-Allow-Origin", "*"},
						{"Connection", "keep-alive"}], "error"}); % Probably not what SocketIO expects
				Pid ->
					case Tail of
						[<<"send">>] ->
							Incoming = case Req:recv_body() of
								<<"data=", Data/binary>> ->
									Data;
								_ ->
									<<>>
							end,
							gen_server:cast(Pid, {data, Req, Incoming});
						_ ->
							gen_server:cast(Pid, {poll, Req})
					end
			end
	end;

create(_, Req, _, _, _) ->
	Req:respond({404, [], "404 Not Found\r\n"}).