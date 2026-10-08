-- 005_validate_notification_registrations.sql
-- Verification query, not a migration: confirms every distinct
-- action_parameter used by an active SEND_NOTIFICATION action has a matching
-- MNP_NOTIFICATION_TYPES row. Expected result: no rows. Catches "forgot to
-- register one of the notification types" at seed time instead of at
-- first-runtime PKG_OUTBOX.pr_enqueue raise.

SELECT DISTINCT a.action_parameter AS unregistered_notification_event_type
  FROM mnp_workflow_actions a
  JOIN mnp_workflow_branches b ON b.id = a.branch_id
 WHERE a.action_type = 'SEND_NOTIFICATION'
   AND a.active_flag = 'Y'
   AND b.active_flag = 'Y'
   AND NOT EXISTS (
       SELECT 1 FROM mnp_notification_types nt
        WHERE nt.event_type = a.action_parameter
   );
