CREATE DATABASE IF NOT EXISTS donation_db;
USE donation_db;

CREATE TABLE stg_form_responses (
  row_id INT,
  col_a  VARCHAR(255),
  col_b  VARCHAR(255),
  col_c  VARCHAR(255),
  col_d  VARCHAR(255),
  col_e  VARCHAR(255),
  col_f  VARCHAR(500)
);

CREATE TABLE stg_ledger (
  row_id INT,
  col_a  VARCHAR(255),
  col_b  VARCHAR(255),
  col_c  VARCHAR(255),
  col_d  VARCHAR(255)
);
