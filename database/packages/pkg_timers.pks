CREATE OR REPLACE PACKAGE pkg_timers AS
    -- Timer lifecycle for the SLA/Timer service. Durations/units live in
    -- MNP_TIMERS (data); expiry is computed via PKG_CALENDAR at start time,
    -- so sweeping is a cheap "expires_at <= now" scan.

    PROCEDURE pr_start_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    );

    PROCEDURE pr_cancel_timer(
        p_request_id  IN NUMBER,
        p_timer_code  IN VARCHAR2
    );

    -- Claims exactly one expired RUNNING timer (FOR UPDATE SKIP LOCKED, so
    -- concurrent callers never double-claim the same row), locks its owning
    -- request, raises TIMER_EXPIRED through the engine, and marks the timer
    -- EXPIRED - all in one transaction/one call, with no separate
    -- claim-then-process step. That single-transaction shape is deliberate:
    -- the legacy reference's timer worker had a visible claim/process split
    -- with no locking in between, which is exactly the shape that allows two
    -- concurrent workers to double-process the same expired timer. Here
    -- there is no window in which that race can occur.
    --
    -- Returns the timer_instance id it processed, or NULL if nothing was
    -- due. Callers (SQL*Plus for now; a scheduled .NET caller is a later
    -- phase) should call this repeatedly until it returns NULL.
    --
    -- Does not guarantee oldest-expired-timer-first ordering under
    -- concurrent callers (see implementation comment) - only that each call
    -- claims exactly one unlocked expired timer, never the same one twice.
    FUNCTION fn_sweep_and_process_one_expired_timer RETURN NUMBER;

END pkg_timers;
/
