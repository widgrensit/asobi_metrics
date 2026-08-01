-module(asobi_metrics_app).
-moduledoc false.

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case application:get_env(asobi_metrics, auto_setup, true) of
        true -> ok = asobi_metrics:setup();
        false -> ok
    end,
    asobi_metrics_sup:start_link().

stop(_State) ->
    ok.
