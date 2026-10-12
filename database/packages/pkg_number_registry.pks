CREATE OR REPLACE PACKAGE pkg_number_registry AS
    -- Number/Routing Lookup service. Owns MNP_NUMBER_OWNERSHIP - a registry
    -- of "who currently owns this MSISDN", populated only from ports
    -- completed inside this system (see schema/006 for why it can't be
    -- more than that). Read-only from .NET's perspective; writes only ever
    -- happen via PR_RECORD_PORT_COMPLETED, called by PKG_WORKFLOW_ENGINE.

    PROCEDURE pr_record_port_completed(p_request_id IN NUMBER);

    -- Returns 0 or 1 rows: msisdn, current_network_code, last_ported_at,
    -- last_porting_request_id. No row is a valid "not tracked" answer, not
    -- an error - callers should not expect this to raise on a miss.
    PROCEDURE pr_lookup(
        p_msisdn IN  VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    );

END pkg_number_registry;
/
