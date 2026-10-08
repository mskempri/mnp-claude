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
```

| Project | Responsibility |
|---|---|
| `src/Mnp.Api` | ASP.NET Core Web API — controllers, DI composition root, config |
| `src/Mnp.Application` | Orchestration services and the abstractions (`IPortingRequestRepository`, `ICarrierNetworkClient`) they depend on |
| `src/Mnp.Domain` | Plain entities/enums shared across layers — no framework dependencies |
| `src/Mnp.Infrastructure.Database` | Calls Oracle PL/SQL packages via ODP.NET (`Oracle.ManagedDataAccess.Core`) |
| `src/Mnp.Infrastructure.ExternalApis` | Outbound HTTP clients to external carrier/registry APIs, with resilience (retry/timeout/circuit breaker) |
| `src/Mnp.MockExternalApis` | Dev-only stand-in for external APIs (currently: donor subscriber validation) so the full HTTP round trip is testable locally without a real sandbox |
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
3. Build, then run both the API and its local mock external API:
   ```bash
   dotnet build
   dotnet run --project src/Mnp.MockExternalApis &
   dotnet run --project src/Mnp.Api
   ```

## Testing

```bash
dotnet test
```

`tests/Mnp.Application.Tests` and `tests/Mnp.Infrastructure.Database.Tests` are
scaffolded (xUnit) but currently empty — add tests as behavior is implemented.

## Status

Covers the **Port Request Orchestration** and **SLA/Timer** services from the
target feature set, plus a working (mock-backed) slice of donor-network
validation. Not yet built: Number/Routing Lookup, the rest of Eligibility &
Validation, Fraud/Number-Snatching Prevention, and the outbox's relay worker
(events are enqueued, nothing reads them yet).

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

Known simplifications, not oversights: the timer sweep has no scheduled
caller yet (call `PKG_TIMERS.fn_sweep_and_process_one_expired_timer`
manually/via a cron for now); it also doesn't guarantee oldest-expired-first
processing under concurrent callers (see the comment in `pkg_timers.pkb`).
The Greek holiday calendar only has fixed-date 2026 holidays seeded — the four
movable Orthodox feast dates are deliberately left out pending confirmation
against an authoritative source, not guessed at.
