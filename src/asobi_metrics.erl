-module(asobi_metrics).
-moduledoc """
Prometheus metrics collectors for [`asobi`](https://github.com/widgrensit/asobi).

Declares Prometheus metrics for the asobi telemetry surface (see
[ADR 0005](https://github.com/widgrensit/asobi/blob/main/docs/adr/0005-telemetry-event-surface.md))
and attaches `m:telemetry` handlers that translate events into counter /
histogram updates.

This package has no web dependency and stands up no listener of its own. Serve
the scrape output from your application's existing web layer. For a Nova app
(asobi's web framework), a one-line controller does it:

```erlang
-module(metrics_controller).
-export([index/1]).

index(_Req) ->
    {status, 200, #{~"content-type" => ~"text/plain; version=0.0.4"},
        asobi_metrics:scrape()}.
```

then route `{"/metrics", fun metrics_controller:index/1, #{methods => [get]}}`
on an operator-only listener - this endpoint is not meant for players. asobi's
game-facing WebSocket listener is the wrong place to mount it.

Enabling metrics is just:

```erlang
{ok, _} = application:ensure_all_started(asobi_metrics).
```

`auto_setup` (default `true`) declares the metrics and attaches the handlers at
boot; set it to `false` to call `setup/0` yourself.
""".

-export([setup/0, scrape/0]).

-define(HANDLER_ID, asobi_metrics_handler).

-doc "Declare metrics and attach telemetry handlers. Idempotent.".
-spec setup() -> ok.
setup() ->
    ok = asobi_metrics_definitions:declare(),
    ok = asobi_metrics_handlers:attach(?HANDLER_ID),
    ok.

-doc """
Render the current metrics in Prometheus text exposition format. Return this
from your `/metrics` handler with content type
`text/plain; version=0.0.4`.
""".
-spec scrape() -> binary().
scrape() ->
    iolist_to_binary(prometheus_text_format:format()).
