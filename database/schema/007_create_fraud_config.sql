-- 007_create_fraud_config.sql
-- Phase E: Fraud/Number-Snatching Prevention velocity-guard config.
--
-- Singleton row, same shape as mnp_business_hours/mnp_outbox_config. A
-- dedicated table rather than overloading mnp_timers - this is a window
-- plus a count threshold together, not a duration-to-expiry concept.
CREATE TABLE mnp_fraud_config (
    id                      NUMBER PRIMARY KEY CHECK (id = 1),
    velocity_window_days    NUMBER NOT NULL,
    max_requests_per_window NUMBER NOT NULL
);

COMMENT ON TABLE mnp_fraud_config IS
    'Singleton config for PKG_FRAUD_PREVENTION.pr_check_velocity: blocks a new port request if max_requests_per_window-or-more requests already exist for the same MSISDN within the last velocity_window_days calendar days.';
