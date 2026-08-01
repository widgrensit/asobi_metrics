# AGENTS.md

Working agreement for agents and contributors on **asobi_metrics** - a
Prometheus exporter and starter Grafana dashboard for asobi.

## Ecosystem

An asobi companion library (all under https://github.com/widgrensit):

- **[asobi](https://github.com/widgrensit/asobi)** - game backend platform
  built on Nova/OTP (this library observes it).
- **[asobi_admin](https://github.com/widgrensit/asobi_admin)** - optional
  admin dashboard, another companion app in the same shape.

**This repo** exports asobi's telemetry events (the `[asobi, ...]` surface
documented in
[ADR 0005](https://github.com/widgrensit/asobi/blob/main/docs/adr/0005-telemetry-event-surface.md))
as Prometheus metrics and ships a starter Grafana dashboard. Keep it in
lockstep with any asobi release that changes the telemetry surface. asobi
core takes no dependency on this package.

Sibling pattern in a different ecosystem:
[`Taure/shigoto_metrics`](https://github.com/Taure/shigoto_metrics) does the
same thing for `shigoto`.

## Conventions

- OTP 29+. The `~"..."` sigil, never `<<"...">>`. No `lists:foldl/foldr`.
- JSON via the OTP `json` module. `?LOG_*` macros with `#{...}` map reports.
- Docs: OTP `-moduledoc` / `-doc`. `{vsn, "git"}` - version derives from git tags.
- Default to zero comments; comment only non-obvious *why*.
- Metric labels must stay bounded (see `asobi_metrics_definitions` moduledoc).
  Never add a label sourced from an unbounded telemetry metadata key
  (`match_id`, `world_id`, `player_id`, etc.) without re-reading that
  moduledoc and ADR 0005 first.

## Commands

```bash
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 fmt          # CI runs fmt --check
rebar3 xref
rebar3 dialyzer
rebar3 ex_doc
```

## Git and PRs

Conventional commits. Always open a PR - never push to `main`. Every merge to
`main` tags a release.
