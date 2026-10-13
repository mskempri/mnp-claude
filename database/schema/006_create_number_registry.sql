-- 006_create_number_registry.sql
-- Phase D: Number/Routing Lookup service backing table.
--
-- One row per MSISDN that has completed at least one port through this
-- system - absence of a row means "not tracked", not "no owner". There is
-- no national numbering-plan range-to-operator dataset backing this (that
-- would be inventing authoritative data this project has deliberately
-- declined to guess at elsewhere - see the Greek holiday calendar and timer
-- durations), so a never-ported MSISDN has no answer here at all.
CREATE TABLE mnp_number_ownership (
    msisdn                  VARCHAR2(20) PRIMARY KEY,
    current_network_code    VARCHAR2(10) NOT NULL,
    last_ported_at          TIMESTAMP WITH TIME ZONE NOT NULL,
    last_porting_request_id NUMBER REFERENCES mnp_porting_requests (id)
);

COMMENT ON TABLE mnp_number_ownership IS
    'Current network owner per MSISDN, as last recorded by a completed port through this system. Populated by PKG_NUMBER_REGISTRY via the workflow engine''s RECORD_NUMBER_OWNERSHIP action on CUTOVER/CUTOVER_COMPLETE - not consulted by FN_CREATE_REQUEST (deliberately, see PHASES.md Phase D).';
