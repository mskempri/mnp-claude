-- ============================================================
-- Live export of the MNP_APP schema from the running Oracle
-- database, extracted via DBMS_METADATA directly from the data
-- dictionary - not reconstructed from the repo's own migration
-- scripts. Reflects exactly what currently exists in the DB.
--
-- Generated 2026-10-09 against the local Podman mnp-oracle
-- container (gvenzl/oracle-free:23-slim), via a PL/SQL block
-- calling DBMS_METADATA.GET_DDL for every TABLE, PACKAGE, and
-- PACKAGE BODY in the MNP_APP schema, plus GET_DDL('INDEX', ...)
-- for indexes not already implied by a table constraint, plus
-- COMMENT ON statements read from USER_TAB_COMMENTS/
-- USER_COL_COMMENTS. Identity-column sequences (ISEQ$$_*) are
-- intentionally omitted: they are embedded inline in each table's
-- GENERATED ALWAYS AS IDENTITY column clause below, not separate
-- objects to recreate. This is a point-in-time snapshot, not a
-- maintained artifact - re-run the export to refresh it.
-- ============================================================
--
-- TABLES
--

  CREATE TABLE "MNP_APP"."MNP_BUSINESS_HOURS" 
   (	"ID" NUMBER, 
	"START_TIME" VARCHAR2(5) NOT NULL ENABLE, 
	"END_TIME" VARCHAR2(5) NOT NULL ENABLE, 
	"TIME_ZONE" VARCHAR2(40) DEFAULT 'Europe/Athens' NOT NULL ENABLE, 
	 CHECK (id = 1) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_CALENDAR_HOLIDAYS" 
   (	"HOLIDAY_DATE" DATE, 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	 PRIMARY KEY ("HOLIDAY_DATE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_CONDITIONS" 
   (	"CONDITION_NAME" VARCHAR2(40), 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	"ACTIVE_FLAG" VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
	 CHECK (active_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("CONDITION_NAME")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_FRAUD_CONFIG" 
   (	"ID" NUMBER, 
	"VELOCITY_WINDOW_DAYS" NUMBER NOT NULL ENABLE, 
	"MAX_REQUESTS_PER_WINDOW" NUMBER NOT NULL ENABLE, 
	 CHECK (id = 1) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_NOTIFICATION_TYPES" 
   (	"EVENT_TYPE" VARCHAR2(40), 
	"AUDIENCE" VARCHAR2(20) NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	 CHECK (audience IN (
                     'DONOR_NETWORK', 'RECIPIENT_NETWORK', 'CUSTOMER', 'OPERATIONS'
                 )) ENABLE, 
	 PRIMARY KEY ("EVENT_TYPE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_NUMBER_OWNERSHIP" 
   (	"MSISDN" VARCHAR2(20), 
	"CURRENT_NETWORK_CODE" VARCHAR2(10) NOT NULL ENABLE, 
	"LAST_PORTED_AT" TIMESTAMP (6) WITH TIME ZONE NOT NULL ENABLE, 
	"LAST_PORTING_REQUEST_ID" NUMBER, 
	 PRIMARY KEY ("MSISDN")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("LAST_PORTING_REQUEST_ID")
	  REFERENCES "MNP_APP"."MNP_PORTING_REQUESTS" ("ID") ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_OUTBOX_CONFIG" 
   (	"ID" NUMBER, 
	"MAX_ATTEMPTS" NUMBER NOT NULL ENABLE, 
	 CHECK (id = 1) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_OUTBOX_EVENTS" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"AGGREGATE_TYPE" VARCHAR2(40) DEFAULT 'PORTING_REQUEST' NOT NULL ENABLE, 
	"AGGREGATE_ID" NUMBER NOT NULL ENABLE, 
	"EVENT_TYPE" VARCHAR2(40) NOT NULL ENABLE, 
	"PAYLOAD" VARCHAR2(4000), 
	"STATUS" VARCHAR2(20) DEFAULT 'PENDING' NOT NULL ENABLE, 
	"ATTEMPT_COUNT" NUMBER DEFAULT 0 NOT NULL ENABLE, 
	"LAST_ERROR" VARCHAR2(4000), 
	"CREATED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	"CLAIMED_AT" TIMESTAMP (6) WITH TIME ZONE, 
	"PUBLISHED_AT" TIMESTAMP (6) WITH TIME ZONE, 
	"AUDIENCE" VARCHAR2(20), 
	 CHECK (status IN (
                            'PENDING', 'CLAIMED', 'PUBLISHED', 'FAILED', 'DEAD_LETTER'
                        )) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 CHECK (audience IN (
        'DONOR_NETWORK', 'RECIPIENT_NETWORK', 'CUSTOMER', 'OPERATIONS'
    )) ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_PORTING_REQUESTS" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"MSISDN" VARCHAR2(20) NOT NULL ENABLE, 
	"DONOR_NETWORK_CODE" VARCHAR2(10) NOT NULL ENABLE, 
	"RECIPIENT_NETWORK_CODE" VARCHAR2(10) NOT NULL ENABLE, 
	"STATUS" VARCHAR2(20) NOT NULL ENABLE, 
	"REQUESTED_PORTING_DATE" DATE NOT NULL ENABLE, 
	"REJECTION_REASON" VARCHAR2(500), 
	"CREATED_AT" TIMESTAMP (6) WITH TIME ZONE NOT NULL ENABLE, 
	"UPDATED_AT" TIMESTAMP (6) WITH TIME ZONE NOT NULL ENABLE, 
	"PAC_CODE" VARCHAR2(20), 
	"PAC_ISSUED_DATE" DATE, 
	 CONSTRAINT "CK_MPR_NETWORKS_DIFFER" CHECK (donor_network_code <> recipient_network_code) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "CK_MPR_STATUS" CHECK (status IN (
    'RECEIVED', 'VALIDATING', 'APPROVED', 'REJECTED',
    'SCHEDULED', 'CUTOVER', 'COMPLETED', 'CANCELLED'
)) ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_TIMERS" 
   (	"TIMER_CODE" VARCHAR2(40), 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	"DURATION_UNITS" NUMBER NOT NULL ENABLE, 
	"UNIT_OF_MEASURE" VARCHAR2(2) NOT NULL ENABLE, 
	"ACTIVE_FLAG" VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
	 CHECK (unit_of_measure IN ('WD', 'BH', 'CD')) ENABLE, 
	 CHECK (active_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("TIMER_CODE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_TIMER_INSTANCES" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"PORTING_REQUEST_ID" NUMBER NOT NULL ENABLE, 
	"TIMER_CODE" VARCHAR2(40) NOT NULL ENABLE, 
	"STATUS" VARCHAR2(20) DEFAULT 'RUNNING' NOT NULL ENABLE, 
	"STARTED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	"EXPIRES_AT" TIMESTAMP (6) WITH TIME ZONE NOT NULL ENABLE, 
	"PROCESSED_AT" TIMESTAMP (6) WITH TIME ZONE, 
	 CHECK (status IN (
                            'RUNNING', 'EXPIRED', 'CANCELLED'
                        )) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("PORTING_REQUEST_ID")
	  REFERENCES "MNP_APP"."MNP_PORTING_REQUESTS" ("ID") ENABLE, 
	 FOREIGN KEY ("TIMER_CODE")
	  REFERENCES "MNP_APP"."MNP_TIMERS" ("TIMER_CODE") ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_WORKFLOW_ACTIONS" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"BRANCH_ID" NUMBER NOT NULL ENABLE, 
	"ACTION_SEQUENCE" NUMBER NOT NULL ENABLE, 
	"ACTION_TYPE" VARCHAR2(40) NOT NULL ENABLE, 
	"ACTION_PARAMETER" VARCHAR2(200), 
	"ACTIVE_FLAG" VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
	 CHECK (active_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "UQ_MWA_SEQUENCE" UNIQUE ("BRANCH_ID", "ACTION_SEQUENCE")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("BRANCH_ID")
	  REFERENCES "MNP_APP"."MNP_WORKFLOW_BRANCHES" ("ID") ENABLE, 
	 FOREIGN KEY ("ACTION_TYPE")
	  REFERENCES "MNP_APP"."MNP_WORKFLOW_ACTION_TYPES" ("ACTION_TYPE") ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_WORKFLOW_ACTION_TYPES" 
   (	"ACTION_TYPE" VARCHAR2(40), 
	"DESCRIPTION" VARCHAR2(200) NOT NULL ENABLE, 
	"ACTIVE_FLAG" VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
	 CHECK (active_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("ACTION_TYPE")
  USING INDEX  ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_WORKFLOW_AUDIT_LOG" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"PORTING_REQUEST_ID" NUMBER NOT NULL ENABLE, 
	"EVENT_TYPE" VARCHAR2(40) NOT NULL ENABLE, 
	"FROM_STATUS" VARCHAR2(20) NOT NULL ENABLE, 
	"CONTEXT_VALUE" VARCHAR2(200), 
	"BRANCH_ID" NUMBER, 
	"CONDITION_NAME" VARCHAR2(40), 
	"CONDITION_RESULT" VARCHAR2(1), 
	"ACTION_ID" NUMBER, 
	"ACTION_TYPE" VARCHAR2(40), 
	"ACTION_PARAMETER" VARCHAR2(200), 
	"HALTED_FLAG" VARCHAR2(1) DEFAULT 'N' NOT NULL ENABLE, 
	"TO_STATUS" VARCHAR2(20), 
	"OCCURRED_AT" TIMESTAMP (6) WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL ENABLE, 
	 CHECK (condition_result IN ('Y', 'N')) ENABLE, 
	 CHECK (halted_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("PORTING_REQUEST_ID")
	  REFERENCES "MNP_APP"."MNP_PORTING_REQUESTS" ("ID") ENABLE, 
	 FOREIGN KEY ("BRANCH_ID")
	  REFERENCES "MNP_APP"."MNP_WORKFLOW_BRANCHES" ("ID") ENABLE, 
	 FOREIGN KEY ("ACTION_ID")
	  REFERENCES "MNP_APP"."MNP_WORKFLOW_ACTIONS" ("ID") ENABLE
   ) ;

  CREATE TABLE "MNP_APP"."MNP_WORKFLOW_BRANCHES" 
   (	"ID" NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	"STATUS" VARCHAR2(20) NOT NULL ENABLE, 
	"EVENT_TYPE" VARCHAR2(40) NOT NULL ENABLE, 
	"BRANCH_SEQUENCE" NUMBER NOT NULL ENABLE, 
	"CONDITION_NAME" VARCHAR2(40), 
	"ACTIVE_FLAG" VARCHAR2(1) DEFAULT 'Y' NOT NULL ENABLE, 
	"DESCRIPTION" VARCHAR2(200), 
	 CHECK (status IN (
                          'RECEIVED', 'VALIDATING', 'APPROVED', 'REJECTED',
                          'SCHEDULED', 'CUTOVER', 'COMPLETED', 'CANCELLED'
                      )) ENABLE, 
	 CHECK (active_flag IN ('Y', 'N')) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX  ENABLE, 
	 CONSTRAINT "UQ_MWB_SEQUENCE" UNIQUE ("STATUS", "EVENT_TYPE", "BRANCH_SEQUENCE")
  USING INDEX  ENABLE, 
	 FOREIGN KEY ("CONDITION_NAME")
	  REFERENCES "MNP_APP"."MNP_CONDITIONS" ("CONDITION_NAME") ENABLE
   ) ;
--
-- TABLE AND COLUMN COMMENTS
--
COMMENT ON TABLE MNP_FRAUD_CONFIG IS 'Singleton config for PKG_FRAUD_PREVENTION.pr_check_velocity: blocks a new port request if max_requests_per_window-or-more requests already exist for the same MSISDN within the last velocity_window_days calendar days.';
COMMENT ON TABLE MNP_NOTIFICATION_TYPES IS 'Registry of valid SEND_NOTIFICATION action_parameter values and who each is for. An unregistered event_type raises (PKG_OUTBOX.pr_enqueue), never silently enqueues with an unknown audience.';
COMMENT ON TABLE MNP_NUMBER_OWNERSHIP IS 'Current network owner per MSISDN, as last recorded by a completed port through this system. Populated by PKG_NUMBER_REGISTRY via the workflow engine''s RECORD_NUMBER_OWNERSHIP action on CUTOVER/CUTOVER_COMPLETE - not consulted by FN_CREATE_REQUEST (deliberately, see PHASES.md Phase D).';
COMMENT ON TABLE MNP_OUTBOX_EVENTS IS 'Transactional outbox. Populated by PKG_WORKFLOW_ENGINE; relayed by a .NET worker added in a later phase (not yet implemented).';
COMMENT ON TABLE MNP_PORTING_REQUESTS IS 'One row per number-porting request. Owned by PKG_PORTING_REQUESTS - do not write to it from application code directly.';
COMMENT ON TABLE MNP_WORKFLOW_BRANCHES IS 'Config-driven state machine: for (status, event_type), the first branch whose condition is true (or the trailing default) runs, and only that one.';
COMMENT ON COLUMN MNP_OUTBOX_EVENTS.AUDIENCE IS 'Nullable because rows enqueued before this column existed (Phase A dev data) predate it. Every row enqueued via PKG_OUTBOX.pr_enqueue going forward has this populated.';
COMMENT ON COLUMN MNP_TIMERS.UNIT_OF_MEASURE IS 'WD = working days, BH = business hours, CD = calendar days';
--
-- STANDALONE INDEXES (not already created by a table constraint)
--

  CREATE INDEX "MNP_APP"."IX_MOE_STATUS" ON "MNP_APP"."MNP_OUTBOX_EVENTS" ("STATUS", SYS_EXTRACT_UTC("CREATED_AT")) 
  ;

  CREATE INDEX "MNP_APP"."IX_MPR_MSISDN" ON "MNP_APP"."MNP_PORTING_REQUESTS" ("MSISDN") 
  ;

  CREATE UNIQUE INDEX "MNP_APP"."UX_MPR_MSISDN_OPEN" ON "MNP_APP"."MNP_PORTING_REQUESTS" (CASE  WHEN ("STATUS"<>'COMPLETED' AND "STATUS"<>'REJECTED' AND "STATUS"<>'CANCELLED') THEN "MSISDN" END ) 
  ;

  CREATE INDEX "MNP_APP"."IX_MTI_REQUEST" ON "MNP_APP"."MNP_TIMER_INSTANCES" ("PORTING_REQUEST_ID", "TIMER_CODE") 
  ;

  CREATE INDEX "MNP_APP"."IX_MTI_SWEEP" ON "MNP_APP"."MNP_TIMER_INSTANCES" ("STATUS", SYS_EXTRACT_UTC("EXPIRES_AT")) 
  ;

  CREATE INDEX "MNP_APP"."IX_MWAL_REQUEST" ON "MNP_APP"."MNP_WORKFLOW_AUDIT_LOG" ("PORTING_REQUEST_ID", SYS_EXTRACT_UTC("OCCURRED_AT")) 
  ;
--
-- PACKAGE SPECS
--

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_CALENDAR" AS
    -- Working-day / business-hour / calendar-day arithmetic for SLA timers.
    -- All arithmetic is performed in the business-hours configuration's
    -- time_zone (Europe/Athens for this deployment, see mnp_business_hours),
    -- not the DB session's or host's default zone, and is DST-correct: "N
    -- calendar days later" lands on the same local wall-clock time on that
    -- date even across a DST transition, not simply N*24 hours later.
    --
    -- Deliberately has no bypass/override switch of any kind. The legacy
    -- reference system had a global flag that could collapse every
    -- regulatory timer to ~1 minute; that capability does not exist here,
    -- in any form, reachable from any build.

    FUNCTION fn_add_working_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE;

    FUNCTION fn_add_business_hours(
        p_from  IN TIMESTAMP WITH TIME ZONE,
        p_hours IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE;

    FUNCTION fn_add_calendar_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE;

    FUNCTION fn_calc_timer_expiry(
        p_anchor     IN TIMESTAMP WITH TIME ZONE,
        p_timer_code IN VARCHAR2
    ) RETURN TIMESTAMP WITH TIME ZONE;

END pkg_calendar;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_CONDITIONS" AS
    -- Named condition dispatch for workflow branches. An unknown condition
    -- name RAISES rather than returning a sentinel a caller might mistake
    -- for "false" — the legacy reference system's evaluate() returned -1 for
    -- an unrecognised name, which its engine then treated identically to a
    -- false result, silently skipping the branch instead of surfacing a
    -- config error. That failure mode is not reproduced here.

    FUNCTION fn_evaluate(
        p_condition_name IN VARCHAR2,
        p_request_id     IN NUMBER,
        p_context        IN VARCHAR2,
        p_explanation    OUT VARCHAR2
    ) RETURN BOOLEAN;

END pkg_conditions;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_FRAUD_PREVENTION" AS
    -- Fraud/Number-Snatching Prevention service (#5 in the six-service
    -- spec): a velocity guard against rapid/repeated port-request attempts
    -- for the same MSISDN. Distinct from UX_MPR_MSISDN_OPEN (schema/004),
    -- which only prevents two *concurrently open* requests - this catches
    -- rapid sequential resubmission after a prior request already closed
    -- (cancelled/rejected/completed), the actual number-snatching pattern.

    e_suspicious_velocity EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_suspicious_velocity, -20005);

    -- Raises e_suspicious_velocity if MNP_PORTING_REQUESTS already has
    -- max_requests_per_window-or-more rows for p_msisdn created within the
    -- last velocity_window_days calendar days (MNP_FRAUD_CONFIG; example
    -- values - confirm against actual fraud policy), counting requests of
    -- ANY status - the signal is repeated attempts, not just open ones.
    -- Called by PKG_PORTING_REQUESTS.fn_create_request before the new row
    -- is inserted, so it evaluates prior history only.
    PROCEDURE pr_check_velocity(p_msisdn IN VARCHAR2);

END pkg_fraud_prevention;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_NUMBER_REGISTRY" AS
    -- Number/Routing Lookup service. Owns MNP_NUMBER_OWNERSHIP - a registry
    -- of "who currently owns this MSISDN", populated only from ports
    -- completed inside this system (see schema/006 for why it can't be
    -- more than that). Read-only from .NET's perspective; writes only ever
    -- happen via PR_RECORD_PORT_COMPLETED, called by PKG_WORKFLOW_ENGINE.

    PROCEDURE pr_record_port_completed(p_request_id IN NUMBER);

    -- Returns 0 or 1 rows: msisdn, current_network_code, last_ported_at,
    -- last_porting_request_id. No row is a valid "not tracked" answer, not
    -- an error - callers should not expect this to raise on a miss.
    PROCEDURE pr_lookup(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    );

END pkg_number_registry;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_OUTBOX" AS
    -- Transactional outbox for the Notification/Event service. PKG_WORKFLOW_ENGINE
    -- is the only caller of PR_ENQUEUE (from its SEND_NOTIFICATION action, inside
    -- the engine's existing row lock/transaction, so a notification is never
    -- recorded without the state change it accompanies actually committing).
    -- Mnp.Worker is the only caller of the claim/mark procedures.
    --
    -- Known limitation, deliberately not solved here: claiming a row and later
    -- marking it published/failed are two separate calls with an HTTP call in
    -- between. If the claiming process crashes mid-dispatch, that row is stuck
    -- CLAIMED forever - never retried, message silently lost. A timeout-based
    -- reclaim was considered and explicitly deferred to keep this surface
    -- simple; see database/README.md.

    e_unknown_event_type EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_unknown_event_type, -20015);

    -- Looks up the audience for p_notification_event_type in
    -- MNP_NOTIFICATION_TYPES (raises -20015 if unregistered - never enqueues
    -- with an unknown audience). Joins MNP_PORTING_REQUESTS for msisdn/
    -- donor_network_code/recipient_network_code and bakes them into the
    -- payload uniformly, regardless of audience, so Mnp.Worker never needs a
    -- second DB round-trip to dispatch.
    PROCEDURE pr_enqueue(
        p_request_id              IN NUMBER,
        p_notification_event_type IN VARCHAR2,
        p_source_event            IN VARCHAR2
    );

    -- Claims one PENDING row (FOR UPDATE SKIP LOCKED + ROWNUM = 1, no ORDER
    -- BY - FOR UPDATE doesn't support FETCH FIRST/an ORDER BY'd inline view,
    -- ORA-02014). p_cursor has 0 or 1 rows: id, event_type, audience, payload.
    PROCEDURE pr_claim_next_pending(p_cursor OUT SYS_REFCURSOR);

    PROCEDURE pr_mark_published(p_outbox_id IN NUMBER);

    -- Increments attempt_count and records p_error. Flips to DEAD_LETTER if
    -- attempt_count has now reached MNP_OUTBOX_CONFIG.max_attempts, else back
    -- to PENDING for the next poll cycle.
    PROCEDURE pr_mark_failed(
        p_outbox_id IN NUMBER,
        p_error     IN VARCHAR2
    );

END pkg_outbox;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_PORTING_REQUESTS" AS
    -- Owns the porting-request aggregate. .NET calls only this package -
    -- never the engine/conditions/calendar packages, and never the table
    -- directly. State transitions are no longer decided here: PR_RAISE_EVENT
    -- hands off to PKG_WORKFLOW_ENGINE, which alone decides the resulting
    -- status from data in MNP_WORKFLOW_BRANCHES/MNP_WORKFLOW_ACTIONS. There
    -- is deliberately no direct status setter any more (no PR_UPDATE_STATUS) -
    -- every status change must go through an event, so there is exactly one
    -- way a request's status can change, not two.

    e_invalid_msisdn           EXCEPTION;
    e_invalid_pac              EXCEPTION;
    e_duplicate_open_request   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_msisdn, -20001);
    PRAGMA EXCEPTION_INIT(e_invalid_pac, -20002);
    PRAGMA EXCEPTION_INIT(e_duplicate_open_request, -20004);

    FUNCTION fn_create_request(
        p_msisdn                 IN VARCHAR2,
        p_donor_network_code     IN VARCHAR2,
        p_recipient_network_code IN VARCHAR2,
        p_requested_porting_date IN DATE,
        p_pac_code               IN VARCHAR2,
        p_pac_issued_date        IN DATE
    ) RETURN NUMBER;

    PROCEDURE pr_get_request(
        p_id     IN  NUMBER,
        p_cursor OUT SYS_REFCURSOR
    );

    PROCEDURE pr_get_requests_by_msisdn(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    );

    -- Raises an event against the request's current status. Takes the row
    -- lock itself (FOR UPDATE) before delegating to the engine, so this is
    -- the single serialization point for concurrent events on one request.
    PROCEDURE pr_raise_event(
        p_id         IN NUMBER,
        p_event_type IN VARCHAR2,
        p_context    IN VARCHAR2 DEFAULT NULL
    );

END pkg_porting_requests;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_TIMERS" AS
    -- Timer lifecycle for the SLA/Timer service. Durations/units live in
    -- MNP_TIMERS (data); expiry is computed via PKG_CALENDAR at start time,
    -- so sweeping is a cheap "expires_at <= now" scan.

    PROCEDURE pr_start_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    );

    PROCEDURE pr_cancel_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    );

    -- Claims exactly one expired RUNNING timer (FOR UPDATE SKIP LOCKED, so
    -- concurrent callers never double-claim the same row), locks its owning
    -- request, raises TIMER_EXPIRED through the engine, and marks the timer
    -- EXPIRED - all in one transaction/one call, with no separate
    -- claim-then-process step. That single-transaction shape is deliberate:
    -- the legacy reference's timer worker had a visible claim/process split
    -- with no locking in between, which is exactly the shape that allows two
    -- concurrent workers to double-process the same expired timer. Here
    -- there is no window in which that race can occur.
    --
    -- Returns the timer_instance id it processed, or NULL if nothing was
    -- due. Callers (SQL*Plus for now; a scheduled .NET caller is a later
    -- phase) should call this repeatedly until it returns NULL.
    --
    -- Does not guarantee oldest-expired-timer-first ordering under
    -- concurrent callers (see implementation comment) - only that each call
    -- claims exactly one unlocked expired timer, never the same one twice.
    FUNCTION fn_sweep_and_process_one_expired_timer RETURN NUMBER;

END pkg_timers;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE "MNP_APP"."PKG_WORKFLOW_ENGINE" AS
    -- The generic rule engine: given a request's current status and an
    -- incoming event, walks MNP_WORKFLOW_BRANCHES for that (status, event)
    -- in branch_sequence order. The FIRST branch whose condition is true (or
    -- the trailing default branch, condition_name IS NULL) is the ONLY
    -- branch whose actions run - branches are mutually exclusive by
    -- construction, so two branches can never both fire for the same event
    -- the way independently-gated rows could in the legacy reference design.
    --
    -- Every branch considered (matched or not) and every action dispatched
    -- is logged to MNP_WORKFLOW_AUDIT_LOG, including HALTs.
    --
    -- If no branch matches at all - including when no default branch is
    -- defined for that (status, event) - this RAISES an "unhandled event"
    -- error rather than silently doing nothing.
    --
    -- Precondition: the caller is responsible for any row locking on
    -- MNP_PORTING_REQUESTS. This procedure assumes p_current_status is
    -- already a trustworthy, locked-or-just-inserted read and does not
    -- re-select or lock the row itself.

    PROCEDURE pr_process_event(
        p_request_id      IN NUMBER,
        p_current_status  IN VARCHAR2,
        p_event_type      IN VARCHAR2,
        p_context         IN VARCHAR2 DEFAULT NULL
    );

END pkg_workflow_engine;
/
--
-- PACKAGE BODIES
--

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_CALENDAR" AS

    FUNCTION fn_is_working_day(p_date IN DATE) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        IF TO_CHAR(p_date, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT', 'SUN') THEN
            RETURN FALSE;
        END IF;

        SELECT COUNT(*) INTO v_count
        FROM mnp_calendar_holidays
        WHERE holiday_date = TRUNC(p_date);

        RETURN v_count = 0;
    END fn_is_working_day;

    FUNCTION fn_add_working_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_tz        VARCHAR2(40);
        v_cursor    DATE;
        v_remaining NUMBER := p_days;
    BEGIN
        SELECT time_zone INTO v_tz FROM mnp_business_hours WHERE id = 1;
        v_cursor := CAST(p_from AT TIME ZONE v_tz AS DATE);

        WHILE v_remaining > 0 LOOP
            v_cursor := v_cursor + 1;
            IF fn_is_working_day(v_cursor) THEN
                v_remaining := v_remaining - 1;
            END IF;
        END LOOP;

        RETURN FROM_TZ(CAST(v_cursor AS TIMESTAMP), v_tz);
    END fn_add_working_days;

    FUNCTION fn_add_business_hours(
        p_from  IN TIMESTAMP WITH TIME ZONE,
        p_hours IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_tz               VARCHAR2(40);
        v_start_time       VARCHAR2(5);
        v_end_time         VARCHAR2(5);
        v_cursor           DATE;
        v_day_start        DATE;
        v_day_end          DATE;
        v_remaining_minutes NUMBER;
        v_available_minutes NUMBER;
    BEGIN
        SELECT time_zone, start_time, end_time
          INTO v_tz, v_start_time, v_end_time
          FROM mnp_business_hours WHERE id = 1;

        v_cursor := CAST(p_from AT TIME ZONE v_tz AS DATE);
        v_remaining_minutes := p_hours * 60;

        -- Normalise the starting point onto a working day, within the window.
        LOOP
            v_day_end := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_end_time || ':00');
            EXIT WHEN fn_is_working_day(TRUNC(v_cursor)) AND v_cursor < v_day_end;
            v_cursor := TRUNC(v_cursor) + 1;
        END LOOP;

        v_day_start := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_start_time || ':00');
        IF v_cursor < v_day_start THEN
            v_cursor := v_day_start;
        END IF;

        LOOP
            v_day_end := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_end_time || ':00');
            v_available_minutes := (v_day_end - v_cursor) * 1440;

            IF v_remaining_minutes <= v_available_minutes THEN
                v_cursor := v_cursor + (v_remaining_minutes / 1440);
                EXIT;
            END IF;

            v_remaining_minutes := v_remaining_minutes - v_available_minutes;
            v_cursor := TRUNC(v_cursor) + 1;
            WHILE NOT fn_is_working_day(TRUNC(v_cursor)) LOOP
                v_cursor := v_cursor + 1;
            END LOOP;
            v_cursor := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_start_time || ':00');
        END LOOP;

        RETURN FROM_TZ(CAST(v_cursor AS TIMESTAMP), v_tz);
    END fn_add_business_hours;

    FUNCTION fn_add_calendar_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_tz     VARCHAR2(40);
        v_cursor DATE;
    BEGIN
        SELECT time_zone INTO v_tz FROM mnp_business_hours WHERE id = 1;
        v_cursor := CAST(p_from AT TIME ZONE v_tz AS DATE) + p_days;
        RETURN FROM_TZ(CAST(v_cursor AS TIMESTAMP), v_tz);
    END fn_add_calendar_days;

    FUNCTION fn_calc_timer_expiry(
        p_anchor     IN TIMESTAMP WITH TIME ZONE,
        p_timer_code IN VARCHAR2
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_units NUMBER;
        v_uom   VARCHAR2(2);
    BEGIN
        SELECT duration_units, unit_of_measure
          INTO v_units, v_uom
          FROM mnp_timers
         WHERE timer_code = p_timer_code
           AND active_flag = 'Y';

        RETURN CASE v_uom
            WHEN 'WD' THEN fn_add_working_days(p_anchor, v_units)
            WHEN 'BH' THEN fn_add_business_hours(p_anchor, v_units)
            WHEN 'CD' THEN fn_add_calendar_days(p_anchor, v_units)
        END;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'Unknown or inactive timer code: ' || p_timer_code);
    END fn_calc_timer_expiry;

END pkg_calendar;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_CONDITIONS" AS

    FUNCTION fn_is_cutover_timer(p_context IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN p_context = 'CUTOVER_WINDOW';
    END fn_is_cutover_timer;

    FUNCTION fn_evaluate(
        p_condition_name IN VARCHAR2,
        p_request_id     IN NUMBER,
        p_context        IN VARCHAR2,
        p_explanation    OUT VARCHAR2
    ) RETURN BOOLEAN IS
        v_result BOOLEAN;
    BEGIN
        CASE UPPER(p_condition_name)
            WHEN 'IS_CUTOVER_TIMER' THEN
                v_result := fn_is_cutover_timer(p_context);
            ELSE
                RAISE_APPLICATION_ERROR(-20011, 'Unknown condition: ' || p_condition_name);
        END CASE;

        p_explanation := p_condition_name || ' = ' ||
            CASE WHEN v_result THEN 'TRUE' ELSE 'FALSE' END ||
            ' (request_id=' || p_request_id || ', context=' || NVL(p_context, '<null>') || ')';

        RETURN v_result;
    END fn_evaluate;

END pkg_conditions;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_FRAUD_PREVENTION" AS

    PROCEDURE pr_check_velocity(p_msisdn IN VARCHAR2) IS
        v_window_days  mnp_fraud_config.velocity_window_days%TYPE;
        v_max_requests mnp_fraud_config.max_requests_per_window%TYPE;
        v_window_start TIMESTAMP WITH TIME ZONE;
        v_count        NUMBER;
    BEGIN
        SELECT velocity_window_days, max_requests_per_window
          INTO v_window_days, v_max_requests
          FROM mnp_fraud_config
         WHERE id = 1;

        -- Plain date arithmetic, so a negative day count correctly walks
        -- backward - reuses the project's one sanctioned Europe/Athens
        -- arithmetic path instead of a raw SYSTIMESTAMP expression.
        v_window_start := pkg_calendar.fn_add_calendar_days(SYSTIMESTAMP, -v_window_days);

        SELECT COUNT(*) INTO v_count
          FROM mnp_porting_requests
         WHERE msisdn = p_msisdn
           AND created_at >= v_window_start;

        IF v_count >= v_max_requests THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Suspicious port velocity for MSISDN ' || p_msisdn || ': ' ||
                v_count || ' request(s) within the last ' || v_window_days ||
                ' day(s) (limit ' || v_max_requests || ').');
        END IF;
    END pr_check_velocity;

END pkg_fraud_prevention;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_NUMBER_REGISTRY" AS

    PROCEDURE pr_record_port_completed(p_request_id IN NUMBER) IS
        v_msisdn              mnp_porting_requests.msisdn%TYPE;
        v_recipient_network   mnp_porting_requests.recipient_network_code%TYPE;
    BEGIN
        SELECT msisdn, recipient_network_code
          INTO v_msisdn, v_recipient_network
          FROM mnp_porting_requests
         WHERE id = p_request_id;

        MERGE INTO mnp_number_ownership tgt
        USING (SELECT v_msisdn AS msisdn FROM dual) src
           ON (tgt.msisdn = src.msisdn)
        WHEN MATCHED THEN
            UPDATE SET current_network_code = v_recipient_network,
                       last_ported_at = SYSTIMESTAMP,
                       last_porting_request_id = p_request_id
        WHEN NOT MATCHED THEN
            INSERT (msisdn, current_network_code, last_ported_at, last_porting_request_id)
            VALUES (v_msisdn, v_recipient_network, SYSTIMESTAMP, p_request_id);
    END pr_record_port_completed;

    PROCEDURE pr_lookup(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT msisdn, current_network_code, last_ported_at, last_porting_request_id
              FROM mnp_number_ownership
             WHERE msisdn = p_msisdn;
    END pr_lookup;

END pkg_number_registry;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_OUTBOX" AS

    PROCEDURE pr_enqueue(
        p_request_id              IN NUMBER,
        p_notification_event_type IN VARCHAR2,
        p_source_event            IN VARCHAR2
    ) IS
        v_audience  mnp_notification_types.audience%TYPE;
        v_msisdn    mnp_porting_requests.msisdn%TYPE;
        v_donor     mnp_porting_requests.donor_network_code%TYPE;
        v_recipient mnp_porting_requests.recipient_network_code%TYPE;
        v_payload   VARCHAR2(4000);
    BEGIN
        BEGIN
            SELECT audience INTO v_audience
              FROM mnp_notification_types
             WHERE event_type = p_notification_event_type;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20015,
                    'Unregistered notification event type: ' || p_notification_event_type);
        END;

        SELECT msisdn, donor_network_code, recipient_network_code
          INTO v_msisdn, v_donor, v_recipient
          FROM mnp_porting_requests
         WHERE id = p_request_id;

        v_payload := JSON_OBJECT(
            'requestId' VALUE p_request_id,
            'sourceEvent' VALUE p_source_event,
            'msisdn' VALUE v_msisdn,
            'donorNetworkCode' VALUE v_donor,
            'recipientNetworkCode' VALUE v_recipient
        );

        INSERT INTO mnp_outbox_events (aggregate_id, event_type, payload, audience)
        VALUES (p_request_id, p_notification_event_type, v_payload, v_audience);
    END pr_enqueue;

    PROCEDURE pr_claim_next_pending(p_cursor OUT SYS_REFCURSOR) IS
        v_id mnp_outbox_events.id%TYPE;
    BEGIN
        SELECT id INTO v_id
          FROM mnp_outbox_events
         WHERE status = 'PENDING'
           AND ROWNUM = 1
           FOR UPDATE SKIP LOCKED;

        UPDATE mnp_outbox_events
           SET status = 'CLAIMED', claimed_at = SYSTIMESTAMP
         WHERE id = v_id;

        OPEN p_cursor FOR
            SELECT id, event_type, audience, payload
              FROM mnp_outbox_events
             WHERE id = v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            OPEN p_cursor FOR
                SELECT id, event_type, audience, payload
                  FROM mnp_outbox_events
                 WHERE 1 = 0;
    END pr_claim_next_pending;

    PROCEDURE pr_mark_published(p_outbox_id IN NUMBER) IS
    BEGIN
        UPDATE mnp_outbox_events
           SET status = 'PUBLISHED', published_at = SYSTIMESTAMP
         WHERE id = p_outbox_id
           AND status = 'CLAIMED';
    END pr_mark_published;

    PROCEDURE pr_mark_failed(
        p_outbox_id IN NUMBER,
        p_error     IN VARCHAR2
    ) IS
        v_attempt_count mnp_outbox_events.attempt_count%TYPE;
        v_max_attempts  mnp_outbox_config.max_attempts%TYPE;
    BEGIN
        UPDATE mnp_outbox_events
           SET attempt_count = attempt_count + 1,
               last_error = p_error
         WHERE id = p_outbox_id
           AND status = 'CLAIMED';

        IF SQL%ROWCOUNT = 0 THEN
            RETURN; -- row wasn't CLAIMED (already moved on); nothing to do
        END IF;

        SELECT attempt_count INTO v_attempt_count FROM mnp_outbox_events WHERE id = p_outbox_id;
        SELECT max_attempts INTO v_max_attempts FROM mnp_outbox_config WHERE id = 1;

        UPDATE mnp_outbox_events
           SET status = CASE WHEN v_attempt_count >= v_max_attempts THEN 'DEAD_LETTER' ELSE 'PENDING' END
         WHERE id = p_outbox_id;
    END pr_mark_failed;

END pkg_outbox;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_PORTING_REQUESTS" AS

    FUNCTION fn_create_request(
        p_msisdn                 IN VARCHAR2,
        p_donor_network_code     IN VARCHAR2,
        p_recipient_network_code IN VARCHAR2,
        p_requested_porting_date IN DATE,
        p_pac_code               IN VARCHAR2,
        p_pac_issued_date        IN DATE
    ) RETURN NUMBER IS
        v_id         mnp_porting_requests.id%TYPE;
        v_pac_expiry TIMESTAMP WITH TIME ZONE;
    BEGIN
        IF NOT REGEXP_LIKE(p_msisdn, '^\+?[0-9]{8,15}$') THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid MSISDN format: ' || p_msisdn);
        END IF;

        pkg_fraud_prevention.pr_check_velocity(p_msisdn);

        IF p_pac_code IS NULL OR NOT REGEXP_LIKE(p_pac_code, '^[A-Z0-9]{6,12}$') THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid PAC code: ' || NVL(p_pac_code, '<null>'));
        END IF;

        IF p_pac_issued_date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'PAC issued date is required.');
        END IF;

        -- PAC_VALIDITY is a pure duration lookup via PKG_CALENDAR (example
        -- value - confirm against jurisdiction, see seed/006), not a timer
        -- instance: this is a synchronous check at submission time, never
        -- swept.
        v_pac_expiry := pkg_calendar.fn_calc_timer_expiry(
            FROM_TZ(CAST(p_pac_issued_date AS TIMESTAMP), 'Europe/Athens'), 'PAC_VALIDITY');
        IF SYSTIMESTAMP > v_pac_expiry THEN
            RAISE_APPLICATION_ERROR(-20002, 'PAC code expired on ' || TO_CHAR(v_pac_expiry, 'YYYY-MM-DD'));
        END IF;

        INSERT INTO mnp_porting_requests (
            msisdn, donor_network_code, recipient_network_code,
            status, requested_porting_date, pac_code, pac_issued_date,
            created_at, updated_at
        ) VALUES (
            p_msisdn, p_donor_network_code, p_recipient_network_code,
            'RECEIVED', p_requested_porting_date, p_pac_code, p_pac_issued_date,
            SYSTIMESTAMP, SYSTIMESTAMP
        )
        RETURNING id INTO v_id;

        -- Row was just inserted in this transaction, so no separate lock is
        -- needed before handing off to the engine.
        pkg_workflow_engine.pr_process_event(v_id, 'RECEIVED', 'CREATED');

        RETURN v_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20004,
                'An open porting request already exists for MSISDN ' || p_msisdn || '.');
    END fn_create_request;

    PROCEDURE pr_get_request(
        p_id     IN  NUMBER,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT id, msisdn, donor_network_code, recipient_network_code,
                   status, requested_porting_date, rejection_reason,
                   pac_code, pac_issued_date,
                   created_at, updated_at
            FROM mnp_porting_requests
            WHERE id = p_id;
    END pr_get_request;

    PROCEDURE pr_get_requests_by_msisdn(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT id, msisdn, donor_network_code, recipient_network_code,
                   status, requested_porting_date, rejection_reason,
                   pac_code, pac_issued_date,
                   created_at, updated_at
            FROM mnp_porting_requests
            WHERE msisdn = p_msisdn
            ORDER BY created_at DESC;
    END pr_get_requests_by_msisdn;

    PROCEDURE pr_raise_event(
        p_id         IN NUMBER,
        p_event_type IN VARCHAR2,
        p_context    IN VARCHAR2 DEFAULT NULL
    ) IS
        v_status mnp_porting_requests.status%TYPE;
    BEGIN
        SELECT status INTO v_status
          FROM mnp_porting_requests
         WHERE id = p_id
           FOR UPDATE;

        pkg_workflow_engine.pr_process_event(p_id, v_status, p_event_type, p_context);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Porting request not found: ' || p_id);
    END pr_raise_event;

END pkg_porting_requests;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_TIMERS" AS

    PROCEDURE pr_start_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    ) IS
        v_expires_at TIMESTAMP WITH TIME ZONE;
    BEGIN
        v_expires_at := pkg_calendar.fn_calc_timer_expiry(SYSTIMESTAMP, p_timer_code);

        INSERT INTO mnp_timer_instances (porting_request_id, timer_code, expires_at)
        VALUES (p_request_id, p_timer_code, v_expires_at);
    END pr_start_timer;

    PROCEDURE pr_cancel_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    ) IS
    BEGIN
        UPDATE mnp_timer_instances
           SET status = 'CANCELLED', processed_at = SYSTIMESTAMP
         WHERE porting_request_id = p_request_id
           AND timer_code = p_timer_code
           AND status = 'RUNNING';

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20014,
                'No RUNNING timer ' || p_timer_code || ' found for request ' ||
                p_request_id || ' to cancel.');
        END IF;
    END pr_cancel_timer;

    FUNCTION fn_sweep_and_process_one_expired_timer RETURN NUMBER IS
        v_timer_id        mnp_timer_instances.id%TYPE;
        v_request_id      mnp_porting_requests.id%TYPE;
        v_timer_code      mnp_timer_instances.timer_code%TYPE;
        v_current_status  mnp_porting_requests.status%TYPE;
    BEGIN
        -- FOR UPDATE does not support selecting through a view containing
        -- ORDER BY/DISTINCT/GROUP BY (ORA-02014), which rules out both
        -- FETCH FIRST...ROWS ONLY and an ORDER BY'd inline subquery here.
        -- ROWNUM = 1 directly against the base table (no ordering) is the
        -- idiom that remains compatible with FOR UPDATE SKIP LOCKED - the
        -- trade-off is that this does not guarantee strict oldest-expired-
        -- first processing under concurrent sweepers, only that each call
        -- claims exactly one unlocked expired timer. Acceptable for Phase A;
        -- revisit if strict FIFO ordering becomes a real requirement.
        SELECT id, porting_request_id, timer_code
          INTO v_timer_id, v_request_id, v_timer_code
          FROM mnp_timer_instances
         WHERE status = 'RUNNING'
           AND expires_at <= SYSTIMESTAMP
           AND ROWNUM = 1
           FOR UPDATE SKIP LOCKED;

        SELECT status INTO v_current_status
          FROM mnp_porting_requests
         WHERE id = v_request_id
           FOR UPDATE;

        pkg_workflow_engine.pr_process_event(
            v_request_id, v_current_status, 'TIMER_EXPIRED', v_timer_code
        );

        UPDATE mnp_timer_instances
           SET status = 'EXPIRED', processed_at = SYSTIMESTAMP
         WHERE id = v_timer_id;

        RETURN v_timer_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END fn_sweep_and_process_one_expired_timer;

END pkg_timers;
/

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "MNP_APP"."PKG_WORKFLOW_ENGINE" AS

    PROCEDURE pr_run_branch_actions(
        p_request_id  IN NUMBER,
        p_event_type  IN VARCHAR2,
        p_from_status IN VARCHAR2,
        p_context     IN VARCHAR2,
        p_branch_id   IN NUMBER
    ) IS
        v_halted BOOLEAN := FALSE;
    BEGIN
        FOR act IN (
            SELECT id, action_type, action_parameter
              FROM mnp_workflow_actions
             WHERE branch_id = p_branch_id
               AND active_flag = 'Y'
             ORDER BY action_sequence
        ) LOOP
            DECLARE
                v_to_status mnp_porting_requests.status%TYPE := NULL;
            BEGIN
                CASE act.action_type
                    WHEN 'TRANSITION_TO' THEN
                        UPDATE mnp_porting_requests
                           SET status = act.action_parameter, updated_at = SYSTIMESTAMP
                         WHERE id = p_request_id;
                        v_to_status := act.action_parameter;

                    WHEN 'SEND_NOTIFICATION' THEN
                        pkg_outbox.pr_enqueue(p_request_id, act.action_parameter, p_event_type);

                    WHEN 'START_TIMER' THEN
                        pkg_timers.pr_start_timer(p_request_id, act.action_parameter);

                    WHEN 'STOP_TIMER' THEN
                        pkg_timers.pr_cancel_timer(p_request_id, act.action_parameter);

                    WHEN 'RECORD_REJECTION_REASON' THEN
                        UPDATE mnp_porting_requests
                           SET rejection_reason = p_context
                         WHERE id = p_request_id;

                    WHEN 'RECORD_NUMBER_OWNERSHIP' THEN
                        pkg_number_registry.pr_record_port_completed(p_request_id);

                    WHEN 'HALT' THEN
                        v_halted := TRUE;

                    ELSE
                        RAISE_APPLICATION_ERROR(-20013, 'Unknown action type: ' || act.action_type);
                END CASE;

                INSERT INTO mnp_workflow_audit_log (
                    porting_request_id, event_type, from_status, context_value,
                    branch_id, action_id, action_type, action_parameter, halted_flag, to_status
                ) VALUES (
                    p_request_id, p_event_type, p_from_status, p_context,
                    p_branch_id, act.id, act.action_type, act.action_parameter,
                    CASE WHEN v_halted THEN 'Y' ELSE 'N' END, v_to_status
                );
            END;

            EXIT WHEN v_halted;
        END LOOP;
    END pr_run_branch_actions;

    PROCEDURE pr_process_event(
        p_request_id      IN NUMBER,
        p_current_status  IN VARCHAR2,
        p_event_type      IN VARCHAR2,
        p_context         IN VARCHAR2 DEFAULT NULL
    ) IS
        v_matched     BOOLEAN := FALSE;
        v_cond_result BOOLEAN;
        v_explanation VARCHAR2(400);
    BEGIN
        FOR br IN (
            SELECT id, condition_name
              FROM mnp_workflow_branches
             WHERE status = p_current_status
               AND event_type = p_event_type
               AND active_flag = 'Y'
             ORDER BY branch_sequence
        ) LOOP
            IF br.condition_name IS NOT NULL THEN
                v_cond_result := pkg_conditions.fn_evaluate(
                    br.condition_name, p_request_id, p_context, v_explanation
                );

                INSERT INTO mnp_workflow_audit_log (
                    porting_request_id, event_type, from_status, context_value,
                    branch_id, condition_name, condition_result
                ) VALUES (
                    p_request_id, p_event_type, p_current_status, p_context,
                    br.id, br.condition_name, CASE WHEN v_cond_result THEN 'Y' ELSE 'N' END
                );

                IF NOT v_cond_result THEN
                    CONTINUE;
                END IF;
            ELSE
                INSERT INTO mnp_workflow_audit_log (
                    porting_request_id, event_type, from_status, context_value, branch_id
                ) VALUES (
                    p_request_id, p_event_type, p_current_status, p_context, br.id
                );
            END IF;

            v_matched := TRUE;
            pr_run_branch_actions(p_request_id, p_event_type, p_current_status, p_context, br.id);
            EXIT;
        END LOOP;

        IF NOT v_matched THEN
            RAISE_APPLICATION_ERROR(-20012,
                'Unhandled event ' || p_event_type || ' for status ' || p_current_status ||
                ' (request ' || p_request_id || '): no matching branch and no default branch defined.');
        END IF;
    END pr_process_event;

END pkg_workflow_engine;
/
