CREATE OR REPLACE PACKAGE BODY pkg_outbox AS

    PROCEDURE pr_enqueue(
        p_request_id              IN NUMBER,
        p_notification_event_type IN VARCHAR2,
        p_source_event            IN VARCHAR2
    ) IS
        v_audience  mnp_notification_types.audience%TYPE;
        v_msisdn    mnp_porting_requests.msisdn%TYPE;
        v_donor     mnp_porting_requests.donor_network_code%TYPE;
        v_recipient mnp_porting_requests.recipient_network_code%TYPE;
        v_payload   VARCHAR2(4000);
    BEGIN
        BEGIN
            SELECT audience INTO v_audience
              FROM mnp_notification_types
             WHERE event_type = p_notification_event_type;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20015,
                    'Unregistered notification event type: ' || p_notification_event_type);
        END;

        SELECT msisdn, donor_network_code, recipient_network_code
          INTO v_msisdn, v_donor, v_recipient
          FROM mnp_porting_requests
         WHERE id = p_request_id;

        v_payload := JSON_OBJECT(
            'requestId' VALUE p_request_id,
            'sourceEvent' VALUE p_source_event,
            'msisdn' VALUE v_msisdn,
            'donorNetworkCode' VALUE v_donor,
            'recipientNetworkCode' VALUE v_recipient
        );

        INSERT INTO mnp_outbox_events (aggregate_id, event_type, payload, audience)
        VALUES (p_request_id, p_notification_event_type, v_payload, v_audience);
    END pr_enqueue;

    PROCEDURE pr_claim_next_pending(p_cursor OUT SYS_REFCURSOR) IS
        v_id mnp_outbox_events.id%TYPE;
    BEGIN
        SELECT id INTO v_id
          FROM mnp_outbox_events
         WHERE status = 'PENDING'
           AND ROWNUM = 1
           FOR UPDATE SKIP LOCKED;

        UPDATE mnp_outbox_events
           SET status = 'CLAIMED', claimed_at = SYSTIMESTAMP
         WHERE id = v_id;

        OPEN p_cursor FOR
            SELECT id, event_type, audience, payload
              FROM mnp_outbox_events
             WHERE id = v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            OPEN p_cursor FOR
                SELECT id, event_type, audience, payload
                  FROM mnp_outbox_events
                 WHERE 1 = 0;
    END pr_claim_next_pending;

    PROCEDURE pr_mark_published(p_outbox_id IN NUMBER) IS
    BEGIN
        UPDATE mnp_outbox_events
           SET status = 'PUBLISHED', published_at = SYSTIMESTAMP
         WHERE id = p_outbox_id
           AND status = 'CLAIMED';
    END pr_mark_published;

    PROCEDURE pr_mark_failed(
        p_outbox_id IN NUMBER,
        p_error     IN VARCHAR2
    ) IS
        v_attempt_count mnp_outbox_events.attempt_count%TYPE;
        v_max_attempts  mnp_outbox_config.max_attempts%TYPE;
    BEGIN
        UPDATE mnp_outbox_events
           SET attempt_count = attempt_count + 1,
               last_error = p_error
         WHERE id = p_outbox_id
           AND status = 'CLAIMED';

        IF SQL%ROWCOUNT = 0 THEN
            RETURN; -- row wasn't CLAIMED (already moved on); nothing to do
        END IF;

        SELECT attempt_count INTO v_attempt_count FROM mnp_outbox_events WHERE id = p_outbox_id;
        SELECT max_attempts INTO v_max_attempts FROM mnp_outbox_config WHERE id = 1;

        UPDATE mnp_outbox_events
           SET status = CASE WHEN v_attempt_count >= v_max_attempts THEN 'DEAD_LETTER' ELSE 'PENDING' END
         WHERE id = p_outbox_id;
    END pr_mark_failed;

    PROCEDURE pr_list_recent(
        p_limit  IN NUMBER,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT id, aggregate_id, event_type, audience, status,
                   attempt_count, last_error, created_at, claimed_at, published_at
              FROM mnp_outbox_events
             ORDER BY created_at DESC
             FETCH FIRST p_limit ROWS ONLY;
    END pr_list_recent;

END pkg_outbox;
/
