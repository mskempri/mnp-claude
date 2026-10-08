CREATE OR REPLACE PACKAGE pkg_calendar AS
    -- Working-day / business-hour / calendar-day arithmetic for SLA timers.
    -- All arithmetic is performed in the business-hours configuration's
    -- time_zone (Europe/Athens for this deployment, see mnp_business_hours),
    -- not the DB session's or host's default zone, and is DST-correct: "N
    -- calendar days later" lands on the same local wall-clock time on that
    -- date even across a DST transition, not simply N*24 hours later.
    --
    -- Deliberately has no bypass/override switch of any kind. The legacy
    -- reference system had a global flag that could collapse every
    -- regulatory timer to ~1 minute; that capability does not exist here,
    -- in any form, reachable from any build.

    FUNCTION fn_add_working_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE;

    FUNCTION fn_add_business_hours(
        p_from  IN TIMESTAMP WITH TIME ZONE,
        p_hours IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE;

    FUNCTION fn_add_calendar_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE;

    FUNCTION fn_calc_timer_expiry(
        p_anchor     IN TIMESTAMP WITH TIME ZONE,
        p_timer_code IN VARCHAR2
    ) RETURN TIMESTAMP WITH TIME ZONE;

END pkg_calendar;
/
