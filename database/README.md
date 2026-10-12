# Database

This is where the actual MNP business logic lives — table definitions, packages,
and the migration scripts that create them. The .NET solution in `src/` is a thin
communication layer: it opens connections, calls package procedures/functions,
and maps rows to .NET types. It does not re-implement validation or state-machine
rules that belong here.

## Layout

- `schema/` — DDL for tables, indexes, constraints. Numbered and applied in order
  (`001_`, `002_`, ...). Never edit an already-applied script in place — add a new
  numbered script for changes.
- `packages/` — PL/SQL package specs (`.pks`) and bodies (`.pkb`).
- `seed/` — data, not schema: workflow rules, timer definitions, the holiday
  calendar. Also numbered; `003_validate_reachability.sql` is a verification
  query (expect zero rows), not a migration.

## Port Request Orchestration: a config-driven rule engine

State transitions are **not** a hardcoded `CASE` statement in PL/SQL. They're data
in `mnp_workflow_branches`/`mnp_workflow_actions`, interpreted by
`PKG_WORKFLOW_ENGINE`:

- For a request's current `status` and an incoming `event_type`, the engine walks
  active branches in `branch_sequence` order. The **first** branch whose
  `condition_name` evaluates true (or the trailing branch with `condition_name
  IS NULL`, the default) is the **only** one whose actions run. Two branches for
  the same (status, event) can never both fire — branches are mutually exclusive
  by construction, not by convention.
- Actions (`TRANSITION_TO`, `SEND_NOTIFICATION`, `START_TIMER`, `STOP_TIMER`,
  `RECORD_REJECTION_REASON`, `HALT`) run in `action_sequence` order within the
  matched branch. `HALT` stops the rest of that branch's actions.
- Every branch considered and every action dispatched is logged to
  `mnp_workflow_audit_log`, win or lose — the full decision trail for a request
  is just a `SELECT ... WHERE porting_request_id = ?`.
- An event with **no matching branch at all** (including no default) raises
  `ORA-20012` rather than silently doing nothing.
- An **unknown condition name** raises `ORA-20011` rather than being treated as
  false.

.NET only ever calls `PKG_PORTING_REQUESTS.PR_RAISE_EVENT` (and `PKG_TIMERS`'s
sweep entry point) — never `PKG_WORKFLOW_ENGINE`/`PKG_CONDITIONS`/`PKG_CALENDAR`
directly. There is deliberately no direct status setter (no `PR_UPDATE_STATUS`):
every status change goes through an event, so there's exactly one way a
request's status can change.

To add a new event/transition: insert rows into `mnp_workflow_branches` and
`mnp_workflow_actions` (see `seed/001_seed_workflow_rules.sql` for the pattern),
then re-run `seed/003_validate_reachability.sql` to confirm you haven't
stranded a status with no way out.

## Eligibility & Validation

`FN_CREATE_REQUEST` checks two things synchronously, before any row exists —
MSISDN format (`-20001`, a regex) and PAC (Porting Authorization Code) format
and expiry (`-20002`): the PAC code must match `^[A-Z0-9]{6,12}$` and be
within `PAC_VALIDITY`'s window of its `pac_issued_date`, computed via
`PKG_CALENDAR.fn_calc_timer_expiry` — the same duration-lookup mechanism
`PKG_TIMERS` uses, just read once at submission time rather than instantiated
as a swept `mnp_timer_instances` row. Both PAC fields are plain columns on
`mnp_porting_requests` (added ahead of time in `schema/004`); required-ness is
enforced in `FN_CREATE_REQUEST`, not a `NOT NULL` constraint, mirroring how
MSISDN format is enforced.

A request's `CREATED` branch now transitions it straight to `VALIDATING`
(`seed/006_seed_eligibility_workflow_rules.sql`) instead of leaving it on
`RECEIVED` — `VALIDATING` is the real pending-eligibility state while .NET's
donor-network subscriber-identity/account-status check
(`CarrierNetworkClient.ValidateSubscriberAsync`) is in flight, with the
`PORT_SLA` timer already running against it. `VALIDATION_PASSED`/
`VALIDATION_FAILED`/`CANCEL`/`TIMER_EXPIRED` branches that used to hang off
`RECEIVED` now hang off `VALIDATING` instead; the old `RECEIVED` ones are
deactivated (`active_flag = 'N'`), not deleted.

*Ownership* (does an MSISDN really belong to the stated donor network) has no
check of its own yet. The Number/Routing Lookup service (below) now tracks
current ownership, but `FN_CREATE_REQUEST` deliberately doesn't consult it —
see that section for why.

## Fraud / Number-Snatching Prevention

`PKG_FRAUD_PREVENTION.pr_check_velocity`, called from `FN_CREATE_REQUEST`
right after the MSISDN-format check, blocks (`-20005`) a new request if
`MNP_PORTING_REQUESTS` already has `max_requests_per_window`-or-more rows for
that MSISDN created within the last `velocity_window_days` calendar days
(`MNP_FRAUD_CONFIG`, a singleton config row — example values, confirm against
actual fraud policy, same caveat as PAC validity and every other invented
duration in this project). Requests of *any* status count toward the
threshold, not just open ones — the signal is repeated attempts, regardless
of outcome.

This is distinct from `UX_MPR_MSISDN_OPEN` (`schema/004`), which only
prevents two *concurrently open* requests for the same MSISDN. This guard
catches rapid *sequential* resubmission after a prior request already closed
(cancelled/rejected/completed) — the actual number-snatching pattern.

A blocked attempt is not currently surfaced to Operations via the outbox:
`PKG_OUTBOX.pr_enqueue` requires an existing `porting_request_id`, and a
blocked attempt never creates a row. Known limitation, not fixed here.

## Number/Routing Lookup

`mnp_number_ownership` is a registry of "who currently owns this MSISDN,"
populated only by ports completed *through this system* — there's no row
for an MSISDN until its first `CUTOVER_COMPLETE`, because a real answer for
a never-ported number would require the national numbering-plan
range-to-operator dataset, which this project declines to guess at (same
caution as the Greek holiday calendar and timer durations: confirm against
an authoritative source, don't invent one).

The engine's `CUTOVER`/`CUTOVER_COMPLETE` branch runs a new
`RECORD_NUMBER_OWNERSHIP` action (`PKG_NUMBER_REGISTRY.PR_RECORD_PORT_COMPLETED`)
alongside its existing `TRANSITION_TO COMPLETED`/`SEND_NOTIFICATION
PORT_COMPLETED` actions — a `MERGE` upsert, so a number ported more than once
over time gets one row that's kept current, not a growing history. Reads go
through `PKG_NUMBER_REGISTRY.PR_LOOKUP` (`SYS_REFCURSOR`, 0 or 1 rows — no
row is a valid "not tracked" answer, not an error) via `GET
/api/number-ownership/{msisdn}` (`404` for not-tracked, never a guessed
network code).

**Deliberately not wired up**: `FN_CREATE_REQUEST` does not consult this
registry to validate the donor network the client claims. Doing so would
require committing to an enforcement policy (what counts as a mismatch, and
whether "not tracked" means "allow") and a bootstrap-data strategy neither of
which has been specified — explicit follow-up work, not an assumption made
in Phase D.

## SLA/Timer

`mnp_timers` holds timer *types* (code, duration, unit — `WD`/`BH`/`CD`);
`mnp_timer_instances` holds one row per live/expired timer for a request.
`PKG_CALENDAR` computes expiry (working-day/business-hour/calendar-day
arithmetic against `mnp_calendar_holidays`/`mnp_business_hours`, interpreted in
`Europe/Athens` regardless of DB session/host time zone, DST-correct). No
duration is ever hardcoded in PL/SQL — only ever read from `mnp_timers`.

`PKG_TIMERS.fn_sweep_and_process_one_expired_timer` claims one expired timer
(`FOR UPDATE SKIP LOCKED`), raises `TIMER_EXPIRED` through the engine, and marks
it processed — all in one call/transaction, so there's no window for two
concurrent callers to double-process the same timer. Call it repeatedly until
it returns `NULL`. Nothing currently schedules this call automatically; a
scheduled .NET caller (or `DBMS_SCHEDULER` job) is a later phase.

## Notification/Event

`mnp_outbox_events` is a transactional outbox: the engine's `SEND_NOTIFICATION`
action calls `PKG_OUTBOX.PR_ENQUEUE`, which looks up the target `audience`
(`DONOR_NETWORK`/`RECIPIENT_NETWORK`/`CUSTOMER`/`OPERATIONS`) for the
notification's event type in `mnp_notification_types`, and inserts a row —
`msisdn`/`donor_network_code`/`recipient_network_code` baked into the payload
— in the same transaction as the status change it accompanies. An
unregistered event type raises `ORA-20015` rather than enqueueing a
null-audience row.

`Mnp.Worker` (a separate, always-running background process, not part of
`Mnp.Api`) polls `PKG_OUTBOX.PR_CLAIM_NEXT_PENDING` (`FOR UPDATE SKIP LOCKED`,
same no-double-claim guarantee as the timer sweep), dispatches by audience —
`DONOR_NETWORK`/`RECIPIENT_NETWORK` to the carrier-network notification
client, `CUSTOMER` to the customer notification client, `OPERATIONS` to a log
line, no HTTP call — and calls `PR_MARK_PUBLISHED`/`PR_MARK_FAILED`
accordingly. `PR_MARK_FAILED` increments `attempt_count` and flips the row to
`DEAD_LETTER` once `mnp_outbox_config.max_attempts` is reached; a
dead-lettered row is never claimed again.

**Known limitation, not an oversight**: claiming a row and later marking it
published/failed are two separate DB calls with an HTTP call in between. If
`Mnp.Worker` crashes mid-dispatch, that row is stuck `CLAIMED` forever —
it is never retried and the notification is silently lost. A timeout-based
reclaim was considered and deliberately deferred to keep `PKG_OUTBOX`'s
surface simple (enqueue / claim / mark-published / mark-failed only); revisit
if this proves to matter in practice.

## Conventions

- Tables: `mnp_<plural_noun>`, snake_case columns.
- Packages: `pkg_<aggregate>`. Public functions/procedures: `fn_`/`pr_` prefix.
- Status/enum-like columns are `VARCHAR2` with a `CHECK` constraint, not lookup
  tables — keeps the valid set visible in one place. The .NET side maps these to
  an enum (see `PortingStatusMapping` in `Mnp.Infrastructure.Database`).
- Errors raised as a dedicated exception number (`RAISE_APPLICATION_ERROR(-200xx, ...)`):
  `-20001` invalid MSISDN, `-20002` invalid/expired PAC code, `-20003` request
  not found, `-20004` duplicate open request for an MSISDN, `-20005`
  suspicious port velocity for an MSISDN, `-20010`
  unknown/inactive timer code, `-20011` unknown condition name, `-20012`
  unhandled event, `-20013` unknown action type, `-20014` no running timer to
  cancel.
- Reads that return more than one column go through a `SYS_REFCURSOR` OUT parameter
  so .NET can map a result set without needing an object type.
- Idempotency ("no duplicate/concurrent open request per MSISDN") is one
  mechanism, not two: a function-based unique index
  (`ux_mpr_msisdn_open`) that collapses terminal-status rows to `NULL`.

## Applying scripts

No migration tool is wired up yet (Flyway/Liquibase are natural fits once there's a
shared dev/test database). Order matters more now than it used to:
`PKG_TIMERS`, `PKG_WORKFLOW_ENGINE`, and `PKG_PORTING_REQUESTS` call each other
across packages, so **apply all package specs (`.pks`) before any package body
(`.pkb`)** — Oracle resolves mutual references fine as long as every spec
already exists when a body compiles.

```bash
# 1. schema, in order
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @schema/001_create_porting_requests_table.sql
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @schema/002_create_workflow_engine_tables.sql
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @schema/003_create_calendar_and_timers.sql
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @schema/004_extend_porting_requests.sql

# 2. all package specs, then all package bodies
for f in packages/*.pks; do sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 "@$f"; done
for f in packages/*.pkb; do sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 "@$f"; done

# 3. seed data, then the reachability check (expect: no rows selected)
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @seed/001_seed_workflow_rules.sql
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @seed/002_seed_timers_and_calendar.sql
sqlplus mnp_app/<password>@//localhost:1521/FREEPDB1 @seed/003_validate_reachability.sql
```

For local dev against the Podman/Docker Oracle container, see the root
[README's Local Oracle section](../README.md#local-oracle-dev) — it runs
`sqlplus` inside the container instead, since no local Oracle client is assumed.
