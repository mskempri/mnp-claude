CREATE OR REPLACE PACKAGE BODY pkg_calendar AS

    FUNCTION fn_is_working_day(p_date IN DATE) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        IF TO_CHAR(p_date, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT', 'SUN') THEN
            RETURN FALSE;
        END IF;

        SELECT COUNT(*) INTO v_count
        FROM mnp_calendar_holidays
        WHERE holiday_date = TRUNC(p_date);

        RETURN v_count = 0;
    END fn_is_working_day;

    FUNCTION fn_add_working_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_tz        VARCHAR2(40);
        v_cursor    DATE;
        v_remaining NUMBER := p_days;
    BEGIN
        SELECT time_zone INTO v_tz FROM mnp_business_hours WHERE id = 1;
        v_cursor := CAST(p_from AT TIME ZONE v_tz AS DATE);

        WHILE v_remaining > 0 LOOP
            v_cursor := v_cursor + 1;
            IF fn_is_working_day(v_cursor) THEN
                v_remaining := v_remaining - 1;
            END IF;
        END LOOP;

        RETURN FROM_TZ(CAST(v_cursor AS TIMESTAMP), v_tz);
    END fn_add_working_days;

    FUNCTION fn_add_business_hours(
        p_from  IN TIMESTAMP WITH TIME ZONE,
        p_hours IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_tz               VARCHAR2(40);
        v_start_time       VARCHAR2(5);
        v_end_time         VARCHAR2(5);
        v_cursor           DATE;
        v_day_start        DATE;
        v_day_end          DATE;
        v_remaining_minutes NUMBER;
        v_available_minutes NUMBER;
    BEGIN
        SELECT time_zone, start_time, end_time
          INTO v_tz, v_start_time, v_end_time
          FROM mnp_business_hours WHERE id = 1;

        v_cursor := CAST(p_from AT TIME ZONE v_tz AS DATE);
        v_remaining_minutes := p_hours * 60;

        -- Normalise the starting point onto a working day, within the window.
        LOOP
            v_day_end := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_end_time || ':00');
            EXIT WHEN fn_is_working_day(TRUNC(v_cursor)) AND v_cursor < v_day_end;
            v_cursor := TRUNC(v_cursor) + 1;
        END LOOP;

        v_day_start := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_start_time || ':00');
        IF v_cursor < v_day_start THEN
            v_cursor := v_day_start;
        END IF;

        LOOP
            v_day_end := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_end_time || ':00');
            v_available_minutes := (v_day_end - v_cursor) * 1440;

            IF v_remaining_minutes <= v_available_minutes THEN
                v_cursor := v_cursor + (v_remaining_minutes / 1440);
                EXIT;
            END IF;

            v_remaining_minutes := v_remaining_minutes - v_available_minutes;
            v_cursor := TRUNC(v_cursor) + 1;
            WHILE NOT fn_is_working_day(TRUNC(v_cursor)) LOOP
                v_cursor := v_cursor + 1;
            END LOOP;
            v_cursor := TRUNC(v_cursor) + TO_DSINTERVAL('0 ' || v_start_time || ':00');
        END LOOP;

        RETURN FROM_TZ(CAST(v_cursor AS TIMESTAMP), v_tz);
    END fn_add_business_hours;

    FUNCTION fn_add_calendar_days(
        p_from IN TIMESTAMP WITH TIME ZONE,
        p_days IN NUMBER
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_tz     VARCHAR2(40);
        v_cursor DATE;
    BEGIN
        SELECT time_zone INTO v_tz FROM mnp_business_hours WHERE id = 1;
        v_cursor := CAST(p_from AT TIME ZONE v_tz AS DATE) + p_days;
        RETURN FROM_TZ(CAST(v_cursor AS TIMESTAMP), v_tz);
    END fn_add_calendar_days;

    FUNCTION fn_calc_timer_expiry(
        p_anchor     IN TIMESTAMP WITH TIME ZONE,
        p_timer_code IN VARCHAR2
    ) RETURN TIMESTAMP WITH TIME ZONE IS
        v_units NUMBER;
        v_uom   VARCHAR2(2);
    BEGIN
        SELECT duration_units, unit_of_measure
          INTO v_units, v_uom
          FROM mnp_timers
         WHERE timer_code = p_timer_code
           AND active_flag = 'Y';

        RETURN CASE v_uom
            WHEN 'WD' THEN fn_add_working_days(p_anchor, v_units)
            WHEN 'BH' THEN fn_add_business_hours(p_anchor, v_units)
            WHEN 'CD' THEN fn_add_calendar_days(p_anchor, v_units)
        END;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'Unknown or inactive timer code: ' || p_timer_code);
    END fn_calc_timer_expiry;

END pkg_calendar;
/
