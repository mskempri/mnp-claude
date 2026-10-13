-- 007_seed_number_registry_action.sql
-- Phase D: registers RECORD_NUMBER_OWNERSHIP and appends it to the existing
-- CUTOVER/CUTOVER_COMPLETE branch, so a completed port updates
-- mnp_number_ownership in the same transaction as the status change.
-- Appends on top of seed/001 rather than editing it in place.

INSERT INTO mnp_workflow_action_types (action_type, description) VALUES
    ('RECORD_NUMBER_OWNERSHIP', 'Upserts mnp_number_ownership to reflect the request''s recipient_network_code as of this port completing.');

INSERT INTO mnp_workflow_actions (branch_id, action_sequence, action_type, action_parameter)
SELECT id, 3, 'RECORD_NUMBER_OWNERSHIP', NULL FROM mnp_workflow_branches
 WHERE status = 'CUTOVER' AND event_type = 'CUTOVER_COMPLETE' AND branch_sequence = 1;

COMMIT;
