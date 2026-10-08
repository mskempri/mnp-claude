CREATE OR REPLACE PACKAGE BODY pkg_conditions AS

    FUNCTION fn_is_cutover_timer(p_context IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN p_context = 'CUTOVER_WINDOW';
    END fn_is_cutover_timer;

    FUNCTION fn_evaluate(
        p_condition_name IN VARCHAR2,
        p_request_id     IN NUMBER,
        p_context        IN VARCHAR2,
        p_explanation    OUT VARCHAR2
    ) RETURN BOOLEAN IS
        v_result BOOLEAN;
    BEGIN
        CASE UPPER(p_condition_name)
            WHEN 'IS_CUTOVER_TIMER' THEN
                v_result := fn_is_cutover_timer(p_context);
            ELSE
                RAISE_APPLICATION_ERROR(-20011, 'Unknown condition: ' || p_condition_name);
        END CASE;

        p_explanation := p_condition_name || ' = ' ||
            CASE WHEN v_result THEN 'TRUE' ELSE 'FALSE' END ||
            ' (request_id=' || p_request_id || ', context=' || NVL(p_context, '<null>') || ')';

        RETURN v_result;
    END fn_evaluate;

END pkg_conditions;
/
