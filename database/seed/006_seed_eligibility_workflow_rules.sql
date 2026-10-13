-- 006_seed_eligibility_workflow_rules.sql
-- Phase C: wires VALIDATING into the rule engine as the real
-- pending-eligibility state, and registers the PAC_VALIDITY duration used by
-- PKG_PORTING_REQUESTS.fn_create_request's PAC-expiry check.
--
-- Appends on top of seed/001 rather than editing it in place (seed scripts
-- aren't idempotent and already-applied ones are never edited - see
-- database/README.md). Re-run seed/003_validate_reachability.sql afterward
-- (expect: no rows).

-- PAC_VALIDITY is a pure duration lookup via PKG_CALENDAR, read synchronously
-- at request-creation time - never instantiated as a mnp_timer_instances row,
-- never swept. Example value - confirm against jurisdiction, same caveat as
-- every other duration in seed/002.
INSERT INTO mnp_timers (timer_code, description, duration_units, unit_of_measure) VALUES
    ('PAC_VALIDITY', 'Window during which an issued PAC code remains valid (example value - confirm against jurisdiction).', 30, 'CD');

-- Newly created requests now move straight to VALIDATING instead of sitting
-- in RECEIVED with no status of their own while awaiting donor-network
-- eligibility confirmation.
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'VALIDATING' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'CREATED' AND branch_sequence = 1;

-- The old RECEIVED/VALIDATION_PASSED and RECEIVED/VALIDATION_FAILED branches
-- are now unreachable (CREATED always moves the request on to VALIDATING) -
-- deactivate rather than delete, consistent with how the engine filters on
-- active_flag = 'Y' everywhere else.
UPDATE mnp_workflow_branches
   SET active_flag = 'N'
 WHERE status = 'RECEIVED' AND event_type IN ('VALIDATION_PASSED', 'VALIDATION_FAILED');

-- Branches: VALIDATING - mirror the deactivated RECEIVED ones exactly.
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('VALIDATING', 'VALIDATION_PASSED', 1, NULL, 'Donor validation succeeded: approve.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('VALIDATING', 'VALIDATION_FAILED', 1, NULL, 'Donor validation failed: reject with reason.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('VALIDATING', 'CANCEL', 1, NULL, 'Customer cancels while awaiting eligibility outcome.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('VALIDATING', 'TIMER_EXPIRED', 1, NULL, 'Overall SLA timer expired while still awaiting validation: alert only, no transition.');

-- Actions: VALIDATING/VALIDATION_PASSED
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_TIMER', 'PORT_SLA' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'VALIDATION_PASSED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'APPROVED' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'VALIDATION_PASSED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'SEND_NOTIFICATION', 'REQUEST_APPROVED' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'VALIDATION_PASSED' AND branch_sequence = 1;

-- Actions: VALIDATING/VALIDATION_FAILED
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_TIMER', 'PORT_SLA' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RECORD_REJECTION_REASON', NULL FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'REJECTED' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'SEND_NOTIFICATION', 'REQUEST_REJECTED' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;

-- Actions: VALIDATING/CANCEL
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_TIMER', 'PORT_SLA' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'CANCEL' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'CANCEL' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'SEND_NOTIFICATION', 'REQUEST_CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'CANCEL' AND branch_sequence = 1;

-- Actions: VALIDATING/TIMER_EXPIRED (alert only, no transition)
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'SEND_NOTIFICATION', 'SLA_AT_RISK' FROM mnp_workflow_branches
 WHERE status = 'VALIDATING' AND event_type = 'TIMER_EXPIRED' AND branch_sequence = 1;

COMMIT;
