%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_trust_store_app).
-behaviour(application).
-export([change_SSL_options/0]).
-export([start/2, stop/1]).


-rabbit_boot_step({rabbit_trust_store, [
    {description, "Change necessary SSL options."},
    {mfa, {?MODULE, change_SSL_options, []}},
    %% {cleanup, ...}, {requires, ...},
    {enables, networking}]}).

change_SSL_options() ->
    case application:get_env(rabbit, ssl_options) of
        undefined ->
            edit([]);
        {ok, Before} when is_list(Before) ->
            After = edit(Before),
            ok = application:set_env(rabbit,
                ssl_options, After, [{persistent, true}])
    end.

start(normal, _) ->
    case ready('SSL') of
        no  -> {error, information('SSL')};
        yes -> ready('whitelist directory')
    end.

stop(_) ->
    ok.


%% Ancillary & Constants

edit(Options) ->
    %% Only enter those options neccessary for this application.
    case lists:keymember(verify_fun, 1, Options) of
        true ->
            {error, information(edit)};
        false ->
            lists:keymerge(1, required_options(),
                [{verify_fun, {delegate(procedure), continue}}|Options])
    end.

information(edit) ->
    <<"The prerequisite SSL option, `verify_fun`, is already set.">>;
information('SSL') ->
    <<"The SSL `verify_fun` procedure must interface with this application.">>;
information(whitelist) ->
    <<"The Trust-Store must be configured with a valid directory for whitelisted certificates.">>.

delegate(procedure) ->
    M = delegate(module), fun M:whitelisted/3;
delegate(module) ->
    rabbit_trust_store.

required_options() ->
    [{verify, verify_peer}, {fail_if_no_peer_cert, true}].

ready('SSL') ->
    {ok, Options} = application:get_env(rabbit, ssl_options),
    case lists:keyfind(verify_fun, 1, Options) of
        false ->
            no;
        {_, {Interface, _St}} ->
            here(Interface)
    end;
ready('whitelist directory') ->
    %% The below two are properties, that is, tuple of name/value.
    Path = {_, Value} = whitelist_path(),
    Expiry = expiry_time(),
    case filelib:ensure_dir(Value) of
        {error, _} ->
            {error, information(whitelist)};
        ok ->
            %% At this point we know `Value` is indeed directory name.
            rabbit_trust_store_sup:start_link([Path, Expiry])
    end.

here(Procedure) ->
    M = delegate(module),
    case erlang:fun_info(Procedure, module) of
        {module, M} -> yes;
        {module, _} -> no
    end.

whitelist_path() ->
    case application:get_env(rabbitmq_trust_store, whitelist) of
        undefined               -> {whitelist, default_directory()};
        {ok, V} when is_list(V) -> {whitelist, V}
    end.

expiry_time() ->
    case application:get_env(rabbitmq_trust_store, expiry) of
        undefined ->
            {expiry, default_expiry()};
        {ok, Seconds} when is_integer(Seconds) ->
            {expiry, Seconds}
    end.

default_directory() ->
    filename:join([os:getenv("HOME"), "rabbit", "whitelist"]) ++ "/".

default_expiry() ->
    timer:seconds(30).
