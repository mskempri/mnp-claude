CREATE OR REPLACE PACKAGE pkg_workflow_engine AS
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
