# MNP application — phased build plan

Tracks the six-service business spec (Number/Routing Lookup, Eligibility &
Validation, Port Request Orchestration, SLA/Timer, Fraud/Number-Snatching
Prevention, Notification/Event) through delivery phases. Core business logic
lives in PL/SQL; .NET is the thin communication layer. All regional/calendar
data uses Europe/Athens (Greece) time.

## Phase A — rule engine, SLA timers, porting-request lifecycle (DONE)

Committed: `a46b3d9`.

- Config-driven, data-driven PL/SQL rule engine (`pkg_workflow_engine`) —
  branches/conditions/actions as data, not hardcoded CASE statements.
  Structurally prevents the bug classes found in the reviewed legacy system
  (contradictory simultaneous branches, ineffective HALT, silent
  unknown-condition failures, global timer bypass, unguarded concurrent timer
  processing).
- `pkg_calendar`, `pkg_conditions`, `pkg_timers` — Greek-holiday-aware,
  DST-correct (Europe/Athens) calendar and SLA timer sweeping.
- `pkg_porting_requests` — `pr_raise_event` replaces the old direct
  status-update path; events flow through the rule engine.
- `Mnp.MockExternalApis` project for local donor-network simulation.
- Known, deliberate gap carried forward: nothing schedules
  `pkg_timers.fn_sweep_and_process_one_expired_timer` — no DBMS_SCHEDULER job
  or .NET caller exists yet. Documented in `database/README.md`.

## Phase B — outbox notification relay / Notification/Event service (#6) (IN PROGRESS — verification complete, docs + commit remaining)

Plan file: `.claude/plans/use-the-ddls-stored-agile-whistle.md` (approved).

Done and verified against the live Podman `mnp-oracle` container:
- Schema: `mnp_notification_types` registry, `mnp_outbox_config` singleton
  (`max_attempts`), `audience` column added to `mnp_outbox_events`.
- `pkg_outbox` (claim-with-SKIP-LOCKED / mark-published / mark-failed /
  enqueue-with-audience-lookup); unregistered event_type raises `-20015`.
- `pkg_workflow_engine`'s `SEND_NOTIFICATION` action now delegates to
  `pkg_outbox.pr_enqueue`.
- Seeds: 9 event_types classified to audiences (`004_seed_notification_types.sql`),
  reachability validation (`005_validate_notification_registrations.sql`).
- New `Mnp.Worker` background-relay project (Singleton DI), `OutboxRelayService`
  (dispatch-by-audience: DonorNetwork/RecipientNetwork → carrier client,
  Customer → customer client, Operations → `ILogger` only, no HTTP call).
- `CarrierNetworkNotificationClient`, `CustomerNotificationClient` +
  matching mock-API controllers.
- 6 passing unit tests in `OutboxRelayServiceTests` (first real tests in
  the project).
- **Verified end-to-end today (2026-10-08)**, three services running together
  (`Mnp.Api` + `Mnp.MockExternalApis` + `Mnp.Worker`):
  - Happy path dispatch and `PUBLISHED` status.
  - SKIP LOCKED double-claim prevention.
  - Crash resilience: a NULL-audience legacy row no longer crashes the whole
    worker host — fixed in `OutboxRepository.ClaimNextPendingEventAsync` by
    explicitly checking `IsDBNull` and routing any parse failure through
    `MarkFailedAsync` instead of throwing past the caller.
  - Failure/retry/dead-letter path: stopped `Mnp.MockExternalApis`, created
    request id=39 directly via PL/SQL, watched outbox row climb
    attempt_count 1→5 and flip to `DEAD_LETTER`; confirmed a subsequent
    `pr_claim_next_pending` call does **not** pick up the dead-lettered row;
    confirmed `Mnp.Worker` process survived the whole sequence without
    crashing. `Mnp.MockExternalApis` has been restarted after this test.

Remaining before Phase B is closed out (plan step 13):
- [ ] `database/README.md` — replace the old "nothing reads this table yet"
      language in the Notification/Event section with the real
      `PKG_OUTBOX` / `Mnp.Worker` mechanism; document the orphaned-claim-
      on-crash known limitation (claim and mark-published/failed are
      separate DB calls with an HTTP call in between — if `Mnp.Worker`
      crashes mid-dispatch, that row is stuck `CLAIMED` forever; explicitly
      deferred, not an oversight — same spirit as the existing "known
      simplifications" section).
- [ ] Root `README.md` — add `Mnp.Worker` to the architecture table/diagram;
      move the outbox relay from "not yet built" to "built" in the Status
      section.
- [ ] Commit all Phase B changes to git (currently uncommitted).

## Phase C — Eligibility & Validation service (NOT STARTED)

Not yet planned in detail. Scope per the original six-service spec: validate
a port request is eligible (subscriber identity, account status, number
format/ownership) before it enters the workflow engine. Likely touches
`pkg_porting_requests` validation entry points and the existing
`CarrierNetworkClient` donor-validation call path.

## Phase D — Number/Routing Lookup service (NOT STARTED)

Not yet planned in detail. Scope per spec: given an MSISDN, determine current
network/routing owner. Likely a new PL/SQL lookup package plus a read-only
API endpoint; may need its own reference data table (current number→network
mapping) distinct from the porting-request workflow tables.

## Phase E — Fraud / Number-Snatching Prevention (NOT STARTED)

Not yet planned in detail. Scope per spec: detect/block suspicious rapid or
contradictory port requests for the same MSISDN. Likely a PL/SQL guard
invoked at request-creation time (`fn_create_request`) or as a new condition
type in the rule engine.

## Deliberately deferred (documented, not forgotten)

- **Timer-sweep scheduling**: no DBMS_SCHEDULER job or .NET scheduled caller
  exists yet for `pkg_timers.fn_sweep_and_process_one_expired_timer`. Out of
  scope for Phase A and Phase B by explicit choice.
- **Outbox stale-claim reclaim**: no timeout-based reclaim for rows stuck
  `CLAIMED` after a worker crash mid-dispatch. User explicitly chose "keep it
  simple for now" when this was raised during Phase B planning — to be
  documented as a known limitation (see Phase B remaining work above), not
  fixed.
- **Notification fan-out**: each event_type maps to exactly one audience
  today; multi-party notification (e.g. both donor and customer on the same
  event) is explicit future work, not retrofitted in Phase B.
