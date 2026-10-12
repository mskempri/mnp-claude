# Mobile Number Portability (MNP) Platform

.NET communication layer + Oracle PL/SQL business logic for mobile number
porting requests.

## Architecture

Business rules — validation, and critically the state machine itself — live in
PL/SQL in the database, as **data**, not hardcoded code: a config-driven rule
engine (`PKG_WORKFLOW_ENGINE` + `mnp_workflow_branches`/`mnp_workflow_actions`)
decides what happens next for a given status + event, including timers
(`PKG_TIMERS`/`PKG_CALENDAR`) and outbound notifications (as outbox rows, see
below). .NET exists to move data across process/network boundaries: HTTP in
from clients, SQL to/from Oracle, HTTP out to external carrier-network APIs.
.NET never decides what status a request ends up in — it raises events and
reads back what the engine decided. See
[database/README.md](database/README.md) for how the engine works.

```
Client -> Mnp.Api (controllers)
             -> Mnp.Application (orchestration: PortingRequestService)
                  -> Mnp.Infrastructure.Database     -> Oracle (PKG_PORTING_REQUESTS -> PKG_WORKFLOW_ENGINE)
                  -> Mnp.Infrastructure.ExternalApis  -> external carrier-network APIs (Mnp.MockExternalApis locally)

Mnp.Worker (separate always-running process)
             -> Mnp.Application (orchestration: OutboxRelayService)
                  -> Mnp.Infrastructure.Database     -> Oracle (PKG_OUTBOX)
                  -> Mnp.Infrastructure.ExternalApis  -> carrier/customer notification APIs (Mnp.MockExternalApis locally)
```

| Project | Responsibility |
|---|---|
| `src/Mnp.Api` | ASP.NET Core Web API — controllers, DI composition root, config |
| `src/Mnp.Worker` | Background host — polls the outbox and relays notifications via `OutboxRelayService` |
| `src/Mnp.Application` | Orchestration services and the abstractions (`IPortingRequestRepository`, `ICarrierNetworkClient`, `IOutboxRepository`, notification clients) they depend on |
| `src/Mnp.Domain` | Plain entities/enums shared across layers — no framework dependencies |
| `src/Mnp.Infrastructure.Database` | Calls Oracle PL/SQL packages via ODP.NET (`Oracle.ManagedDataAccess.Core`) |
| `src/Mnp.Infrastructure.ExternalApis` | Outbound HTTP clients to external carrier/registry/notification APIs, with resilience (retry/timeout/circuit breaker) |
| `src/Mnp.MockExternalApis` | Dev-only stand-in for external APIs (donor subscriber validation, carrier/customer notifications) so the full HTTP round trip is testable locally without a real sandbox |
| `database/` | Table DDL, PL/SQL packages, and seed data — see [database/README.md](database/README.md) |

## Prerequisites

- .NET 10 SDK
- Access to an Oracle database. For local dev, `docker-compose.yml` at the repo
  root runs [gvenzl/oracle-free](https://github.com/gvenzl/oci-oracle-free) (a
  community image built specifically for this kind of dev/test use — no Oracle
  registry login needed, native arm64 + amd64 images) under Podman or Docker.

## Local Oracle (dev)

```bash
cp .env.example .env   # fill in ORACLE_PASSWORD / APP_USER_PASSWORD, or generate your own
podman machine start   # if using Podman and the VM isn't already running
podman compose up -d   # or: docker compose up -d
podman logs -f mnp-oracle   # watch for "DATABASE IS READY TO USE!" (first run takes a few minutes)
```

This creates an `mnp_app` user in the `FREEPDB1` pluggable database, reachable at
`localhost:1521/FREEPDB1`. Apply the schema, then **all** package specs before
**any** package body (they call each other across packages), then seed data:

```bash
source .env
run() { podman exec -i mnp-oracle sqlplus -s mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 < "$1"; }

for f in database/schema/*.sql; do run "$f"; done
for f in database/packages/*.pks; do run "$f"; done
for f in database/packages/*.pkb; do run "$f"; done
for f in database/seed/*.sql; do run "$f"; done
```

See [database/README.md](database/README.md) for script conventions and what
the rule engine/timers/outbox tables are for.

## Setup

1. Install the SDK (already done on this machine via `brew install dotnet`; add
   `/opt/homebrew/opt/dotnet/libexec` to `DOTNET_ROOT` and your `PATH` if not
   using the cask install).
2. Configure the Oracle connection string via user-secrets instead of editing
   `appsettings.json` (keeps real connection strings out of source control):
   ```bash
   cd src/Mnp.Api
   dotnet user-secrets init
   dotnet user-secrets set "ConnectionStrings:Oracle" "User Id=mnp_app;Password=<APP_USER_PASSWORD from .env>;Data Source=localhost:1521/FREEPDB1;"
   cd ../..
   ```
   `CarrierNetwork:BaseUrl` doesn't need a secret for local dev — it already
   points at `Mnp.MockExternalApis` via `appsettings.Development.json`.
3. Build, then run the mock external API, the outbox relay worker, and the API:
   ```bash
   dotnet build
   dotnet run --project src/Mnp.MockExternalApis &
   dotnet run --project src/Mnp.Worker &
   dotnet run --project src/Mnp.Api
   ```

## Testing

```bash
dotnet test
```

`tests/Mnp.Application.Tests` and `tests/Mnp.Infrastructure.Database.Tests` are
scaffolded (xUnit) but currently empty — add tests as behavior is implemented.

## Status

Covers all six services from the target feature set: **Port Request
Orchestration**, **SLA/Timer**, **Notification/Event**, **Eligibility &
Validation**, **Number/Routing Lookup**, and **Fraud/Number-Snatching
Prevention**. What remains are documented, deliberate deferrals (see below
and [PHASES.md](PHASES.md) for the full phased build plan), not missing
services.

Verified end-to-end against a real local Oracle instance (not just
type-checked): the full lifecycle `RECEIVED -> APPROVED -> SCHEDULED ->
CUTOVER -> COMPLETED` plus rejection and cancellation paths, via both direct
PL/SQL calls and the running HTTP API (`POST /api/porting-requests`,
`POST /api/porting-requests/{id}/events`); branch-exclusivity (two branches for
the same status+event can't both fire); `HALT` truncating a branch's remaining
actions; an unknown condition name and an unhandled event both raising instead
of silently no-opping; the timer sweep's `FOR UPDATE SKIP LOCKED` claim
preventing two concurrent sweepers from double-processing the same expired
timer. `Mnp.MockExternalApis` closes the one previously-flagged gap: the
donor-validation HTTP call now succeeds against a real (if fake) endpoint
instead of failing DNS resolution.

The outbox relay (`Mnp.Worker` + `PKG_OUTBOX`) is also verified end-to-end:
dispatch-by-audience routing (donor/recipient network, customer, and an
internal `OPERATIONS` log-only path) against all three services running
together; `FOR UPDATE SKIP LOCKED` double-claim prevention; a claimed row
with unparseable data (e.g. a NULL audience) failing gracefully through the
retry path instead of crashing the worker host; and the full
failed-attempt -> `DEAD_LETTER` progression, confirming a dead-lettered row
is never claimed again and the worker keeps polling throughout.

Eligibility & Validation (`PAC` code validation + the `VALIDATING` status)
is also verified end-to-end: malformed and expired PAC codes are rejected
with no row inserted; a valid submission lands in `VALIDATING` (not
`RECEIVED`) with its SLA timer already running; `VALIDATING` correctly
reaches `APPROVED`/`REJECTED`/`CANCELLED`; the SLA timer sweep fires an
internal alert from `VALIDATING` without changing status; and the donor-network
HTTP call now happens *after* the request is persisted, so a failed/crashed
call leaves a visible, timer-tracked request instead of silently losing the
submission.

The Number/Routing Lookup service (`PKG_NUMBER_REGISTRY` +
`mnp_number_ownership`) is verified end-to-end too: an untracked MSISDN
returns `404` from `GET /api/number-ownership/{msisdn}`; driving a request to
`COMPLETED` (both directly via PL/SQL and via the live HTTP API) populates
exactly one registry row with the right current owner; porting the same
MSISDN again updates that row rather than duplicating it.

Fraud/Number-Snatching Prevention (`PKG_FRAUD_PREVENTION`) is verified
end-to-end too: 3 requests for the same MSISDN succeed, a 4th within the
velocity window is blocked with no row inserted, and a different MSISDN is
unaffected by the first one's history — confirmed via direct PL/SQL and via
the live HTTP API (3x `201`, 4th -> `500`).

Known simplifications, not oversights: the timer sweep has no scheduled
caller yet (call `PKG_TIMERS.fn_sweep_and_process_one_expired_timer`
manually/via a cron for now); it also doesn't guarantee oldest-expired-first
processing under concurrent callers (see the comment in `pkg_timers.pkb`).
The Greek holiday calendar only has fixed-date 2026 holidays seeded — the four
movable Orthodox feast dates are deliberately left out pending confirmation
against an authoritative source, not guessed at. The outbox relay has no
stale-claim reclaim — if `Mnp.Worker` crashes mid-dispatch, that row stays
`CLAIMED` forever (see [database/README.md](database/README.md#notificationevent)).
Eligibility checks real MSISDN format, PAC format/expiry, and donor-reported
subscriber identity/account status, but not MSISDN-to-donor-network
*ownership* — the registry that tracks ownership now exists, but
`fn_create_request` deliberately doesn't consult it yet (see
[database/README.md](database/README.md#numberrouting-lookup)). A blocked
fraud-velocity attempt isn't surfaced to Operations via the outbox (it never
creates a request row to hang a notification on) and isn't audited to a log
table (no existing precedent for auditing pre-engine guard failures).
