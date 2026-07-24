-- =====================================================================
-- 03_final_table_creation.sql
-- Purpose: Build the final tables that feed the Power BI model:
--          dim_donors, fct_donations, fct_expenses.
--
-- Note on overlap: the Google Form responses and the "BANK TRANSFER"
-- rows in the ledger record the SAME individual donations (they match
-- 1-to-1 on timestamp + amount). To avoid double-counting, donor-level
-- detail comes from the form responses, and only the ledger entries
-- that do NOT exist in the form (TNG payments, the one-off "OTHERS"
-- lump sum, and later volunteer donations) are added on top.
-- =====================================================================

USE donation_db;

-- ---------------------------------------------------------------------
-- Dimension: donors (one row per donor who filled the form)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_donors;
CREATE TABLE dim_donors AS
SELECT DISTINCT donor_id
FROM clean_form_responses;

-- ---------------------------------------------------------------------
-- Fact: donations
-- Combines form-attributed donations with ledger-only donations
-- (anonymous TNG/cash payments, lump sums, volunteer contributions).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS fct_donations;
CREATE TABLE fct_donations AS
SELECT
    row_id,
    donation_ts,
    donor_id,
    amount_rm,
    'FORM'   AS source,
    'BANK TRANSFER / TNG (attributed)' AS payment_method
FROM clean_form_responses

UNION ALL

SELECT
    row_id,
    donation_ts,
    NULL AS donor_id,
    amount_rm,
    'LEDGER' AS source,
    payment_method
FROM clean_ledger_donations
WHERE payment_method IN ('TNG', 'OTHER', 'VOLUNTEER');
-- 'BANK TRANSFER' rows deliberately excluded here: already captured via FORM above

-- ---------------------------------------------------------------------
-- Fact: expenses
-- Categorized where the sheet's section headers make it clear
-- (e.g. named dog / treatment case). Rows without a clear section are
-- left as 'Uncategorized' -- extend this CASE statement as more
-- records / dog cases are added to the ledger.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS fct_expenses;
CREATE TABLE fct_expenses AS
SELECT
    row_id,
    expense_description,
    amount_rm,
    CASE
        WHEN row_id BETWEEN 61  AND 89  THEN 'General Treatment & Logistics'
        WHEN row_id = 116               THEN 'Food & Snacks'
        WHEN row_id BETWEEN 140 AND 147 THEN 'Riley'
        WHEN row_id BETWEEN 149 AND 151 THEN 'Xiaopao'
        WHEN row_id BETWEEN 161 AND 163 THEN 'Riley (Shelter)'
        ELSE 'Uncategorized'
    END AS treatment_category
FROM clean_ledger_expenses;

-- ---------------------------------------------------------------------
-- Quick KPI checks (same numbers the Power BI cards should show)
-- ---------------------------------------------------------------------
SELECT SUM(amount_rm) AS total_donations FROM fct_donations;
SELECT COUNT(DISTINCT donor_id) AS total_donors FROM fct_donations WHERE donor_id IS NOT NULL;
SELECT ROUND(AVG(amount_rm), 2) AS avg_donation FROM fct_donations;
SELECT SUM(amount_rm) AS total_expenses FROM fct_expenses;
SELECT treatment_category, SUM(amount_rm) AS total_spent
FROM fct_expenses
GROUP BY treatment_category
ORDER BY total_spent DESC;
