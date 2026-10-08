-- 004_extend_porting_requests.sql
-- Adds the CUTOVER status, idempotency enforcement, and columns Phase C
-- (eligibility) will need. No PL/SQL in this phase reads pac_code/pac_issued_date.

ALTER TABLE mnp_porting_requests DROP CONSTRAINT ck_mpr_status;

ALTER TABLE mnp_porting_requests ADD CONSTRAINT ck_mpr_status CHECK (status IN (
    'RECEIVED', 'VALIDATING', 'APPROVED', 'REJECTED',
    'SCHEDULED', 'CUTOVER', 'COMPLETED', 'CANCELLED'
));

ALTER TABLE mnp_porting_requests ADD (
    pac_code         VARCHAR2(20),
    pac_issued_date  DATE
);

-- Enforces "no duplicate/concurrent open request per MSISDN" (services #2 and
-- #3 describe the same invariant from two angles; one mechanism backs both).
-- Oracle's idiom for a partial unique index: terminal-status rows evaluate to
-- NULL and are excluded from uniqueness, so exactly one non-terminal row per
-- MSISDN is enforced atomically by Oracle itself.
CREATE UNIQUE INDEX ux_mpr_msisdn_open ON mnp_porting_requests (
    CASE WHEN status NOT IN ('COMPLETED', 'REJECTED', 'CANCELLED') THEN msisdn END
);
