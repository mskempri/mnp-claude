-- 008_seed_fraud_config.sql
-- Example/placeholder velocity-guard values - confirm against actual fraud
-- policy before relying on these outside local dev, same caveat as every
-- other invented duration in this project (PAC validity, SLA/cutover timer
-- durations, the holiday calendar).

INSERT INTO mnp_fraud_config (id, velocity_window_days, max_requests_per_window) VALUES (1, 7, 3);

COMMIT;
