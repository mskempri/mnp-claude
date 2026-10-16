# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build the whole solution
dotnet build

# Run all tests
dotnet test

# Run tests in a single project
dotnet test tests/Mnp.Application.Tests

# Run a single test by name
dotnet test tests/Mnp.Application.Tests --filter "FullyQualifiedName~ProcessNextAsync_ReturnsFalse"

# Run the full local stack (builds, then starts all three with logs
# redirected to logs/*.log instead of interleaving in one terminal)
scripts/run-local.sh

# Watch logs while the stack is running
tail -f logs/*.log

# Oracle connection string (do this once; never in appsettings.json)
cd src/Mnp.Api && dotnet user-secrets set "ConnectionStrings:Oracle" \
  "User Id=mnp_app;Password=<APP_USER_PASSWORD>;Data Source=localhost:1521/FREEPDB1;"
# Same for Mnp.Worker
cd src/Mnp.Worker && dotnet user-secrets set "ConnectionStrings:Oracle" \
  "User Id=mnp_app;Password=<APP_USER_PASSWORD>;Data Source=localhost:1521/FREEPDB1;"
```

## Oracle / Podman

```bash
source .env   # loads APP_USER_PASSWORD, ORACLE_PASSWORD
podman machine start
podman compose up -d
podman logs -f mnp-oracle   # wait for "DATABASE IS READY TO USE!"

# One-liner helper used throughout this project
run() { podman exec -i mnp-oracle sqlplus -s mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 < "$1"; }

# Apply schema + packages + seeds (order matters — all .pks before any .pkb)
for f in database/schema/*.sql; do run "$f"; done
for f in database/packages/*.pks; do run "$f"; done
for f in database/packages/*.pkb; do run "$f"; done
for f in database/seed/*.sql; do run "$f"; done

# Interactive SQL session
podman exec -it mnp-oracle sqlplus mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1

# PL/SQL block in a pipeline
podman exec -i mnp-oracle sqlplus -s mnp_app/"$APP_USER_PASSWORD"@localhost:1521/FREEPDB1 <<'SQLEOF'
BEGIN ... END;
/
exit;
SQLEOF
```

## Architecture

### Guiding rule
Business logic lives **entirely in PL/SQL**. .NET never decides what status a request ends up in — it raises events and reads back what the engine decided. Adding a new state transition means inserting rows into `mnp_workflow_branches`/`mnp_workflow_actions`, not changing .NET code.

### Request lifecycle

```
POST /api/porting-requests
  → PortingRequestsController
  → PortingRequestService.SubmitAsync
      → CarrierNetworkClient.ValidateSubscriberAsync  (HTTP to donor network / MockExternalApis)
      → PKG_PORTING_REQUESTS.FN_CREATE_REQUEST         (returns new id; internally raises REQUEST_RECEIVED)
      → PKG_PORTING_REQUESTS.PR_RAISE_EVENT(VALIDATION_PASSED | VALIDATION_FAILED)
           → PKG_WORKFLOW_ENGINE                        (matches branch, runs actions)
               → PKG_OUTBOX.PR_ENQUEUE                 (SEND_NOTIFICATION actions)
               → PKG_TIMERS.PR_START_TIMER             (START_TIMER actions)

Mnp.Worker (always running, separate process)
  → OutboxRelayWorker  (BackgroundService, polls every N seconds)
  → OutboxRelayService.ProcessNextAsync
      → PKG_OUTBOX.PR_CLAIM_NEXT_PENDING  (FOR UPDATE SKIP LOCKED — no double-claim)
      → dispatch by audience:
          DonorNetwork / RecipientNetwork  → CarrierNetworkNotificationClient (HTTP)
          Customer                         → CustomerNotificationClient (HTTP)
          Operations                       → ILogger.LogWarning only
      → PKG_OUTBOX.PR_MARK_PUBLISHED | PR_MARK_FAILED
```

### Rule engine
`PKG_WORKFLOW_ENGINE` interprets `mnp_workflow_branches` (status + event_type + condition + sequence) and `mnp_workflow_actions` (action_type + action_parameter + sequence). The first branch whose condition evaluates true is the **only** one that fires — mutual exclusion by construction. Unknown condition names and unhandled events raise rather than silently no-op. Every branch evaluation is logged to `mnp_workflow_audit_log`.

### ODP.NET calling convention
- Stored procedure calls: `CommandType.StoredProcedure`, `BindByName = true`, always `await using` connection and command.
- Return values from functions: unnamed first parameter (`OracleParameter` with `Direction = ReturnValue`), cast via `(OracleDecimal)param.Value`.
- Multi-column results: `SYS_REFCURSOR` OUT parameter → `(OracleRefCursor)param.Value` → `.GetDataReader()`.
- `FOR UPDATE` in PL/SQL doesn't support `FETCH FIRST N ROWS` or an ORDER BY'd inline view — use bare `ROWNUM = 1` on the base table instead (ORA-02014 otherwise). This means no guaranteed oldest-first ordering under concurrency.
- Nullable DB columns: always check `reader.IsDBNull(ordinal)` before `reader.GetString/GetInt64`.

### .NET layer shape
- `Mnp.Domain` — entities and enums only, no framework deps.
- `Mnp.Application` — orchestration services + interfaces (`IPortingRequestRepository`, `IOutboxRepository`, `ICarrierNetworkClient`, `ICarrierNetworkNotificationClient`, `ICustomerNotificationClient`). No DB or HTTP code here.
- `Mnp.Infrastructure.Database` — ODP.NET implementations. Enum ↔ VARCHAR2 mappings live in `*Mapping` classes (`PortingStatusMapping`, `NotificationAudienceMapping`). JSON payload parsing also lives here (infrastructure concern, mirrors how cursor rows are shaped into domain objects).
- `Mnp.Infrastructure.ExternalApis` — `IHttpClientFactory`-backed implementations with `AddStandardResilienceHandler()` (retry/circuit-breaker/timeout). Each external service gets its own `*Options` class bound with `ValidateDataAnnotations().ValidateOnStart()`.
- `Mnp.Api` — scoped DI (per-HTTP-request). `Mnp.Worker` — singleton DI (stateless, no per-request concept). Both use identical `AddOptions<T>().Bind(...).ValidateDataAnnotations().ValidateOnStart()` + `AddHttpClient<TInterface, TImpl>(...).AddStandardResilienceHandler()` wiring.

### Tests
`tests/Mnp.Application.Tests` — xUnit with hand-rolled fakes (no mocking library). See `OutboxRelayServiceTests` for the pattern: one `Fake*` class per interface, `sealed class` with a `List<...> Calls` property for assertions.

## PL/SQL conventions

- Tables: `mnp_<plural_noun>`, snake_case columns.
- Packages: `pkg_<aggregate>`. Public entry points: `fn_` (returns a value) / `pr_` (procedure).
- Enum-like columns: `VARCHAR2` + `CHECK` constraint, not a lookup table.
- New schema changes: add a new numbered `database/schema/NNN_*.sql`; never edit an already-applied script.
- All `RAISE_APPLICATION_ERROR` codes: `-20001` invalid MSISDN, `-20002` invalid/expired PAC code, `-20003` not found, `-20004` duplicate open request, `-20005` suspicious port velocity, `-20010` unknown timer code, `-20011` unknown condition name, `-20012` unhandled event, `-20013` unknown action type, `-20014` no running timer, `-20015` unknown notification event type.
- After seeding new workflow rules, re-run `database/seed/003_validate_reachability.sql` (expect: no rows) to confirm no status is stranded without a way out.
- After adding a new `SEND_NOTIFICATION` action parameter, add the matching row to `mnp_notification_types` and re-run `database/seed/005_validate_notification_registrations.sql` (expect: no rows).
- All timezone arithmetic uses `Europe/Athens` — never use `SYSDATE` or `SYSTIMESTAMP` raw; use `AT TIME ZONE 'Europe/Athens'` or `FROM_TZ`/`CAST ... AS DATE` patterns.

## What is not yet built

See [PHASES.md](PHASES.md) for the full build plan. All six services from the original spec are now built; what remains are deliberate, documented deferrals, not missing services: (1) no scheduled caller for `PKG_TIMERS.fn_sweep_and_process_one_expired_timer` — invoke manually for now; (2) no stale-claim reclaim in `PKG_OUTBOX` — a mid-dispatch `Mnp.Worker` crash leaves a row stuck `CLAIMED` forever; (3) `fn_create_request` doesn't consult the Number/Routing Lookup registry (`PKG_NUMBER_REGISTRY`) for real MSISDN-to-donor-network *ownership* verification — the registry exists and is populated on every completed port, but wiring it in as an enforcement gate needs a policy decision and bootstrap-data strategy that hasn't been made (see `database/README.md`'s Number/Routing Lookup section); (4) a blocked fraud-velocity attempt (`PKG_FRAUD_PREVENTION`) isn't surfaced to Operations via the outbox, since `PKG_OUTBOX.pr_enqueue` requires an existing request row that a blocked attempt never creates.
