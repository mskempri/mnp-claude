CREATE OR REPLACE PACKAGE pkg_porting_requests AS
    -- Owns all business rules for the porting-request lifecycle: creation,
    -- lookup, and status transitions. The .NET layer only calls these
    -- entry points and must not read/write mnp_porting_requests directly.

    e_invalid_msisdn       EXCEPTION;
    e_invalid_transition   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_msisdn, -20001);
    PRAGMA EXCEPTION_INIT(e_invalid_transition, -20002);

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

    PROCEDURE pr_update_status(
        p_id     IN NUMBER,
        p_status IN VARCHAR2,
        p_reason IN VARCHAR2 DEFAULT NULL
    );

END pkg_porting_requests;
/
