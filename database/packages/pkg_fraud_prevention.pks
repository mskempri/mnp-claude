CREATE OR REPLACE PACKAGE pkg_fraud_prevention AS
    -- Fraud/Number-Snatching Prevention service (#5 in the six-service
    -- spec): a velocity guard against rapid/repeated port-request attempts
    -- for the same MSISDN. Distinct from UX_MPR_MSISDN_OPEN (schema/004),
    -- which only prevents two *concurrently open* requests - this catches
    -- rapid sequential resubmission after a prior request already closed
    -- (cancelled/rejected/completed), the actual number-snatching pattern.

    e_suspicious_velocity EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_suspicious_velocity, -20005);

    -- Raises e_suspicious_velocity if MNP_PORTING_REQUESTS already has
    -- max_requests_per_window-or-more rows for p_msisdn created within the
    -- last velocity_window_days calendar days (MNP_FRAUD_CONFIG; example
    -- values - confirm against actual fraud policy), counting requests of
    -- ANY status - the signal is repeated attempts, not just open ones.
    -- Called by PKG_PORTING_REQUESTS.fn_create_request before the new row
    -- is inserted, so it evaluates prior history only.
    PROCEDURE pr_check_velocity(p_msisdn IN VARCHAR2);

END pkg_fraud_prevention;
/
