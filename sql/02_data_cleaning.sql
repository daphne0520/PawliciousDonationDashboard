-- =====================================================================
-- 02_data_cleaning.sql
-- Purpose: Clean the two staging tables and split the ledger into its
--          two real components (donations vs. expenses), which were
--          mixed together in the original spreadsheet.
-- =====================================================================

USE donation_db;

-- ---------------------------------------------------------------------
-- STEP 1: Clean form responses
-- The last rows of the form export (row_id 51-62) are not real
-- individual donations -- they are a footer: a lump-sum note, a list of
-- volunteer names, a "total" line, and a "did not fill form" note.
-- We drop rows with no usable amount and cast the rest to proper types.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_form_responses;
CREATE TABLE clean_form_responses AS
SELECT
    row_id,
    CASE WHEN ts_raw = '' THEN NULL ELSE STR_TO_DATE(ts_raw, '%Y-%m-%d %H:%i:%s.%f') END AS donation_ts,
    donor_id,
    CAST(amount_raw AS DECIMAL(10,2)) AS amount_rm
FROM stg_form_responses
WHERE amount_raw REGEXP '^[0-9]+(\.[0-9]+)?$';   -- keeps only rows with a real numeric amount

-- ---------------------------------------------------------------------
-- STEP 2: Clean ledger -> DONATIONS
-- Keep only genuine transaction rows: bank transfer / TNG payments and
-- the ad-hoc "volunteer donation" entries further down the sheet.
-- Header rows, section labels, running BALANCE, and TOTAL rows are
-- computed/derived values, not raw transactions, so they are excluded.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_ledger_donations;
CREATE TABLE clean_ledger_donations AS
SELECT
    row_id,
    CASE
        WHEN col_a REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN STR_TO_DATE(col_a, '%Y-%m-%d %H:%i:%s')
        ELSE NULL
    END AS donation_ts,
    CASE
        WHEN col_b IN ('BANK TRANSFER', 'TNG') THEN col_b
        WHEN col_a = 'VOLUNTEER DONATION:' OR (col_a REGEXP '[0-9]{1,2} [A-Z]{3}$') THEN 'VOLUNTEER'
        ELSE 'OTHER'
    END AS payment_method,
    CAST(col_c AS DECIMAL(10,2)) AS amount_rm
FROM stg_ledger
WHERE
    -- real bank/TNG transactions
    (col_b IN ('BANK TRANSFER', 'TNG') AND col_c REGEXP '^[0-9]+(\.[0-9]+)?$')
    -- the single "OTHERS" lump-sum donation row
    OR (col_b = 'OTHERS' AND col_c REGEXP '^[0-9]+(\.[0-9]+)?$')
    -- volunteer donation entries (date-labelled, e.g. "21 JUN", 100.0)
    OR (col_a REGEXP '^[0-9]{1,2} [A-Z]{3}$' AND col_b REGEXP '^[0-9]+(\.[0-9]+)?$');

-- ---------------------------------------------------------------------
-- STEP 3: Clean ledger -> EXPENSES
-- Everything from the "DOG TREATMENT" section onward that has an
-- amount attached is an expense line, not a donation. TOTAL and
-- BALANCE rows are still excluded since they are running calculations.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clean_ledger_expenses;
CREATE TABLE clean_ledger_expenses AS
SELECT
    row_id,
    col_a AS expense_description,
    CAST(col_b AS DECIMAL(10,2)) AS amount_rm
FROM stg_ledger
WHERE row_id >= 61                                  -- expense section starts here
  AND col_b REGEXP '^[0-9]+(\.[0-9]+)?$'             -- has a real numeric amount
  AND col_a NOT IN ('TOTAL:', 'BALANCE:', 'BALANCE')  -- exclude running totals/balances
  AND col_a NOT LIKE 'TOTAL FEE%'
  AND col_a NOT LIKE 'BALANCE%'
  AND col_a NOT REGEXP '^[0-9]{1,2} [A-Z]{3}$';       -- exclude volunteer donation rows (e.g. "21 JUN"), which belong in donations, not expenses

-- Quick sanity checks
SELECT * FROM clean_form_responses ORDER BY row_id LIMIT 10;
SELECT * FROM clean_ledger_donations ORDER BY row_id LIMIT 10;
SELECT * FROM clean_ledger_expenses ORDER BY row_id LIMIT 10;
