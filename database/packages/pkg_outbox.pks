CREATE OR REPLACE PACKAGE pkg_outbox AS
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
