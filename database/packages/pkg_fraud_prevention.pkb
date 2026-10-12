CREATE OR REPLACE PACKAGE BODY pkg_fraud_prevention AS

    PROCEDURE pr_check_velocity(p_msisdn IN VARCHAR2) IS
        v_window_days  mnp_fraud_config.velocity_window_days%TYPE;
        v_max_requests mnp_fraud_config.max_requests_per_window%TYPE;
        v_window_start TIMESTAMP WITH TIME ZONE;
        v_count        NUMBER;
    BEGIN
        SELECT velocity_window_days, max_requests_per_window
          INTO v_window_days, v_max_requests
          FROM mnp_fraud_config
         WHERE id = 1;

        -- Plain date arithmetic, so a negative day count correctly walks
        -- backward - reuses the project's one sanctioned Europe/Athens
        -- arithmetic path instead of a raw SYSTIMESTAMP expression.
        v_window_start := pkg_calendar.fn_add_calendar_days(SYSTIMESTAMP, -v_window_days);

        SELECT COUNT(*) INTO v_count
          FROM mnp_porting_requests
         WHERE msisdn = p_msisdn
           AND created_at >= v_window_start;

        IF v_count >= v_max_requests THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Suspicious port velocity for MSISDN ' || p_msisdn || ': ' ||
                v_count || ' request(s) within the last ' || v_window_days ||
                ' day(s) (limit ' || v_max_requests || ').');
        END IF;
    END pr_check_velocity;

END pkg_fraud_prevention;
/
