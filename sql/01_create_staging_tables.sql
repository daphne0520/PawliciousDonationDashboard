-- =====================================================================
-- 01_create_staging_tables.sql
-- Purpose: Create raw staging tables and load the two source exports
--          (Google Form responses + manual donation ledger) as-is,
--          with no cleaning applied yet.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS donation_db;
USE donation_db;

-- ---------------------------------------------------------------------
-- Raw Google Form donation responses (anonymized donor names -> donor_id)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg_form_responses;
CREATE TABLE stg_form_responses (
    row_id      INT,
    ts_raw      VARCHAR(50),    -- kept as text: source has blank/irregular values in footer rows
    donor_id    VARCHAR(50),
    amount_raw  VARCHAR(50)     -- kept as text: source has blank values in footer rows
);

LOAD DATA LOCAL INFILE 'responses_anonymized.csv'
INTO TABLE stg_form_responses
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(row_id, ts_raw, donor_id, amount_raw);

-- ---------------------------------------------------------------------
-- Raw donation + expense ledger (manually kept spreadsheet, exported as-is)
-- Columns are generic because the sheet mixes several different sections:
-- transaction log, running totals/balances, and expense notes.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg_ledger;
CREATE TABLE stg_ledger (
    row_id  INT,
    col_a   VARCHAR(255),   -- date, section label, or expense description
    col_b   VARCHAR(255),   -- payment method, amount, or expense description
    col_c   VARCHAR(255),   -- amount (RM) or blank
    col_d   VARCHAR(255)    -- memo, usually blank
);

LOAD DATA LOCAL INFILE 'donations_ledger.csv'
INTO TABLE stg_ledger
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(row_id, col_a, col_b, col_c, col_d);

-- Quick sanity checks
SELECT COUNT(*) AS form_response_rows FROM stg_form_responses;
SELECT COUNT(*) AS ledger_rows FROM stg_ledger;
