-- 001_create_porting_requests_table.sql
-- Core table backing the mobile number portability workflow.

CREATE TABLE mnp_porting_requests (
    id                      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    msisdn                  VARCHAR2(20)  NOT NULL,
    donor_network_code      VARCHAR2(10)  NOT NULL,
    recipient_network_code  VARCHAR2(10)  NOT NULL,
    status                  VARCHAR2(20)  NOT NULL,
    requested_porting_date  DATE          NOT NULL,
    rejection_reason        VARCHAR2(500),
    created_at              TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at              TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_mpr_status CHECK (status IN (
        'RECEIVED', 'VALIDATING', 'APPROVED', 'REJECTED',
        'SCHEDULED', 'COMPLETED', 'CANCELLED'
    )),
    CONSTRAINT ck_mpr_networks_differ CHECK (donor_network_code <> recipient_network_code)
);

CREATE INDEX ix_mpr_msisdn ON mnp_porting_requests (msisdn);

COMMENT ON TABLE mnp_porting_requests IS
    'One row per number-porting request. Owned by PKG_PORTING_REQUESTS - do not write to it from application code directly.';
