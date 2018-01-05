%% -------------------------------------------------------------------
%%
%% Copyright (c) 2018 Vitor Enes.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------


-module(cal_client_handler).
-author("Vitor Enes <vitorenesduarte@gmail.com>").

-include("cal.hrl").

-behaviour(gen_server).
-behaviour(ranch_protocol).

%% API
-export([start_link/4]).

%% gen_server
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2]).

-record(state, {socket :: inet:socket()}).

%% @doc Ranch callback when a new connection is accepted.
start_link(Ref, Socket, ranch_tcp, _Opts = []) ->
    Arg = [Ref, Socket],
    {ok, proc_lib:spawn_link(?MODULE,
                             init,
                             [Arg])}.

%% @doc Implementation of `ranch_protocol' using `gen_server'.
init([Ref, Socket]) ->
    lager:info("New client connection ~p", [Socket]),

    %% configure socket
    ok = ranch:accept_ack(Ref),
    ok = cal_client_socket:configure(Socket),
    ok = cal_client_socket:activate(Socket),

    gen_server:enter_loop(?MODULE, [], #state{socket=Socket}).

handle_call(Msg, _From, State) ->
    {stop, {unhandled, Msg}, State}.

handle_cast(Msg, State) ->
    {stop, {unhandled, Msg}, State}.

handle_info({tcp, Socket, Bin}, State) ->
    do_receive(Bin, Socket),
    {noreply, State};

handle_info({tcp_closed, Socket}, State) ->
    lager:info("TCP client socket closed ~p", [Socket]),
    {stop, normal, State};

handle_info({notification, ExpId, Event}, #state{socket=Socket}=State) ->
    Message = cal_client_message:encode_notification(ExpId, Event),
    cal_client_socket:send(Socket, Message),
    {noreply, State}.

%% @private
do_receive(Bin, Socket) ->
    %% decode message
    Message = cal_client_message:decode(Bin),

    lager:info("MESSAGE ~p", [Message]),

    %% reactivate socket
    ok = cal_client_socket:activate(Socket).