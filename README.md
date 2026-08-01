# asobi_metrics

Prometheus metrics collectors and Grafana dashboard for
[`asobi`](https://github.com/widgrensit/asobi).

Subscribes to asobi's telemetry surface
([ADR 0005](https://github.com/widgrensit/asobi/blob/main/docs/adr/0005-telemetry-event-surface.md))
and exposes it as canonical Prometheus metrics. A ready-to-import Grafana
dashboard lives in
[`priv/grafana/asobi.json`](priv/grafana/asobi.json). `asobi` itself takes no
dependency on this package, and this package has no web dependency - it only
needs `telemetry` and `prometheus`.

## Quickstart

Start the application (it declares the metrics and attaches the telemetry
handlers at boot):

```erlang
{ok, _} = application:ensure_all_started(asobi_metrics).
```

Then serve `asobi_metrics:scrape/0` from your app's web layer and point
Prometheus at it. On [Nova](https://github.com/novaframework/nova) - asobi's
web framework - that is a one-line controller:

```erlang
-module(metrics_controller).
-export([index/1]).

index(_Req) ->
    {status, 200, #{~"content-type" => ~"text/plain; version=0.0.4"},
        asobi_metrics:scrape()}.
```

wired into your routes on an **operator-only** listener:

```erlang
{"/metrics", fun metrics_controller:index/1, #{methods => [get]}}
```

Do not mount this on asobi's player-facing WebSocket listener - the scrape
output is operational data, not something to expose to game clients. Import
`priv/grafana/asobi.json` into Grafana once you have a scrape target.

Not on Nova? Return `scrape/0` from any handler you already run, or mount
`prometheus_cowboy2_handler` on your own Cowboy listener (add
`prometheus_cowboy` to your app - it is not a dependency here).

## What gets exported

| Metric | Type | Labels |
| --- | --- | --- |
| `asobi_match_started_total` | counter | `mode` |
| `asobi_match_finished_total` | counter | - |
| `asobi_match_player_joined_total` | counter | - |
| `asobi_match_player_left_total` | counter | - |
| `asobi_match_duration_seconds` | histogram | - |
| `asobi_world_started_total` | counter | `mode` |
| `asobi_world_finished_total` | counter | - |
| `asobi_world_player_joined_total` | counter | - |
| `asobi_world_player_left_total` | counter | - |
| `asobi_world_phase_changed_total` | counter | `from_phase`, `to_phase` |
| `asobi_world_duration_seconds` | histogram | - |
| `asobi_matchmaker_queued_total` | counter | `mode` |
| `asobi_matchmaker_removed_total` | counter | `reason` |
| `asobi_matchmaker_formed_total` | counter | `mode` |
| `asobi_matchmaker_failed_total` | counter | `mode` |
| `asobi_matchmaker_wait_seconds` | histogram | `mode` |
| `asobi_sessions_connected_total` | counter | - |
| `asobi_sessions_disconnected_total` | counter | - |
| `asobi_session_duration_seconds` | histogram | - |
| `asobi_ws_connected_total` | counter | - |
| `asobi_ws_disconnected_total` | counter | - |
| `asobi_ws_message_in_total` | counter | `type` |
| `asobi_ws_message_out_total` | counter | `type` |
| `asobi_ws_connect_rate_limited_total` | counter | - |
| `asobi_ws_idle_auth_timeout_total` | counter | - |
| `asobi_ws_origin_rejected_total` | counter | - |
| `asobi_join_rate_limited_total` | counter | - |
| `asobi_rehome_rate_limited_total` | counter | - |
| `asobi_anticheat_violations_total` | counter | `type` |
| `asobi_errors_total` | counter | `kind` |
| `asobi_economy_transactions_total` | counter | `currency`, `reason` |
| `asobi_store_purchases_total` | counter | - |
| `asobi_chat_messages_total` | counter | - |
| `asobi_vote_started_total` | counter | `method` |
| `asobi_vote_cast_total` | counter | - |
| `asobi_vote_resolved_total` | counter | - |
| `asobi_vote_duration_seconds` | histogram | - |
| `asobi_auth_cache_hits_total` | counter | `kind` |
| `asobi_auth_cache_misses_total` | counter | `kind` |
| `asobi_auth_cache_sweeps_total` | counter | - |

High-cardinality identifiers (`match_id`, `world_id`, `player_id`,
`sender_id`, `vote_id`, `item_id`, `channel_id`, `peer_ip`) are kept out of
labels; they stay on the raw telemetry events for tracing sinks (e.g.
`opentelemetry_asobi`) that can afford per-entity cardinality.

**Money is not aggregated here.** `economy.transaction`'s `amount` and
`store.purchase`'s `cost` are counted, not summed - a Prometheus counter
can't represent a signed amount, and a monitoring exporter re-deriving
financial totals from sampled telemetry is not an authoritative ledger.
Correctness-critical money totals belong in the game's own ledger, not here.

**Cardinality:** label values must be bounded, developer-controlled
dimensions. Never route untrusted input into a label - each distinct value
mints a new time series.

## Configuration

| Key | Default | Meaning |
| --- | --- | --- |
| `auto_setup` | `true` | Declare metrics and attach handlers at application start. Set `false` to call `asobi_metrics:setup/0` yourself. |

## Not covered - compose these instead

`asobi_metrics` only covers asobi's own telemetry surface. For the rest of a
typical asobi deployment:

- **Database** (kura/pgo) - [`opentelemetry_kura`](https://github.com/Taure/opentelemetry_kura)
- **Background jobs** (shigoto) - [`shigoto_metrics`](https://github.com/Taure/shigoto_metrics)
- **BEAM VM stats** - the [`prometheus`](https://hex.pm/packages/prometheus) dependency already
  ships VM collectors (`prometheus_vm_memory_collector`,
  `prometheus_vm_statistics_collector`, etc.); enable them directly, no
  asobi-specific glue needed.

There is no ECS or RPC layer in asobi, so those domains have no metrics to
export.

## License

Apache-2.0.
