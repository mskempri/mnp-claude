CREATE OR REPLACE PACKAGE BODY pkg_number_registry AS

    PROCEDURE pr_record_port_completed(p_request_id IN NUMBER) IS
        v_msisdn              mnp_porting_requests.msisdn%TYPE;
        v_recipient_network   mnp_porting_requests.recipient_network_code%TYPE;
    BEGIN
        SELECT msisdn, recipient_network_code
          INTO v_msisdn, v_recipient_network
          FROM mnp_porting_requests
         WHERE id = p_request_id;

        MERGE INTO mnp_number_ownership tgt
        USING (SELECT v_msisdn AS msisdn FROM dual) src
           ON (tgt.msisdn = src.msisdn)
        WHEN MATCHED THEN
            UPDATE SET current_network_code = v_recipient_network,
                       last_ported_at = SYSTIMESTAMP,
                       last_porting_request_id = p_request_id
        WHEN NOT MATCHED THEN
            INSERT (msisdn, current_network_code, last_ported_at, last_porting_request_id)
            VALUES (v_msisdn, v_recipient_network, SYSTIMESTAMP, p_request_id);
    END pr_record_port_completed;

    PROCEDURE pr_lookup(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT msisdn, current_network_code, last_ported_at, last_porting_request_id
              FROM mnp_number_ownership
             WHERE msisdn = p_msisdn;
    END pr_lookup;

END pkg_number_registry;
/
