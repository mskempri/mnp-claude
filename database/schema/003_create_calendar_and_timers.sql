-- 003_create_calendar_and_timers.sql
-- SLA/Timer service backing tables. Durations, holidays, and business hours
-- are DATA (seeded in database/seed/), never hardcoded in PL/SQL.
--
-- Deliberately simpler than the legacy reference calendar: this holds one
-- holiday list, not a public/transfer-holiday split. That split existed in
-- the legacy system for a reason specific to its own settlement process that
-- isn't established here; introducing it now would be inventing a business
-- rule, not reusing one. Revisit if a real requirement for it shows up.
CREATE TABLE mnp_calendar_holidays (
    holiday_date    DATE PRIMARY KEY,
    description     VARCHAR2(200) NOT NULL
);

-- Singleton config row: the business-hours window, interpreted in time_zone
-- (Europe/Athens for this deployment) regardless of DB session/host time zone.
CREATE TABLE mnp_business_hours (
    id          NUMBER PRIMARY KEY CHECK (id = 1),
    start_time  VARCHAR2(5) NOT NULL,  -- 'HH24:MI', local to time_zone
    end_time    VARCHAR2(5) NOT NULL,
    time_zone   VARCHAR2(40) DEFAULT 'Europe/Athens' NOT NULL
);

CREATE TABLE mnp_timers (
    timer_code      VARCHAR2(40) PRIMARY KEY,
    description     VARCHAR2(200) NOT NULL,
    duration_units  NUMBER NOT NULL,
    unit_of_measure VARCHAR2(2) NOT NULL CHECK (unit_of_measure IN ('WD', 'BH', 'CD')),
    active_flag     VARCHAR2(1) DEFAULT 'Y' NOT NULL CHECK (active_flag IN ('Y', 'N'))
);

COMMENT ON COLUMN mnp_timers.unit_of_measure IS 'WD = working days, BH = business hours, CD = calendar days';

CREATE TABLE mnp_timer_instances (
    id                  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    porting_request_id  NUMBER NOT NULL REFERENCES mnp_porting_requests (id),
    timer_code          VARCHAR2(40) NOT NULL REFERENCES mnp_timers (timer_code),
    status              VARCHAR2(20) DEFAULT 'RUNNING' NOT NULL CHECK (status IN (
                            'RUNNING', 'EXPIRED', 'CANCELLED'
                        )),
    started_at          TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    expires_at          TIMESTAMP WITH TIME ZONE NOT NULL,
    processed_at        TIMESTAMP WITH TIME ZONE
);

-- Sweep scans for RUNNING timers past their expiry; this index makes that a
-- cheap range scan instead of a full table scan as the table grows.
CREATE INDEX ix_mti_sweep ON mnp_timer_instances (status, expires_at);
CREATE INDEX ix_mti_request ON mnp_timer_instances (porting_request_id, timer_code);
