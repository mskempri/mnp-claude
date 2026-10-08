-- 002_create_workflow_engine_tables.sql
-- Generic, data-driven rule engine backing Port Request Orchestration.
-- Replaces the hardcoded is_transition_allowed/pr_update_status state machine
-- (see 001) with config: branches + actions drive status transitions and
-- side effects, instead of a CASE statement in code.

CREATE TABLE mnp_conditions (
    condition_name  VARCHAR2(40) PRIMARY KEY,
    description     VARCHAR2(200) NOT NULL,
    active_flag     VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (active_flag IN ('Y', 'N'))
);

CREATE TABLE mnp_workflow_action_types (
    action_type     VARCHAR2(40) PRIMARY KEY,
    description     VARCHAR2(200) NOT NULL,
    active_flag     VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (active_flag IN ('Y', 'N'))
);

-- Branches are evaluated in order for a given (status, event_type): the first
-- branch whose condition is true (or the trailing default branch, where
-- condition_name IS NULL) is the ONLY one whose actions run. Unlike a flat
-- table of independently-gated rows, two branches for the same (status,
-- event_type) can never both fire — eliminates the contradictory-simultaneous-
-- actions bug class by construction, not just by convention.
CREATE TABLE mnp_workflow_branches (
    id                NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status            VARCHAR2(20) NOT NULL CHECK (status IN (
                          'RECEIVED', 'VALIDATING', 'APPROVED', 'REJECTED',
                          'SCHEDULED', 'CUTOVER', 'COMPLETED', 'CANCELLED'
                      )),
    event_type        VARCHAR2(40) NOT NULL,
    branch_sequence   NUMBER NOT NULL,
    condition_name    VARCHAR2(40) REFERENCES mnp_conditions (condition_name),
    active_flag       VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (active_flag IN ('Y', 'N')),
    description       VARCHAR2(200),
    CONSTRAINT uq_mwb_sequence UNIQUE (status, event_type, branch_sequence)
);

CREATE TABLE mnp_workflow_actions (
    id                NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id         NUMBER NOT NULL REFERENCES mnp_workflow_branches (id),
    action_sequence   NUMBER NOT NULL,
    action_type       VARCHAR2(40) NOT NULL REFERENCES mnp_workflow_action_types (action_type),
    action_parameter  VARCHAR2(200),
    active_flag       VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (active_flag IN ('Y', 'N')),
    CONSTRAINT uq_mwa_sequence UNIQUE (branch_id, action_sequence)
);

-- One row per branch/condition/action evaluated by the engine, win or lose.
-- Makes every dispatch decision queryable after the fact.
CREATE TABLE mnp_workflow_audit_log (
    id                  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    porting_request_id  NUMBER NOT NULL REFERENCES mnp_porting_requests (id),
    event_type          VARCHAR2(40) NOT NULL,
    from_status         VARCHAR2(20) NOT NULL,
    context_value       VARCHAR2(200),
    branch_id           NUMBER REFERENCES mnp_workflow_branches (id),
    condition_name      VARCHAR2(40),
    condition_result    VARCHAR2(1) CHECK (condition_result IN ('Y', 'N')),
    action_id           NUMBER REFERENCES mnp_workflow_actions (id),
    action_type         VARCHAR2(40),
    action_parameter    VARCHAR2(200),
    halted_flag         VARCHAR2(1) DEFAULT 'N' NOT NULL CHECK (halted_flag IN ('Y', 'N')),
    to_status           VARCHAR2(20),
    occurred_at         TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX ix_mwal_request ON mnp_workflow_audit_log (porting_request_id, occurred_at);

-- Transactional outbox for the Notification/Event service. The engine's
-- SEND_NOTIFICATION action inserts here in the SAME transaction as the status
-- change it accompanies, so a notification is never recorded without the
-- state change actually having committed (or vice versa). A separate relay
-- worker (Phase B) claims PENDING rows and publishes them asynchronously;
-- nothing reads this table yet in this phase.
CREATE TABLE mnp_outbox_events (
    id                  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    aggregate_type      VARCHAR2(40) DEFAULT 'PORTING_REQUEST' NOT NULL,
    aggregate_id        NUMBER NOT NULL,
    event_type          VARCHAR2(40) NOT NULL,
    payload             VARCHAR2(4000),
    status              VARCHAR2(20) DEFAULT 'PENDING' NOT NULL CHECK (status IN (
                            'PENDING', 'CLAIMED', 'PUBLISHED', 'FAILED', 'DEAD_LETTER'
                        )),
    attempt_count       NUMBER DEFAULT 0 NOT NULL,
    last_error          VARCHAR2(4000),
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    claimed_at          TIMESTAMP WITH TIME ZONE,
    published_at        TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_moe_status ON mnp_outbox_events (status, created_at);

COMMENT ON TABLE mnp_workflow_branches IS
    'Config-driven state machine: for (status, event_type), the first branch whose condition is true (or the trailing default) runs, and only that one.';
COMMENT ON TABLE mnp_outbox_events IS
    'Transactional outbox. Populated by PKG_WORKFLOW_ENGINE; relayed by a .NET worker added in a later phase (not yet implemented).';
