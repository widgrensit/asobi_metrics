# Security

## Reporting a vulnerability

Open a private security advisory on GitHub.

## Surface

`asobi_metrics` has **no network surface of its own**: it declares Prometheus
metrics and attaches `telemetry` handlers, and stands up no listener. Its only
runtime dependencies are `telemetry` and `prometheus`.

The `/metrics` scrape output (`asobi_metrics:scrape/0`) is served by *your*
application's web layer, so exposure and authentication are governed there.
The output is operational metadata - match/world/session throughput, error
and rate-limit rejection counts, matchmaker wait times - so serve it on an
operator-only interface, never on asobi's player-facing WebSocket listener or
the public internet.

## Label cardinality

Metric label values must be bounded, developer-controlled dimensions. Never
route untrusted input (a `player_id`, a `match_id`, a `peer_ip`) into a label;
each distinct value creates a new time series, and unbounded values are a
cardinality denial-of-service on the exporter and the scraping Prometheus. See
the `asobi_metrics_definitions` moduledoc and
[ADR 0005](https://github.com/widgrensit/asobi/blob/main/docs/adr/0005-telemetry-event-surface.md)
in `asobi` for the full label-safety classification.
