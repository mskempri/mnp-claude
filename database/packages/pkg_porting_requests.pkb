CREATE OR REPLACE PACKAGE BODY pkg_porting_requests AS

    FUNCTION fn_create_request(
        p_msisdn                 IN VARCHAR2,
        p_donor_network_code     IN VARCHAR2,
        p_recipient_network_code IN VARCHAR2,
        p_requested_porting_date IN DATE,
        p_pac_code               IN VARCHAR2,
        p_pac_issued_date        IN DATE
    ) RETURN NUMBER IS
        v_id         mnp_porting_requests.id%TYPE;
        v_pac_expiry TIMESTAMP WITH TIME ZONE;
    BEGIN
        IF NOT REGEXP_LIKE(p_msisdn, '^\+?[0-9]{8,15}$') THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid MSISDN format: ' || p_msisdn);
        END IF;

        pkg_fraud_prevention.pr_check_velocity(p_msisdn);

        IF p_pac_code IS NULL OR NOT REGEXP_LIKE(p_pac_code, '^[A-Z0-9]{6,12}$') THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid PAC code: ' || NVL(p_pac_code, '<null>'));
        END IF;

        IF p_pac_issued_date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'PAC issued date is required.');
        END IF;

        -- PAC_VALIDITY is a pure duration lookup via PKG_CALENDAR (example
        -- value - confirm against jurisdiction, see seed/006), not a timer
        -- instance: this is a synchronous check at submission time, never
        -- swept.
        v_pac_expiry := pkg_calendar.fn_calc_timer_expiry(
            FROM_TZ(CAST(p_pac_issued_date AS TIMESTAMP), 'Europe/Athens'), 'PAC_VALIDITY');
        IF SYSTIMESTAMP > v_pac_expiry THEN
            RAISE_APPLICATION_ERROR(-20002, 'PAC code expired on ' || TO_CHAR(v_pac_expiry, 'YYYY-MM-DD'));
        END IF;

        INSERT INTO mnp_porting_requests (
            msisdn, donor_network_code, recipient_network_code,
            status, requested_porting_date, pac_code, pac_issued_date,
            created_at, updated_at
        ) VALUES (
            p_msisdn, p_donor_network_code, p_recipient_network_code,
            'RECEIVED', p_requested_porting_date, p_pac_code, p_pac_issued_date,
            SYSTIMESTAMP, SYSTIMESTAMP
        )
        RETURNING id INTO v_id;

        -- Row was just inserted in this transaction, so no separate lock is
        -- needed before handing off to the engine.
        pkg_workflow_engine.pr_process_event(v_id, 'RECEIVED', 'CREATED');

        RETURN v_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20004,
                'An open porting request already exists for MSISDN ' || p_msisdn || '.');
    END fn_create_request;

    PROCEDURE pr_get_request(
        p_id     IN  NUMBER,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT id, msisdn, donor_network_code, recipient_network_code,
                   status, requested_porting_date, rejection_reason,
                   pac_code, pac_issued_date,
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
                   pac_code, pac_issued_date,
                   created_at, updated_at
            FROM mnp_porting_requests
            WHERE msisdn = p_msisdn
            ORDER BY created_at DESC;
    END pr_get_requests_by_msisdn;

    PROCEDURE pr_raise_event(
        p_id         IN NUMBER,
        p_event_type IN VARCHAR2,
        p_context    IN VARCHAR2 DEFAULT NULL
    ) IS
        v_status mnp_porting_requests.status%TYPE;
    BEGIN
        SELECT status INTO v_status
          FROM mnp_porting_requests
         WHERE id = p_id
           FOR UPDATE;

        pkg_workflow_engine.pr_process_event(p_id, v_status, p_event_type, p_context);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Porting request not found: ' || p_id);
    END pr_raise_event;

END pkg_porting_requests;
/
