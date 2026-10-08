CREATE OR REPLACE PACKAGE pkg_conditions AS
    -- Named condition dispatch for workflow branches. An unknown condition
    -- name RAISES rather than returning a sentinel a caller might mistake
    -- for "false" — the legacy reference system's evaluate() returned -1 for
    -- an unrecognised name, which its engine then treated identically to a
    -- false result, silently skipping the branch instead of surfacing a
    -- config error. That failure mode is not reproduced here.

    FUNCTION fn_evaluate(
        p_condition_name IN VARCHAR2,
        p_request_id     IN NUMBER,
        p_context        IN VARCHAR2,
        p_explanation    OUT VARCHAR2
    ) RETURN BOOLEAN;

END pkg_conditions;
/
