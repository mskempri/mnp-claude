CREATE OR REPLACE PACKAGE BODY pkg_timers AS

    PROCEDURE pr_start_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    ) IS
        v_expires_at TIMESTAMP WITH TIME ZONE;
    BEGIN
        v_expires_at := pkg_calendar.fn_calc_timer_expiry(SYSTIMESTAMP, p_timer_code);

        INSERT INTO mnp_timer_instances (porting_request_id, timer_code, expires_at)
        VALUES (p_request_id, p_timer_code, v_expires_at);
    END pr_start_timer;

    PROCEDURE pr_cancel_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    ) IS
    BEGIN
        UPDATE mnp_timer_instances
           SET status = 'CANCELLED', processed_at = SYSTIMESTAMP
         WHERE porting_request_id = p_request_id
           AND timer_code = p_timer_code
           AND status = 'RUNNING';

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20014,
                'No RUNNING timer ' || p_timer_code || ' found for request ' ||
                p_request_id || ' to cancel.');
        END IF;
    END pr_cancel_timer;

    FUNCTION fn_sweep_and_process_one_expired_timer RETURN NUMBER IS
        v_timer_id        mnp_timer_instances.id%TYPE;
        v_request_id      mnp_porting_requests.id%TYPE;
        v_timer_code      mnp_timer_instances.timer_code%TYPE;
        v_current_status  mnp_porting_requests.status%TYPE;
    BEGIN
        -- FOR UPDATE does not support selecting through a view containing
        -- ORDER BY/DISTINCT/GROUP BY (ORA-02014), which rules out both
        -- FETCH FIRST...ROWS ONLY and an ORDER BY'd inline subquery here.
        -- ROWNUM = 1 directly against the base table (no ordering) is the
        -- idiom that remains compatible with FOR UPDATE SKIP LOCKED - the
        -- trade-off is that this does not guarantee strict oldest-expired-
        -- first processing under concurrent sweepers, only that each call
        -- claims exactly one unlocked expired timer. Acceptable for Phase A;
        -- revisit if strict FIFO ordering becomes a real requirement.
        SELECT id, porting_request_id, timer_code
          INTO v_timer_id, v_request_id, v_timer_code
          FROM mnp_timer_instances
         WHERE status = 'RUNNING'
           AND expires_at <= SYSTIMESTAMP
           AND ROWNUM = 1
           FOR UPDATE SKIP LOCKED;

        SELECT status INTO v_current_status
          FROM mnp_porting_requests
         WHERE id = v_request_id
           FOR UPDATE;

        pkg_workflow_engine.pr_process_event(
            v_request_id, v_current_status, 'TIMER_EXPIRED', v_timer_code
        );

        UPDATE mnp_timer_instances
           SET status = 'EXPIRED', processed_at = SYSTIMESTAMP
         WHERE id = v_timer_id;

        RETURN v_timer_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END fn_sweep_and_process_one_expired_timer;

END pkg_timers;
/
