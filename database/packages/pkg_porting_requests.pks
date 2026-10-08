CREATE OR REPLACE PACKAGE pkg_porting_requests AS
    -- Owns the porting-request aggregate. .NET calls only this package -
    -- never the engine/conditions/calendar packages, and never the table
    -- directly. State transitions are no longer decided here: PR_RAISE_EVENT
    -- hands off to PKG_WORKFLOW_ENGINE, which alone decides the resulting
    -- status from data in MNP_WORKFLOW_BRANCHES/MNP_WORKFLOW_ACTIONS. There
    -- is deliberately no direct status setter any more (no PR_UPDATE_STATUS) -
    -- every status change must go through an event, so there is exactly one
    -- way a request's status can change, not two.

    e_invalid_msisdn           EXCEPTION;
    e_duplicate_open_request   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_msisdn, -20001);
    PRAGMA EXCEPTION_INIT(e_duplicate_open_request, -20004);

    FUNCTION fn_create_request(
        p_msisdn                 IN VARCHAR2,
        p_donor_network_code     IN VARCHAR2,
        p_recipient_network_code IN VARCHAR2,
        p_requested_porting_date IN DATE
    ) RETURN NUMBER;

    PROCEDURE pr_get_request(
        p_id     IN  NUMBER,
        p_cursor OUT SYS_REFCURSOR
    );

    PROCEDURE pr_get_requests_by_msisdn(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    );

    -- Raises an event against the request's current status. Takes the row
    -- lock itself (FOR UPDATE) before delegating to the engine, so this is
    -- the single serialization point for concurrent events on one request.
    PROCEDURE pr_raise_event(
        p_id         IN NUMBER,
        p_event_type IN VARCHAR2,
        p_context    IN VARCHAR2 DEFAULT NULL
    );

END pkg_porting_requests;
/
