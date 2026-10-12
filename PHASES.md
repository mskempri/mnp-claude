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

## Phase B — outbox notification relay / Notification/Event service (#6) (DONE)

Committed: `d53cb1d`.

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

All plan steps complete, including step 13 (docs):
- [x] `database/README.md` — Notification/Event section rewritten with the
      real `PKG_OUTBOX` / `Mnp.Worker` mechanism, plus the orphaned-claim-
      on-crash known limitation.
- [x] Root `README.md` — `Mnp.Worker` added to the architecture table/
      diagram; Status section moved the outbox relay from "not yet built" to
      "built".
- [x] Committed all Phase B changes to git (`d53cb1d`).

## Phase C — Eligibility & Validation service (DONE)

Plan file: `.claude/plans/use-the-ddls-stored-agile-whistle.md` (approved).

Scope per the original six-service spec — "validate a port request is
eligible (subscriber identity, account status, number format/ownership)
before it enters the workflow engine" — grounded in breadcrumbs Phases A/B
left deliberately: `pac_code`/`pac_issued_date` columns added-but-unread in
`schema/004`, `VALIDATING` legal-but-unreachable in the status CHECK
constraint, and `-20002` conspicuously unused in the error-code sequence.

Done and verified against the live Podman `mnp-oracle` container:
- `pkg_porting_requests.fn_create_request` gained PAC validation: format
  (`^[A-Z0-9]{6,12}$`) and expiry (via `pkg_calendar.fn_calc_timer_expiry`
  against a new `PAC_VALIDITY` duration row in `mnp_timers`, same mechanism
  `pkg_timers` uses, read synchronously — no new timer instance, no sweep).
  Both raise `-20002`.
- `seed/006_seed_eligibility_workflow_rules.sql` wires `VALIDATING` into the
  rule engine as the real pending-eligibility state: `CREATED` now
  transitions `RECEIVED` → `VALIDATING`; the old `RECEIVED`/
  `VALIDATION_PASSED`/`VALIDATION_FAILED` branches are deactivated
  (`active_flag = 'N'`) and replaced by equivalent branches rooted at
  `VALIDATING` (plus `CANCEL` and `TIMER_EXPIRED` branches there too).
- `seed/003_validate_reachability.sql` no longer carves `VALIDATING` out —
  it's checked like every other non-terminal status now.
- `PortingRequestService.SubmitAsync` reordered: create the request first
  (lands in `VALIDATING`, SLA timer already running), *then* call the donor
  network, then raise the resulting event — a crash mid-call now leaves a
  visible `VALIDATING` row instead of silently losing the submission (the
  prior ordering created nothing if the donor call threw).
- 3 new tests in `PortingRequestServiceTests` (first tests for this service),
  covering ordering and the request-survives-a-donor-call-exception case.
- **Verified end-to-end today (2026-10-09)**, three services running together:
  - Malformed PAC / expired PAC → `-20002`, no row inserted either way.
  - Valid PAC → row lands in `VALIDATING`, not `RECEIVED`.
  - `VALIDATING` → `APPROVED`/`REJECTED`/`CANCELLED` all confirmed, including
    `rejection_reason` recording.
  - The deactivated `RECEIVED`/`VALIDATION_PASSED` branch now correctly
    raises `-20012` (unhandled event) rather than silently transitioning.
  - SLA timer sweep (`pkg_timers.fn_sweep_and_process_one_expired_timer`)
    fires `SLA_AT_RISK` from `VALIDATING` without changing status, both via
    direct event-raise and via the real sweep against a backdated timer row.
  - Full HTTP round trip (`Mnp.Api` + `Mnp.MockExternalApis` + `Mnp.Worker`):
    valid submission → `201` with PAC fields round-tripped; malformed/expired
    PAC → `500` (the pre-existing, documented error→HTTP-status translation
    gap, unchanged, not this phase's job); donor-denial path → `201`
    `REJECTED` with reason; notification dispatch (`REQUEST_APPROVED` →
    `RECIPIENT_NETWORK`, `REQUEST_REJECTED`/`REQUEST_RECEIVED` → `CUSTOMER`)
    confirmed firing correctly from the `VALIDATING`-rooted branches.

Not addressed, by design: real MSISDN-to-donor-network *ownership*
verification. The donor HTTP call implicitly assumes whatever network code
the client sent is correct; genuinely verifying it depends on Phase D's
Number/Routing Lookup service and isn't faked here.

## Phase D — Number/Routing Lookup service (DONE)

Plan file: `.claude/plans/use-the-ddls-stored-agile-whistle.md` (approved).

Scope per the original six-service spec: "given an MSISDN, determine current
network/routing owner." Unlike Phase C, nothing was pre-planted for this
phase — it's a genuinely new capability. Scope decision confirmed with the
user before building: standalone read-only lookup only, **not** wired into
`fn_create_request` as an ownership gate — a real answer for a never-ported
MSISDN would need the national numbering-plan range-to-operator dataset,
which this project declines to invent (same caution as the Greek holiday
calendar/timer durations), so the registry only ever knows ownership for
numbers that have completed a port *inside this system*. Closing Phase C's
ownership-verification gap with a real enforcement policy is explicit,
deliberately-deferred follow-up work.

Done and verified against the live Podman `mnp-oracle` container:
- `schema/006_create_number_registry.sql` — `mnp_number_ownership` (msisdn PK,
  current_network_code, last_ported_at, last_porting_request_id). No row =
  not tracked, not "no owner."
- New `pkg_number_registry` package: `pr_record_port_completed` (`MERGE`
  upsert, called only by the engine), `pr_lookup` (`SYS_REFCURSOR`, 0 or 1
  rows, no raise on a miss).
- `pkg_workflow_engine.pkb` gained one new action type,
  `RECORD_NUMBER_OWNERSHIP`, dispatched alongside the existing ones.
- `seed/007_seed_number_registry_action.sql` appends it to the existing
  `CUTOVER`/`CUTOVER_COMPLETE` branch (action_sequence 3).
- New .NET vertical slice mirroring `PortingRequest`'s layering:
  `NumberOwnership` domain type, `INumberRegistryRepository`/
  `NumberRegistryRepository`, thin `NumberRegistryService`,
  `NumberRegistryController` (`GET /api/number-ownership/{msisdn}` → `200` or
  `404`).
- 2 new tests in `NumberRegistryServiceTests`.
- **Verified end-to-end today (2026-10-09)**:
  - Untracked MSISDN → no row via direct PL/SQL lookup, `404` via HTTP.
  - A request driven through the full lifecycle to `COMPLETED` (via direct
    PL/SQL, and separately via the live HTTP API) produces exactly one
    registry row with the correct `recipient_network_code` and
    `last_porting_request_id`.
  - Porting the same MSISDN a second time (swapped donor/recipient) updates
    that same row (`MERGE`, confirmed via `COUNT(*) = 1`) rather than
    creating a second one.
  - `GET /api/number-ownership/{msisdn}` correctly returns `200` with the
    live registry state once a port completes.

Not addressed, by design: `fn_create_request` still doesn't consult this
registry. See `database/README.md`'s Number/Routing Lookup section for why.

## Phase E — Fraud / Number-Snatching Prevention (DONE)

Plan file: `.claude/plans/use-the-ddls-stored-agile-whistle.md` (approved).

Scope per the original six-service spec: "detect/block suspicious rapid or
contradictory port requests for the same MSISDN." The sixth and final
service from the spec — all six are now built (remaining gaps are documented
deferrals, see below, not missing services).

Done and verified against the live Podman `mnp-oracle` container:
- `schema/007_create_fraud_config.sql` — `mnp_fraud_config` singleton
  (`velocity_window_days`, `max_requests_per_window`; example/placeholder
  values, same caveat as PAC validity and every other invented duration).
- New `pkg_fraud_prevention` package: `pr_check_velocity` blocks (`-20005`) a
  new request if the MSISDN already has `max_requests_per_window`-or-more
  rows (any status) created within the last `velocity_window_days` calendar
  days, computed via `pkg_calendar.fn_add_calendar_days` with a negative day
  count (reuses the existing Europe/Athens-correct arithmetic path).
- `fn_create_request` gained one call to `pr_check_velocity`, right after the
  MSISDN-format check — no other PL/SQL or .NET changes needed.
- Distinct from `ux_mpr_msisdn_open` (prevents concurrently-*open* duplicates
  only): this catches rapid *sequential* resubmission after a prior request
  already closed.
- **Verified end-to-end today (2026-10-09)**: 3 requests for the same
  MSISDN (each immediately cancelled) succeed; a 4th within the window
  raises `-20005` with no row inserted; a different MSISDN is unaffected by
  the first one's history — confirmed both via direct PL/SQL and via the
  live HTTP API (3× `201`, 4th → `500`, consistent with the pre-existing
  error-translation gap). Full existing test suite (11/11) and build
  unaffected, confirming this phase stayed entirely in PL/SQL as planned.

Not addressed, by design: a blocked attempt doesn't raise an Operations
notification (`pkg_outbox.pr_enqueue` requires an existing request row, which
a blocked attempt never creates) and isn't audited to a log table (no
existing precedent for auditing pre-engine guard failures — MSISDN/PAC
failures aren't audited either).

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
