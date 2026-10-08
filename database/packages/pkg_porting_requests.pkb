CREATE OR REPLACE PACKAGE BODY pkg_porting_requests AS

    FUNCTION is_transition_allowed(
        p_from IN VARCHAR2,
        p_to   IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN CASE p_from
            WHEN 'RECEIVED'   THEN p_to IN ('VALIDATING', 'REJECTED', 'CANCELLED')
            WHEN 'VALIDATING' THEN p_to IN ('APPROVED', 'REJECTED', 'CANCELLED')
            WHEN 'APPROVED'   THEN p_to IN ('SCHEDULED', 'CANCELLED')
            WHEN 'SCHEDULED'  THEN p_to IN ('COMPLETED', 'CANCELLED')
            ELSE FALSE -- REJECTED, COMPLETED, CANCELLED are terminal
        END;
    END is_transition_allowed;

    FUNCTION fn_create_request(
        p_msisdn                 IN VARCHAR2,
        p_donor_network_code     IN VARCHAR2,
        p_recipient_network_code IN VARCHAR2,
        p_requested_porting_date IN DATE
    ) RETURN NUMBER IS
        v_id mnp_porting_requests.id%TYPE;
    BEGIN
        IF NOT REGEXP_LIKE(p_msisdn, '^\+?[0-9]{8,15}$') THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid MSISDN format: ' || p_msisdn);
        END IF;

        INSERT INTO mnp_porting_requests (
            msisdn, donor_network_code, recipient_network_code,
            status, requested_porting_date, created_at, updated_at
        ) VALUES (
            p_msisdn, p_donor_network_code, p_recipient_network_code,
            'RECEIVED', p_requested_porting_date, SYSTIMESTAMP, SYSTIMESTAMP
        )
        RETURNING id INTO v_id;

        RETURN v_id;
    END fn_create_request;

    PROCEDURE pr_get_request(
        p_id     IN  NUMBER,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT id, msisdn, donor_network_code, recipient_network_code,
                   status, requested_porting_date, rejection_reason,
                   created_at, updated_at
            FROM mnp_porting_requests
            WHERE id = p_id;
    END pr_get_request;

    PROCEDURE pr_get_requests_by_msisdn(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT id, msisdn, donor_network_code, recipient_network_code,
                   status, requested_porting_date, rejection_reason,
                   created_at, updated_at
            FROM mnp_porting_requests
            WHERE msisdn = p_msisdn
            ORDER BY created_at DESC;
    END pr_get_requests_by_msisdn;

    PROCEDURE pr_update_status(
        p_id     IN NUMBER,
        p_status IN VARCHAR2,
        p_reason IN VARCHAR2 DEFAULT NULL
    ) IS
        v_current_status mnp_porting_requests.status%TYPE;
    BEGIN
        SELECT status INTO v_current_status
        FROM mnp_porting_requests
        WHERE id = p_id
        FOR UPDATE;

        IF NOT is_transition_allowed(v_current_status, p_status) THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Cannot transition porting request ' || p_id ||
                ' from ' || v_current_status || ' to ' || p_status);
        END IF;

        UPDATE mnp_porting_requests
        SET status = p_status,
            rejection_reason = p_reason,
            updated_at = SYSTIMESTAMP
        WHERE id = p_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Porting request not found: ' || p_id);
    END pr_update_status;

END pkg_porting_requests;
/
