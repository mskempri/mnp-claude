-- 004_seed_notification_types.sql
-- Classifies each of Phase A's seeded SEND_NOTIFICATION event types to a
-- single audience. Principle: which single party's next real-world action
-- is unblocked by this event - not "who might find this interesting".
--
-- Flagged entries below are genuinely debatable, forced into one audience by
-- the "minimal fan-out for now" decision - treat as placeholder business
-- modeling to confirm later, same status as the timer durations and the
-- Greek holiday calendar.

INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('REQUEST_RECEIVED', 'CUSTOMER', 'Acknowledgment; no network action is gated on it.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('REQUEST_APPROVED', 'RECIPIENT_NETWORK', 'Debatable: could argue DONOR_NETWORK instead. Gaining carrier can proceed toward scheduling.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('REQUEST_REJECTED', 'CUSTOMER', 'Terminal; donor already knows (it produced the determination), customer needs the reason.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('REQUEST_CANCELLED', 'RECIPIENT_NETWORK', 'Debatable: could argue DONOR_NETWORK instead. Stands down in-flight scheduling/cutover prep.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('REQUEST_SCHEDULED', 'DONOR_NETWORK', 'Debatable: could argue RECIPIENT_NETWORK instead. Donor needs advance notice to prepare release.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('CUTOVER_STARTED', 'DONOR_NETWORK', 'Donor executes the decommission/release at this trigger.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('PORT_COMPLETED', 'CUSTOMER', 'Number is now live on the new network.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('SLA_AT_RISK', 'OPERATIONS', 'Internal alert; no customer/network action.');
INSERT INTO mnp_notification_types (event_type, audience, description) VALUES
    ('UNEXPECTED_TIMER_EXPIRY', 'OPERATIONS', 'Defensive fallback branch; should not happen in practice.');

INSERT INTO mnp_outbox_config (id, max_attempts) VALUES (1, 5);

COMMIT;
