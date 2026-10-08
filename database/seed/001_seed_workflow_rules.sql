-- 001_seed_workflow_rules.sql
-- Re-expresses the porting-request lifecycle (previously the hardcoded
-- is_transition_allowed CASE statement) as data. Apply once against a fresh
-- schema; re-running will fail on the unique constraints (it isn't
-- idempotent, by design, like the numbered schema scripts).
--
-- Lifecycle covered:
--   RECEIVED -> APPROVED (VALIDATION_PASSED) | REJECTED (VALIDATION_FAILED) | CANCELLED (CANCEL)
--   APPROVED -> SCHEDULED (SCHEDULE) | CANCELLED (CANCEL)
--   SCHEDULED -> CUTOVER (TIMER_EXPIRED, cutover-window timer) | CANCELLED (CANCEL)
--   CUTOVER -> COMPLETED (CUTOVER_COMPLETE)
-- CUTOVER has no CANCEL branch: once cutover begins, the cancellation window
-- has closed. Raising CANCEL in CUTOVER is correctly unhandled - the engine
-- will raise, not silently ignore it.
-- VALIDATING is intentionally not wired to anything yet: Phase C's
-- eligibility work introduces the async validation step that rests there.
-- Reaching it today is impossible, so it needs no branches yet.

-- Condition registry
INSERT INTO mnp_conditions (condition_name, description) VALUES
    ('IS_CUTOVER_TIMER', 'True when the TIMER_EXPIRED event''s context is the CUTOVER_WINDOW timer code.');

-- Action type registry
INSERT INTO mnp_workflow_action_types (action_type, description) VALUES
    ('TRANSITION_TO', 'Sets the request''s status to action_parameter.');
INSERT INTO mnp_workflow_action_types (action_type, description) VALUES
    ('SEND_NOTIFICATION', 'Enqueues an outbox event of type action_parameter.');
INSERT INTO mnp_workflow_action_types (action_type, description) VALUES
    ('START_TIMER', 'Starts a timer instance for the timer code in action_parameter.');
INSERT INTO mnp_workflow_action_types (action_type, description) VALUES
    ('STOP_TIMER', 'Cancels the running timer instance for the timer code in action_parameter.');
INSERT INTO mnp_workflow_action_types (action_type, description) VALUES
    ('RECORD_REJECTION_REASON', 'Writes the event''s context value into rejection_reason.');
INSERT INTO mnp_workflow_action_types (action_type, description) VALUES
    ('HALT', 'Stops processing further actions in this branch. No production branch currently uses this; verified via the inactive RECEIVED/__TEST_HALT__ fixture branch (active_flag=N) - see database/README.md.');

-- Branches: RECEIVED
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('RECEIVED', 'CREATED', 1, NULL, 'Request received: start the overall SLA timer and notify.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('RECEIVED', 'VALIDATION_PASSED', 1, NULL, 'Donor validation succeeded: approve.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('RECEIVED', 'VALIDATION_FAILED', 1, NULL, 'Donor validation failed: reject with reason.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('RECEIVED', 'CANCEL', 1, NULL, 'Customer cancels before validation completes.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('RECEIVED', 'TIMER_EXPIRED', 1, NULL, 'Overall SLA timer expired while still awaiting validation: alert only, no transition.');

-- Branches: APPROVED
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('APPROVED', 'SCHEDULE', 1, NULL, 'Cutover date/time confirmed: schedule and start the cutover-window timer.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('APPROVED', 'CANCEL', 1, NULL, 'Customer cancels after approval, before scheduling.');

-- Branches: SCHEDULED
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('SCHEDULED', 'TIMER_EXPIRED', 1, 'IS_CUTOVER_TIMER', 'The cutover-window timer expired: begin cutover.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('SCHEDULED', 'TIMER_EXPIRED', 2, NULL, 'Defensive default: some other timer code expired while SCHEDULED (should not happen in Phase A) - alert, no transition.');
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('SCHEDULED', 'CANCEL', 1, NULL, 'Customer cancels after scheduling, before cutover begins.');

-- Branches: CUTOVER
INSERT INTO mnp_workflow_branches (status, event_type, branch_sequence, condition_name, description) VALUES
    ('CUTOVER', 'CUTOVER_COMPLETE', 1, NULL, 'Transfer execution confirmed complete.');

-- Actions: RECEIVED/CREATED
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'START_TIMER', 'PORT_SLA' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'CREATED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'SEND_NOTIFICATION', 'REQUEST_RECEIVED' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'CREATED' AND branch_sequence = 1;

-- Actions: RECEIVED/VALIDATION_PASSED
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_TIMER', 'PORT_SLA' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'VALIDATION_PASSED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'APPROVED' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'VALIDATION_PASSED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'SEND_NOTIFICATION', 'REQUEST_APPROVED' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'VALIDATION_PASSED' AND branch_sequence = 1;

-- Actions: RECEIVED/VALIDATION_FAILED
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_TIMER', 'PORT_SLA' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'RECORD_REJECTION_REASON', NULL FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'TRANSITION_TO', 'REJECTED' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 4, 'SEND_NOTIFICATION', 'REQUEST_REJECTED' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'VALIDATION_FAILED' AND branch_sequence = 1;

-- Actions: RECEIVED/CANCEL
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_TIMER', 'PORT_SLA' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'CANCEL' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'CANCEL' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'SEND_NOTIFICATION', 'REQUEST_CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'CANCEL' AND branch_sequence = 1;

-- Actions: RECEIVED/TIMER_EXPIRED (alert only, no transition)
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'SEND_NOTIFICATION', 'SLA_AT_RISK' FROM mnp_workflow_branches
 WHERE status = 'RECEIVED' AND event_type = 'TIMER_EXPIRED' AND branch_sequence = 1;

-- Actions: APPROVED/SCHEDULE
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'SCHEDULED' FROM mnp_workflow_branches
 WHERE status = 'APPROVED' AND event_type = 'SCHEDULE' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'START_TIMER', 'CUTOVER_WINDOW' FROM mnp_workflow_branches
 WHERE status = 'APPROVED' AND event_type = 'SCHEDULE' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'SEND_NOTIFICATION', 'REQUEST_SCHEDULED' FROM mnp_workflow_branches
 WHERE status = 'APPROVED' AND event_type = 'SCHEDULE' AND branch_sequence = 1;

-- Actions: APPROVED/CANCEL
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'APPROVED' AND event_type = 'CANCEL' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'SEND_NOTIFICATION', 'REQUEST_CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'APPROVED' AND event_type = 'CANCEL' AND branch_sequence = 1;

-- Actions: SCHEDULED/TIMER_EXPIRED, branch 1 (IS_CUTOVER_TIMER = true)
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'CUTOVER' FROM mnp_workflow_branches
 WHERE status = 'SCHEDULED' AND event_type = 'TIMER_EXPIRED' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'SEND_NOTIFICATION', 'CUTOVER_STARTED' FROM mnp_workflow_branches
 WHERE status = 'SCHEDULED' AND event_type = 'TIMER_EXPIRED' AND branch_sequence = 1;

-- Actions: SCHEDULED/TIMER_EXPIRED, branch 2 (default/fallback)
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'SEND_NOTIFICATION', 'UNEXPECTED_TIMER_EXPIRY' FROM mnp_workflow_branches
 WHERE status = 'SCHEDULED' AND event_type = 'TIMER_EXPIRED' AND branch_sequence = 2;

-- Actions: SCHEDULED/CANCEL
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'STOP_TIMER', 'CUTOVER_WINDOW' FROM mnp_workflow_branches
 WHERE status = 'SCHEDULED' AND event_type = 'CANCEL' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'TRANSITION_TO', 'CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'SCHEDULED' AND event_type = 'CANCEL' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'SEND_NOTIFICATION', 'REQUEST_CANCELLED' FROM mnp_workflow_branches
 WHERE status = 'SCHEDULED' AND event_type = 'CANCEL' AND branch_sequence = 1;

-- Actions: CUTOVER/CUTOVER_COMPLETE
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 1, 'TRANSITION_TO', 'COMPLETED' FROM mnp_workflow_branches
 WHERE status = 'CUTOVER' AND event_type = 'CUTOVER_COMPLETE' AND branch_sequence = 1;
INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 2, 'SEND_NOTIFICATION', 'PORT_COMPLETED' FROM mnp_workflow_branches
 WHERE status = 'CUTOVER' AND event_type = 'CUTOVER_COMPLETE' AND branch_sequence = 1;

COMMIT;
