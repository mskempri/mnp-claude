CREATE OR REPLACE PACKAGE BODY pkg_workflow_engine AS

    PROCEDURE pr_run_branch_actions(
        p_request_id  IN NUMBER,
        p_event_type  IN VARCHAR2,
        p_from_status IN VARCHAR2,
        p_context     IN VARCHAR2,
        p_branch_id   IN NUMBER
    ) IS
        v_halted BOOLEAN := FALSE;
    BEGIN
        FOR act IN (
            SELECT id, action_type, action_parameter
              FROM mnp_workflow_actions
             WHERE branch_id = p_branch_id
               AND active_flag = 'Y'
             ORDER BY action_sequence
        ) LOOP
            DECLARE
                v_to_status mnp_porting_requests.status%TYPE := NULL;
            BEGIN
                CASE act.action_type
                    WHEN 'TRANSITION_TO' THEN
                        UPDATE mnp_porting_requests
                           SET status = act.action_parameter, updated_at = SYSTIMESTAMP
                         WHERE id = p_request_id;
                        v_to_status := act.action_parameter;

                    WHEN 'SEND_NOTIFICATION' THEN
                        pkg_outbox.pr_enqueue(p_request_id, act.action_parameter, p_event_type);

                    WHEN 'START_TIMER' THEN
                        pkg_timers.pr_start_timer(p_request_id, act.action_parameter);

                    WHEN 'STOP_TIMER' THEN
                        pkg_timers.pr_cancel_timer(p_request_id, act.action_parameter);

                    WHEN 'RECORD_REJECTION_REASON' THEN
                        UPDATE mnp_porting_requests
                           SET rejection_reason = p_context
                         WHERE id = p_request_id;

                    WHEN 'RECORD_NUMBER_OWNERSHIP' THEN
                        pkg_number_registry.pr_record_port_completed(p_request_id);

                    WHEN 'HALT' THEN
                        v_halted := TRUE;

                    ELSE
                        RAISE_APPLICATION_ERROR(-20013, 'Unknown action type: ' || act.action_type);
                END CASE;

                INSERT INTO mnp_workflow_audit_log (
                    porting_request_id, event_type, from_status, context_value,
                    branch_id, action_id, action_type, action_parameter, halted_flag, to_status
                ) VALUES (
                    p_request_id, p_event_type, p_from_status, p_context,
                    p_branch_id, act.id, act.action_type, act.action_parameter,
                    CASE WHEN v_halted THEN 'Y' ELSE 'N' END, v_to_status
                );
            END;

            EXIT WHEN v_halted;
        END LOOP;
    END pr_run_branch_actions;

    PROCEDURE pr_process_event(
        p_request_id      IN NUMBER,
        p_current_status  IN VARCHAR2,
        p_event_type      IN VARCHAR2,
        p_context         IN VARCHAR2 DEFAULT NULL
    ) IS
        v_matched     BOOLEAN := FALSE;
        v_cond_result BOOLEAN;
        v_explanation VARCHAR2(400);
    BEGIN
        FOR br IN (
            SELECT id, condition_name
              FROM mnp_workflow_branches
             WHERE status = p_current_status
               AND event_type = p_event_type
               AND active_flag = 'Y'
             ORDER BY branch_sequence
        ) LOOP
            IF br.condition_name IS NOT NULL THEN
                v_cond_result := pkg_conditions.fn_evaluate(
                    br.condition_name, p_request_id, p_context, v_explanation
                );

                INSERT INTO mnp_workflow_audit_log (
                    porting_request_id, event_type, from_status, context_value,
                    branch_id, condition_name, condition_result
                ) VALUES (
                    p_request_id, p_event_type, p_current_status, p_context,
                    br.id, br.condition_name, CASE WHEN v_cond_result THEN 'Y' ELSE 'N' END
                );

                IF NOT v_cond_result THEN
                    CONTINUE;
                END IF;
            ELSE
                INSERT INTO mnp_workflow_audit_log (
                    porting_request_id, event_type, from_status, context_value, branch_id
                ) VALUES (
                    p_request_id, p_event_type, p_current_status, p_context, br.id
                );
            END IF;

            v_matched := TRUE;
            pr_run_branch_actions(p_request_id, p_event_type, p_current_status, p_context, br.id);
            EXIT;
        END LOOP;

        IF NOT v_matched THEN
            RAISE_APPLICATION_ERROR(-20012,
                'Unhandled event ' || p_event_type || ' for status ' || p_current_status ||
                ' (request ' || p_request_id || '): no matching branch and no default branch defined.');
        END IF;
    END pr_process_event;

END pkg_workflow_engine;
/
