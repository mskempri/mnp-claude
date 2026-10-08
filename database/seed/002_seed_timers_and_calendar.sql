-- 002_seed_timers_and_calendar.sql
-- Business-hours window, Greek public holidays, and timer durations.
--
-- Durations below are EXAMPLE/placeholder data for local dev and testing,
-- not asserted regulatory fact - confirm against the actual porting
-- regulations for the operating jurisdiction before relying on these
-- figures anywhere but local dev. Per the design principle carried through
-- this project: timer durations are never hardcoded in PL/SQL, only ever
-- read from this table, so correcting them later is a data change, not a
-- code change.

INSERT INTO mnp_business_hours (id, start_time, end_time, time_zone) VALUES
    (1, '09:00', '17:00', 'Europe/Athens');

INSERT INTO mnp_timers (timer_code, description, duration_units, unit_of_measure) VALUES
    ('PORT_SLA', 'Overall regulatory window from request receipt to validation outcome (example value - confirm against jurisdiction).', 1, 'WD');
INSERT INTO mnp_timers (timer_code, description, duration_units, unit_of_measure) VALUES
    ('CUTOVER_WINDOW', 'Gap between scheduling and cutover execution (example value - confirm against jurisdiction).', 2, 'BH');

-- Greek public holidays, 2026 - fixed-date holidays only. Deliberately NOT
-- included: the four movable Orthodox feast dates that depend on the Paschal
-- computation (Clean Monday / Kathara Deftera, Good Friday, Easter Monday,
-- Whit Monday / Agiou Pnevmatos). Asserting those dates here without
-- verifying them against an authoritative Greek calendar source would be
-- presenting a guess as fact for a table whose entire purpose is correctness
-- of regulatory timer arithmetic - add them once confirmed, rather than now.
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-01-01', 'New Year''s Day');
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-01-06', 'Epiphany');
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-03-25', 'Greek Independence Day');
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-05-01', 'Labour Day');
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-08-15', 'Assumption of Mary');
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-10-28', 'Ochi Day');
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-12-25', 'Christmas Day');
INSERT INTO mnp_calendar_holidays (holiday_date, description) VALUES
    (DATE '2026-12-26', 'Synaxis of the Mother of God');

COMMIT;
