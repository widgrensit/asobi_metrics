-module(asobi_metrics_definitions).
-moduledoc """
Declares the Prometheus metrics that `asobi_metrics_handlers` updates from
asobi's telemetry surface (see
[ADR 0005](https://github.com/widgrensit/asobi/blob/main/docs/adr/0005-telemetry-event-surface.md)
in `asobi`).

High-cardinality keys (`match_id`, `world_id`, `player_id`, `sender_id`,
`vote_id`, `item_id`, `channel_id`, `peer_ip`) deliberately stay out of every
metric label; they remain on the raw telemetry events for tracing/audit sinks
(e.g. `opentelemetry_asobi`) that can afford per-entity cardinality. Labels are
limited to bounded, game/protocol-declared dimensions: `mode`, `reason`,
`kind`, `type`, `method`, `currency`, `from_phase`, `to_phase`.

Label values MUST be bounded, developer-controlled dimensions. Never route
untrusted input into a label: each distinct value mints a new Prometheus
series and unbounded values are a cardinality DoS on both the exporter and
the scraping Prometheus.

Economy and store amounts (`amount`, `cost`) are intentionally NOT summed
into a Prometheus counter or gauge here. They can be negative (a debit), and
a monitoring exporter re-deriving financial totals from telemetry sampling
is not an authoritative ledger - that would invite treating an ops metric as
a source of truth it was never meant to be. Only transaction *counts* are
exported; correctness-critical money totals belong in the game's own ledger.
""".

-export([declare/0]).

%% Matches/worlds run minutes to roughly an hour; sessions can run for hours.
-define(MATCH_DURATION_BUCKETS, [1, 5, 15, 30, 60, 120, 300, 600, 1800, 3600]).
-define(SESSION_DURATION_BUCKETS, [1, 10, 30, 60, 300, 900, 1800, 3600, 7200, 14400]).
-define(WAIT_BUCKETS, [0.1, 0.5, 1, 5, 10, 30, 60, 120, 300]).
-define(VOTE_DURATION_BUCKETS, [1, 5, 10, 15, 30, 60, 120, 300]).

-spec declare() -> ok.
declare() ->
    counters(),
    histograms(),
    ok.

counters() ->
    match_counters(),
    world_counters(),
    matchmaker_counters(),
    session_counters(),
    ws_counters(),
    misc_counters(),
    ok.

match_counters() ->
    prometheus_counter:declare([
        {name, asobi_match_started_total},
        {help, "Total matches started."},
        {labels, [mode]}
    ]),
    prometheus_counter:declare([
        {name, asobi_match_finished_total},
        {help, "Total matches finished."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_match_player_joined_total},
        {help, "Total match-join events."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_match_player_left_total},
        {help, "Total match-leave events."},
        {labels, []}
    ]),
    ok.

world_counters() ->
    prometheus_counter:declare([
        {name, asobi_world_started_total},
        {help, "Total worlds started."},
        {labels, [mode]}
    ]),
    prometheus_counter:declare([
        {name, asobi_world_finished_total},
        {help, "Total worlds finished."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_world_player_joined_total},
        {help, "Total world-join events."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_world_player_left_total},
        {help, "Total world-leave events."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_world_phase_changed_total},
        {help, "Total world phase transitions."},
        {labels, [from_phase, to_phase]}
    ]),
    ok.

matchmaker_counters() ->
    prometheus_counter:declare([
        {name, asobi_matchmaker_queued_total},
        {help, "Total players queued for matchmaking."},
        {labels, [mode]}
    ]),
    prometheus_counter:declare([
        {name, asobi_matchmaker_removed_total},
        {help, "Total players removed from a matchmaking queue before forming."},
        {labels, [reason]}
    ]),
    prometheus_counter:declare([
        {name, asobi_matchmaker_formed_total},
        {help, "Total matchmaker groups formed."},
        {labels, [mode]}
    ]),
    prometheus_counter:declare([
        {name, asobi_matchmaker_failed_total},
        {help, "Total matchmaker forming attempts that failed."},
        {labels, [mode]}
    ]),
    ok.

session_counters() ->
    prometheus_counter:declare([
        {name, asobi_sessions_connected_total},
        {help, "Total player sessions connected."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_sessions_disconnected_total},
        {help, "Total player sessions disconnected."},
        {labels, []}
    ]),
    ok.

ws_counters() ->
    prometheus_counter:declare([
        {name, asobi_ws_connected_total},
        {help, "Total WebSocket connections accepted."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_ws_disconnected_total},
        {help, "Total WebSocket connections closed."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_ws_message_in_total},
        {help, "Total inbound WebSocket messages."},
        {labels, [type]}
    ]),
    prometheus_counter:declare([
        {name, asobi_ws_message_out_total},
        {help, "Total outbound WebSocket messages."},
        {labels, [type]}
    ]),
    prometheus_counter:declare([
        {name, asobi_ws_connect_rate_limited_total},
        {help, "Total WebSocket connection attempts rejected by the per-IP rate limit."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_ws_idle_auth_timeout_total},
        {help, "Total WebSocket connections closed for failing to authenticate in time."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_ws_origin_rejected_total},
        {help, "Total WebSocket upgrades rejected by the Origin allowlist."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_join_rate_limited_total},
        {help, "Total joins rejected by the per-identity join rate cap."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_rehome_rate_limited_total},
        {help, "Total zone-crossings rejected by the per-identity rehome rate cap."},
        {labels, []}
    ]),
    ok.

misc_counters() ->
    prometheus_counter:declare([
        {name, asobi_anticheat_violations_total},
        {help, "Total anticheat violations detected."},
        {labels, [type]}
    ]),
    prometheus_counter:declare([
        {name, asobi_errors_total},
        {help, "Total game-code errors (e.g. a Lua callback raising)."},
        {labels, [kind]}
    ]),
    prometheus_counter:declare([
        {name, asobi_economy_transactions_total},
        {help, "Total economy transactions. Amounts are not aggregated here - see moduledoc."},
        {labels, [currency, reason]}
    ]),
    prometheus_counter:declare([
        {name, asobi_store_purchases_total},
        {help, "Total store purchases. Costs are not aggregated here - see moduledoc."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_chat_messages_total},
        {help, "Total chat messages sent."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_vote_started_total},
        {help, "Total votes started."},
        {labels, [method]}
    ]),
    prometheus_counter:declare([
        {name, asobi_vote_cast_total},
        {help, "Total ballots cast."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_vote_resolved_total},
        {help, "Total votes resolved."},
        {labels, []}
    ]),
    prometheus_counter:declare([
        {name, asobi_auth_cache_hits_total},
        {help, "Total auth cache hits."},
        {labels, [kind]}
    ]),
    prometheus_counter:declare([
        {name, asobi_auth_cache_misses_total},
        {help, "Total auth cache misses."},
        {labels, [kind]}
    ]),
    prometheus_counter:declare([
        {name, asobi_auth_cache_sweeps_total},
        {help, "Total auth cache sweep passes."},
        {labels, []}
    ]),
    ok.

histograms() ->
    prometheus_histogram:declare([
        {name, asobi_match_duration_seconds},
        {help, "Wall-clock duration of a finished match."},
        {labels, []},
        {buckets, ?MATCH_DURATION_BUCKETS}
    ]),
    prometheus_histogram:declare([
        {name, asobi_world_duration_seconds},
        {help, "Wall-clock duration of a finished world."},
        {labels, []},
        {buckets, ?MATCH_DURATION_BUCKETS}
    ]),
    prometheus_histogram:declare([
        {name, asobi_matchmaker_wait_seconds},
        {help, "Time players waited for a matchmaker group to form."},
        {labels, [mode]},
        {buckets, ?WAIT_BUCKETS}
    ]),
    prometheus_histogram:declare([
        {name, asobi_session_duration_seconds},
        {help, "Wall-clock duration of a player session."},
        {labels, []},
        {buckets, ?SESSION_DURATION_BUCKETS}
    ]),
    prometheus_histogram:declare([
        {name, asobi_vote_duration_seconds},
        {help, "Wall-clock duration from vote start to resolution."},
        {labels, []},
        {buckets, ?VOTE_DURATION_BUCKETS}
    ]),
    ok.
