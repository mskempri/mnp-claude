-- 003_validate_reachability.sql
-- Verification query, not a migration: run after seeding to confirm every
-- non-terminal status has at least one active outgoing TRANSITION_TO branch.
-- VALIDATING is deliberately excluded - it is unreachable until Phase C wires
-- an async eligibility step into it; nothing currently transitions a request
-- into VALIDATING, so it needing no way out yet is expected, not a gap.
--
-- Expected result: no rows. Any row returned means a non-terminal status
-- would have no way to progress - the exact failure mode that let the
-- legacy reference system's HAS_DEBT_OBJECTION-gated rejection strand a
-- request in UNDER_REVIEW with no fallback branch.

SELECT s.status AS stranded_status
  FROM (
      SELECT 'RECEIVED' AS status FROM dual UNION ALL
      SELECT 'VALIDATING' FROM dual UNION ALL
      SELECT 'APPROVED' FROM dual UNION ALL
      SELECT 'SCHEDULED' FROM dual UNION ALL
      SELECT 'CUTOVER' FROM dual
  ) s
 WHERE s.status <> 'VALIDATING'
   AND NOT EXISTS (
       SELECT 1
         FROM mnp_workflow_branches b
         JOIN mnp_workflow_actions a ON a.branch_id = b.id
        WHERE b.status = s.status
          AND b.active_flag = 'Y'
          AND a.active_flag = 'Y'
          AND a.action_type = 'TRANSITION_TO'
   );
