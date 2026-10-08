-- 005_create_outbox_relay_tables.sql
-- Supports the Notification/Event relay: who an outbox event is for, and
-- how many times to retry before giving up. MNP_OUTBOX_EVENTS itself already
-- exists (002_create_workflow_engine_tables.sql) - this only extends it.

CREATE TABLE mnp_notification_types (
    event_type   VARCHAR2(40) PRIMARY KEY,
    audience     VARCHAR2(20) NOT NULL CHECK (audience IN (
                     'DONOR_NETWORK', 'RECIPIENT_NETWORK', 'CUSTOMER', 'OPERATIONS'
                 )),
    description  VARCHAR2(200) NOT NULL
);

COMMENT ON TABLE mnp_notification_types IS
    'Registry of valid SEND_NOTIFICATION action_parameter values and who each is for. An unregistered event_type raises (PKG_OUTBOX.pr_enqueue), never silently enqueues with an unknown audience.';

-- Singleton config row, mirroring MNP_BUSINESS_HOURS.
CREATE TABLE mnp_outbox_config (
    id            NUMBER PRIMARY KEY CHECK (id = 1),
    max_attempts  NUMBER NOT NULL
);

ALTER TABLE mnp_outbox_events ADD (
    audience VARCHAR2(20) CHECK (audience IN (
        'DONOR_NETWORK', 'RECIPIENT_NETWORK', 'CUSTOMER', 'OPERATIONS'
    ))
);

COMMENT ON COLUMN mnp_outbox_events.audience IS
    'Nullable because rows enqueued before this column existed (Phase A dev data) predate it. Every row enqueued via PKG_OUTBOX.pr_enqueue going forward has this populated.';
