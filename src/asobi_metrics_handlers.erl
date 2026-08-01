-module(asobi_metrics_handlers).
-moduledoc """
`m:telemetry` handlers that translate asobi events (ADR 0005 in `asobi`) into
Prometheus updates.

Attached by `asobi_metrics:setup/0`. Idempotent: attaching the same
`HandlerId` twice is a no-op. `handle/4` is total - a bad event is logged and
swallowed rather than raising, because `telemetry` detaches any handler that
throws, which would silently blank out every metric.
""".

-include_lib("kernel/include/logger.hrl").

-export([attach/1, detach/1, handle/4]).

-define(EVENTS, [
    [asobi, match, started],
    [asobi, match, finished],
    [asobi, match, player_joined],
    [asobi, match, player_left],
    [asobi, world, started],
    [asobi, world, finished],
    [asobi, world, player_joined],
    [asobi, world, player_left],
    [asobi, world, phase_changed],
    [asobi, matchmaker, queued],
    [asobi, matchmaker, removed],
    [asobi, matchmaker, formed],
    [asobi, matchmaker, failed],
    [asobi, session, connected],
    [asobi, session, disconnected],
    [asobi, ws, connected],
    [asobi, ws, disconnected],
    [asobi, ws, message_in],
    [asobi, ws, message_out],
    [asobi, ws, connect_rate_limited],
    [asobi, ws, idle_auth_timeout],
    [asobi, ws, origin_rejected],
    [asobi, join, rate_limited],
    [asobi, rehome, rate_limited],
    [asobi, anticheat, violation],
    [asobi, error],
    [asobi, economy, transaction],
    [asobi, store, purchase],
    [asobi, chat, message_sent],
    [asobi, vote, started],
    [asobi, vote, cast],
    [asobi, vote, resolved],
    [asobi, auth_cache, hit],
    [asobi, auth_cache, miss],
    [asobi, auth_cache, sweep]
]).

-define(LABEL_MAX, 128).

-spec attach(term()) -> ok.
attach(HandlerId) ->
    case telemetry:attach_many(HandlerId, ?EVENTS, fun ?MODULE:handle/4, []) of
        ok -> ok;
        {error, already_exists} -> ok
    end.

-spec detach(term()) -> ok.
detach(HandlerId) ->
    _ = telemetry:detach(HandlerId),
    ok.

-spec handle(telemetry:event_name(), map(), map(), term()) -> ok.
handle(Event, Measurements, Meta, Config) ->
    try
        do_handle(Event, Measurements, Meta, Config)
    catch
        Class:Reason:Stack ->
            ?LOG_WARNING(#{
                msg => ~"asobi_metrics_handler_error",
                event => Event,
                class => Class,
                reason => Reason,
                stacktrace => Stack
            }),
            ok
    end.

do_handle([asobi, match, started], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_match_started_total, [mode(Meta)]),
    ok;
do_handle([asobi, match, finished], Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_match_finished_total, []),
    prometheus_histogram:observe(
        asobi_match_duration_seconds, [], ms_to_seconds(maps:get(duration_ms, Measurements, 0))
    ),
    ok;
do_handle([asobi, match, player_joined], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_match_player_joined_total, []),
    ok;
do_handle([asobi, match, player_left], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_match_player_left_total, []),
    ok;
do_handle([asobi, world, started], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_world_started_total, [mode(Meta)]),
    ok;
do_handle([asobi, world, finished], Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_world_finished_total, []),
    prometheus_histogram:observe(
        asobi_world_duration_seconds, [], ms_to_seconds(maps:get(duration_ms, Measurements, 0))
    ),
    ok;
do_handle([asobi, world, player_joined], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_world_player_joined_total, []),
    ok;
do_handle([asobi, world, player_left], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_world_player_left_total, []),
    ok;
do_handle([asobi, world, phase_changed], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_world_phase_changed_total, [
        label(maps:get(from_phase, Meta, undefined)), label(maps:get(to_phase, Meta, undefined))
    ]),
    ok;
do_handle([asobi, matchmaker, queued], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_matchmaker_queued_total, [mode(Meta)]),
    ok;
do_handle([asobi, matchmaker, removed], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_matchmaker_removed_total, [
        label(maps:get(reason, Meta, undefined))
    ]),
    ok;
do_handle([asobi, matchmaker, formed], Measurements, Meta, _Config) ->
    Mode = mode(Meta),
    prometheus_counter:inc(asobi_matchmaker_formed_total, [Mode]),
    prometheus_histogram:observe(
        asobi_matchmaker_wait_seconds, [Mode], ms_to_seconds(maps:get(wait_ms, Measurements, 0))
    ),
    ok;
do_handle([asobi, matchmaker, failed], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_matchmaker_failed_total, [mode(Meta)]),
    ok;
do_handle([asobi, session, connected], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_sessions_connected_total, []),
    ok;
do_handle([asobi, session, disconnected], Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_sessions_disconnected_total, []),
    prometheus_histogram:observe(
        asobi_session_duration_seconds, [], ms_to_seconds(maps:get(duration_ms, Measurements, 0))
    ),
    ok;
do_handle([asobi, ws, connected], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_ws_connected_total, []),
    ok;
do_handle([asobi, ws, disconnected], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_ws_disconnected_total, []),
    ok;
do_handle([asobi, ws, message_in], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_ws_message_in_total, [label(maps:get(type, Meta, undefined))]),
    ok;
do_handle([asobi, ws, message_out], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_ws_message_out_total, [label(maps:get(type, Meta, undefined))]),
    ok;
do_handle([asobi, ws, connect_rate_limited], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_ws_connect_rate_limited_total, []),
    ok;
do_handle([asobi, ws, idle_auth_timeout], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_ws_idle_auth_timeout_total, []),
    ok;
do_handle([asobi, ws, origin_rejected], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_ws_origin_rejected_total, []),
    ok;
do_handle([asobi, join, rate_limited], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_join_rate_limited_total, []),
    ok;
do_handle([asobi, rehome, rate_limited], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_rehome_rate_limited_total, []),
    ok;
do_handle([asobi, anticheat, violation], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_anticheat_violations_total, [
        label(maps:get(type, Meta, undefined))
    ]),
    ok;
do_handle([asobi, error], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_errors_total, [label(maps:get(kind, Meta, undefined))]),
    ok;
do_handle([asobi, economy, transaction], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_economy_transactions_total, [
        label(maps:get(currency, Meta, undefined)), label(maps:get(reason, Meta, undefined))
    ]),
    ok;
do_handle([asobi, store, purchase], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_store_purchases_total, []),
    ok;
do_handle([asobi, chat, message_sent], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_chat_messages_total, []),
    ok;
do_handle([asobi, vote, started], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_vote_started_total, [label(maps:get(method, Meta, undefined))]),
    ok;
do_handle([asobi, vote, cast], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_vote_cast_total, []),
    ok;
do_handle([asobi, vote, resolved], Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_vote_resolved_total, []),
    prometheus_histogram:observe(
        asobi_vote_duration_seconds, [], ms_to_seconds(maps:get(duration_ms, Measurements, 0))
    ),
    ok;
do_handle([asobi, auth_cache, hit], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_auth_cache_hits_total, [label(maps:get(kind, Meta, undefined))]),
    ok;
do_handle([asobi, auth_cache, miss], _Measurements, Meta, _Config) ->
    prometheus_counter:inc(asobi_auth_cache_misses_total, [
        label(maps:get(kind, Meta, undefined))
    ]),
    ok;
do_handle([asobi, auth_cache, sweep], _Measurements, _Meta, _Config) ->
    prometheus_counter:inc(asobi_auth_cache_sweeps_total, []),
    ok;
do_handle(_Event, _Measurements, _Meta, _Config) ->
    ok.

mode(Meta) ->
    label(maps:get(mode, Meta, undefined)).

ms_to_seconds(N) when is_number(N), N >= 0 ->
    N / 1000;
ms_to_seconds(_) ->
    0.0.

%% Labels come from bounded developer-controlled metadata; the fallback only
%% guards against an unexpected term and is truncated so it can never mint a
%% giant, high-cardinality label value.
label(undefined) -> ~"unknown";
label(A) when is_atom(A) -> atom_to_binary(A);
label(B) when is_binary(B) -> truncate(B);
label(I) when is_integer(I) -> integer_to_binary(I);
label(Term) -> truncate(iolist_to_binary(io_lib:format("~p", [Term]))).

truncate(Bin) when byte_size(Bin) =< ?LABEL_MAX ->
    Bin;
truncate(Bin) ->
    <<Head:?LABEL_MAX/binary, _/binary>> = Bin,
    <<Head/binary, "...">>.
