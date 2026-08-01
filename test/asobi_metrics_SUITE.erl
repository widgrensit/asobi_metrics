-module(asobi_metrics_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([
    setup_is_idempotent/1,
    match_lifecycle_increments_counters/1,
    world_phase_changed_records_labels/1,
    matchmaker_formed_records_wait/1,
    session_disconnected_records_duration/1,
    ws_events_increment_counters/1,
    rate_limit_events_increment_counters/1,
    anticheat_and_error_events_increment_counters/1,
    economy_and_store_events_increment_counters/1,
    vote_lifecycle_increments_counters/1,
    auth_cache_events_increment_counters/1,
    unknown_event_is_ignored/1,
    scrape_returns_prometheus_text/1
]).

all() ->
    [
        setup_is_idempotent,
        match_lifecycle_increments_counters,
        world_phase_changed_records_labels,
        matchmaker_formed_records_wait,
        session_disconnected_records_duration,
        ws_events_increment_counters,
        rate_limit_events_increment_counters,
        anticheat_and_error_events_increment_counters,
        economy_and_store_events_increment_counters,
        vote_lifecycle_increments_counters,
        auth_cache_events_increment_counters,
        unknown_event_is_ignored,
        scrape_returns_prometheus_text
    ].

init_per_suite(Config) ->
    application:set_env(asobi_metrics, auto_setup, false),
    {ok, _} = application:ensure_all_started(asobi_metrics),
    ok = asobi_metrics:setup(),
    Config.

end_per_suite(_Config) ->
    ok = application:stop(asobi_metrics),
    ok.

setup_is_idempotent(_Config) ->
    ok = asobi_metrics:setup(),
    ok = asobi_metrics:setup(),
    ok.

match_lifecycle_increments_counters(_Config) ->
    Before = counter_value(asobi_match_started_total, [~"ffa"]),
    telemetry:execute([asobi, match, started], #{count => 1}, #{
        match_id => ~"m1", mode => ~"ffa"
    }),
    telemetry:execute([asobi, match, finished], #{duration_ms => 120_000, count => 1}, #{
        match_id => ~"m1", result => #{winner => ~"p1"}
    }),
    telemetry:execute([asobi, match, player_joined], #{count => 1}, #{
        match_id => ~"m1", player_id => ~"p1"
    }),
    telemetry:execute([asobi, match, player_left], #{count => 1}, #{
        match_id => ~"m1", player_id => ~"p1"
    }),
    ?assertEqual(Before + 1, counter_value(asobi_match_started_total, [~"ffa"])),
    ?assertEqual(1, counter_value(asobi_match_finished_total, [])),
    ?assertEqual(1, histogram_count(asobi_match_duration_seconds, [])),
    ?assertEqual(1, counter_value(asobi_match_player_joined_total, [])),
    ?assertEqual(1, counter_value(asobi_match_player_left_total, [])).

world_phase_changed_records_labels(_Config) ->
    telemetry:execute([asobi, world, started], #{count => 1}, #{
        world_id => ~"w1", mode => ~"pve"
    }),
    telemetry:execute([asobi, world, phase_changed], #{count => 1}, #{
        world_id => ~"w1", from_phase => ~"lobby", to_phase => ~"combat"
    }),
    ?assertEqual(1, counter_value(asobi_world_started_total, [~"pve"])),
    ?assertEqual(
        1, counter_value(asobi_world_phase_changed_total, [~"lobby", ~"combat"])
    ).

matchmaker_formed_records_wait(_Config) ->
    telemetry:execute(
        [asobi, matchmaker, formed],
        #{player_count => 4, wait_ms => 3_000, count => 1},
        #{mode => ~"duo"}
    ),
    telemetry:execute([asobi, matchmaker, failed], #{player_count => 1, count => 1}, #{
        mode => ~"duo"
    }),
    ?assertEqual(1, counter_value(asobi_matchmaker_formed_total, [~"duo"])),
    ?assertEqual(1, histogram_count(asobi_matchmaker_wait_seconds, [~"duo"])),
    ?assertEqual(1, counter_value(asobi_matchmaker_failed_total, [~"duo"])).

session_disconnected_records_duration(_Config) ->
    telemetry:execute([asobi, session, connected], #{count => 1}, #{player_id => ~"p1"}),
    telemetry:execute([asobi, session, disconnected], #{duration_ms => 60_000, count => 1}, #{
        player_id => ~"p1"
    }),
    ?assertEqual(1, counter_value(asobi_sessions_connected_total, [])),
    ?assertEqual(1, counter_value(asobi_sessions_disconnected_total, [])),
    ?assertEqual(1, histogram_count(asobi_session_duration_seconds, [])).

ws_events_increment_counters(_Config) ->
    telemetry:execute([asobi, ws, connected], #{count => 1}, #{}),
    telemetry:execute([asobi, ws, message_in], #{count => 1}, #{type => ~"move"}),
    telemetry:execute([asobi, ws, message_out], #{count => 1}, #{type => ~"state"}),
    telemetry:execute([asobi, ws, disconnected], #{count => 1}, #{}),
    ?assertEqual(1, counter_value(asobi_ws_connected_total, [])),
    ?assertEqual(1, counter_value(asobi_ws_message_in_total, [~"move"])),
    ?assertEqual(1, counter_value(asobi_ws_message_out_total, [~"state"])),
    ?assertEqual(1, counter_value(asobi_ws_disconnected_total, [])).

rate_limit_events_increment_counters(_Config) ->
    telemetry:execute([asobi, ws, connect_rate_limited], #{count => 1}, #{
        peer_ip => ~"203.0.113.1"
    }),
    telemetry:execute([asobi, ws, idle_auth_timeout], #{count => 1}, #{}),
    telemetry:execute([asobi, ws, origin_rejected], #{count => 1}, #{}),
    telemetry:execute([asobi, join, rate_limited], #{count => 1}, #{player_id => ~"p1"}),
    telemetry:execute([asobi, rehome, rate_limited], #{count => 1}, #{player_id => ~"p1"}),
    ?assertEqual(1, counter_value(asobi_ws_connect_rate_limited_total, [])),
    ?assertEqual(1, counter_value(asobi_ws_idle_auth_timeout_total, [])),
    ?assertEqual(1, counter_value(asobi_ws_origin_rejected_total, [])),
    ?assertEqual(1, counter_value(asobi_join_rate_limited_total, [])),
    ?assertEqual(1, counter_value(asobi_rehome_rate_limited_total, [])).

anticheat_and_error_events_increment_counters(_Config) ->
    telemetry:execute([asobi, anticheat, violation], #{count => 1}, #{
        player_id => ~"p1", type => speed_hack, details => #{}
    }),
    telemetry:execute([asobi, error], #{count => 1}, #{kind => lua_error, details => #{}}),
    ?assertEqual(1, counter_value(asobi_anticheat_violations_total, [~"speed_hack"])),
    ?assertEqual(1, counter_value(asobi_errors_total, [~"lua_error"])).

economy_and_store_events_increment_counters(_Config) ->
    telemetry:execute([asobi, economy, transaction], #{amount => 100, count => 1}, #{
        player_id => ~"p1", currency => ~"gold", reason => ~"quest_reward"
    }),
    telemetry:execute([asobi, store, purchase], #{cost => 500, count => 1}, #{
        player_id => ~"p1", item_id => ~"skin_01"
    }),
    telemetry:execute([asobi, chat, message_sent], #{count => 1}, #{
        channel_id => ~"global", sender_id => ~"p1"
    }),
    ?assertEqual(
        1, counter_value(asobi_economy_transactions_total, [~"gold", ~"quest_reward"])
    ),
    ?assertEqual(1, counter_value(asobi_store_purchases_total, [])),
    ?assertEqual(1, counter_value(asobi_chat_messages_total, [])).

vote_lifecycle_increments_counters(_Config) ->
    telemetry:execute([asobi, vote, started], #{count => 1}, #{
        vote_id => ~"v1", method => ~"majority"
    }),
    telemetry:execute([asobi, vote, cast], #{count => 1}, #{vote_id => ~"v1", player_id => ~"p1"}),
    telemetry:execute([asobi, vote, resolved], #{duration_ms => 15_000, count => 1}, #{
        vote_id => ~"v1", result => #{outcome => passed}
    }),
    ?assertEqual(1, counter_value(asobi_vote_started_total, [~"majority"])),
    ?assertEqual(1, counter_value(asobi_vote_cast_total, [])),
    ?assertEqual(1, counter_value(asobi_vote_resolved_total, [])),
    ?assertEqual(1, histogram_count(asobi_vote_duration_seconds, [])).

auth_cache_events_increment_counters(_Config) ->
    telemetry:execute([asobi, auth_cache, hit], #{count => 1}, #{kind => positive}),
    telemetry:execute([asobi, auth_cache, miss], #{count => 1}, #{kind => negative}),
    telemetry:execute([asobi, auth_cache, sweep], #{count => 1}, #{}),
    ?assertEqual(1, counter_value(asobi_auth_cache_hits_total, [~"positive"])),
    ?assertEqual(1, counter_value(asobi_auth_cache_misses_total, [~"negative"])),
    ?assertEqual(1, counter_value(asobi_auth_cache_sweeps_total, [])).

unknown_event_is_ignored(_Config) ->
    %% Not in the attached event list at all - telemetry itself is a no-op,
    %% but this proves handle/4 tolerates an event outside ?EVENTS too.
    ok = asobi_metrics_handlers:handle([asobi, unknown, thing], #{}, #{}, []).

scrape_returns_prometheus_text(_Config) ->
    Body = asobi_metrics:scrape(),
    ?assert(is_binary(Body)),
    ?assert(binary:match(Body, ~"asobi_match_started_total") =/= nomatch),
    ?assert(binary:match(Body, ~"asobi_matchmaker_wait_seconds") =/= nomatch),
    ?assert(binary:match(Body, ~"# HELP asobi_") =/= nomatch),
    ?assert(binary:match(Body, ~"# TYPE asobi_") =/= nomatch).

counter_value(Metric, Labels) ->
    case prometheus_counter:value(Metric, Labels) of
        undefined -> 0;
        V when is_number(V) -> V
    end.

histogram_count(Metric, Labels) ->
    case prometheus_histogram:value(Metric, Labels) of
        undefined -> 0;
        {Buckets, _Sum} -> lists:sum(Buckets)
    end.
