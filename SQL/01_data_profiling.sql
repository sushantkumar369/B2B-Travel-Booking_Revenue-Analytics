-- ============================================================
-- PROJECT 2: B2B TRAVEL BOOKING & REVENUE ANALYTICS
-- PHASE 1: RAW DATA LOAD + DATA QUALITY PROFILING
-- Database: PostgreSQL
-- ============================================================
-- Industry principle:
-- Load raw files first. Do NOT silently clean data during ingestion.
-- Dates and measures are stored as TEXT in the raw layer so malformed
-- source values remain visible for profiling and auditability.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;

DROP TABLE IF EXISTS raw.payments;
DROP TABLE IF EXISTS raw.cancellations;
DROP TABLE IF EXISTS raw.bookings;
DROP TABLE IF EXISTS raw.travel_agents;
DROP TABLE IF EXISTS raw.hotels;
DROP TABLE IF EXISTS raw.suppliers;
DROP TABLE IF EXISTS raw.destinations;

CREATE TABLE raw.bookings (
    booking_id            TEXT,
    booking_date          TEXT,
    travel_date           TEXT,
    agent_id              TEXT,
    hotel_id              TEXT,
    supplier_id           TEXT,
    destination_id        TEXT,
    rooms                  TEXT,
    nights                 TEXT,
    guests                 TEXT,
    booking_status         TEXT,
    currency               TEXT,
    gross_booking_value    TEXT,
    supplier_cost          TEXT,
    discount_amount        TEXT,
    tax_amount             TEXT,
    payment_status         TEXT
);

CREATE TABLE raw.travel_agents (
    agent_id               TEXT,
    agent_name             TEXT,
    country                TEXT,
    city                   TEXT,
    registration_date      TEXT,
    agent_type             TEXT,
    sales_region           TEXT,
    account_manager        TEXT
);

CREATE TABLE raw.hotels (
    hotel_id               TEXT,
    hotel_name             TEXT,
    destination_id         TEXT,
    star_rating            TEXT,
    hotel_category         TEXT,
    chain_name             TEXT,
    active_flag            TEXT
);

CREATE TABLE raw.suppliers (
    supplier_id            TEXT,
    supplier_name          TEXT,
    supplier_country       TEXT,
    supplier_type          TEXT,
    contract_type          TEXT,
    commission_rate        TEXT
);

CREATE TABLE raw.destinations (
    destination_id         TEXT,
    city                   TEXT,
    country                TEXT,
    region                 TEXT,
    destination_type       TEXT
);

CREATE TABLE raw.cancellations (
    cancellation_id        TEXT,
    booking_id             TEXT,
    cancellation_date      TEXT,
    cancellation_reason    TEXT,
    refund_amount          TEXT,
    cancellation_fee       TEXT,
    cancelled_by           TEXT
);

CREATE TABLE raw.payments (
    payment_id             TEXT,
    booking_id             TEXT,
    payment_date           TEXT,
    payment_method         TEXT,
    amount                 TEXT,
    payment_status         TEXT
);

-- ============================================================
-- LOAD THE CSV FILES
-- ============================================================
-- Recommended in pgAdmin:
-- Right-click each table > Import/Export Data > Import
-- Format = CSV, Header = Yes, Delimiter = comma, Encoding = UTF8
--
-- If using psql, replace the paths below and uncomment.
--
-- \copy raw.bookings FROM 'C:/YOUR_PATH/bookings.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy raw.travel_agents FROM 'C:/YOUR_PATH/travel_agents.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy raw.hotels FROM 'C:/YOUR_PATH/hotels.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy raw.suppliers FROM 'C:/YOUR_PATH/suppliers.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy raw.destinations FROM 'C:/YOUR_PATH/destinations.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy raw.cancellations FROM 'C:/YOUR_PATH/cancellations.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy raw.payments FROM 'C:/YOUR_PATH/payments.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');


-- ============================================================
-- A. TABLE SIZE / GRAIN CHECK
-- ============================================================

SELECT 'bookings' AS table_name, COUNT(*) AS row_count FROM raw.bookings
UNION ALL
SELECT 'travel_agents', COUNT(*) FROM raw.travel_agents
UNION ALL
SELECT 'hotels', COUNT(*) FROM raw.hotels
UNION ALL
SELECT 'suppliers', COUNT(*) FROM raw.suppliers
UNION ALL
SELECT 'destinations', COUNT(*) FROM raw.destinations
UNION ALL
SELECT 'cancellations', COUNT(*) FROM raw.cancellations
UNION ALL
SELECT 'payments', COUNT(*) FROM raw.payments
ORDER BY table_name;


-- ============================================================
-- B. PRIMARY KEY UNIQUENESS
-- ============================================================

SELECT
    'bookings.booking_id' AS key_name,
    COUNT(*) AS rows,
    COUNT(DISTINCT booking_id) AS distinct_keys,
    COUNT(*) - COUNT(DISTINCT booking_id) AS duplicate_key_rows
FROM raw.bookings
UNION ALL
SELECT 'travel_agents.agent_id', COUNT(*), COUNT(DISTINCT agent_id),
       COUNT(*) - COUNT(DISTINCT agent_id)
FROM raw.travel_agents
UNION ALL
SELECT 'hotels.hotel_id', COUNT(*), COUNT(DISTINCT hotel_id),
       COUNT(*) - COUNT(DISTINCT hotel_id)
FROM raw.hotels
UNION ALL
SELECT 'suppliers.supplier_id', COUNT(*), COUNT(DISTINCT supplier_id),
       COUNT(*) - COUNT(DISTINCT supplier_id)
FROM raw.suppliers
UNION ALL
SELECT 'destinations.destination_id', COUNT(*), COUNT(DISTINCT destination_id),
       COUNT(*) - COUNT(DISTINCT destination_id)
FROM raw.destinations
UNION ALL
SELECT 'cancellations.cancellation_id', COUNT(*), COUNT(DISTINCT cancellation_id),
       COUNT(*) - COUNT(DISTINCT cancellation_id)
FROM raw.cancellations
UNION ALL
SELECT 'payments.payment_id', COUNT(*), COUNT(DISTINCT payment_id),
       COUNT(*) - COUNT(DISTINCT payment_id)
FROM raw.payments;


-- ============================================================
-- C. DUPLICATE BOOKING IDS
-- ============================================================

SELECT
    booking_id,
    COUNT(*) AS row_count
FROM raw.bookings
GROUP BY booking_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC, booking_id;


-- ============================================================
-- D. NULL / BLANK PROFILING - BOOKINGS
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(booking_id), '') IS NULL) AS booking_id_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(booking_date), '') IS NULL) AS booking_date_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(travel_date), '') IS NULL) AS travel_date_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(agent_id), '') IS NULL) AS agent_id_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(hotel_id), '') IS NULL) AS hotel_id_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(supplier_id), '') IS NULL) AS supplier_id_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(destination_id), '') IS NULL) AS destination_id_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(gross_booking_value), '') IS NULL) AS gbv_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(booking_status), '') IS NULL) AS status_missing,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(payment_status), '') IS NULL) AS payment_status_missing
FROM raw.bookings;


-- ============================================================
-- E. DATE FORMAT PROFILING
-- ============================================================

SELECT
    CASE
        WHEN booking_date ~ '^\d{4}-\d{2}-\d{2}$' THEN 'YYYY-MM-DD'
        WHEN booking_date ~ '^\d{2}/\d{2}/\d{4}$' THEN 'DD/MM/YYYY'
        WHEN NULLIF(TRIM(booking_date), '') IS NULL THEN 'NULL/BLANK'
        ELSE 'OTHER/INVALID'
    END AS booking_date_pattern,
    COUNT(*) AS rows
FROM raw.bookings
GROUP BY 1
ORDER BY rows DESC;

SELECT
    CASE
        WHEN travel_date ~ '^\d{4}-\d{2}-\d{2}$' THEN 'YYYY-MM-DD'
        WHEN travel_date ~ '^\d{2}/\d{2}/\d{4}$' THEN 'DD/MM/YYYY'
        WHEN NULLIF(TRIM(travel_date), '') IS NULL THEN 'NULL/BLANK'
        ELSE 'OTHER/INVALID'
    END AS travel_date_pattern,
    COUNT(*) AS rows
FROM raw.bookings
GROUP BY 1
ORDER BY rows DESC;


-- ============================================================
-- F. SAFE DATE PARSING + LOGICAL DATE CHECKS
-- ============================================================

WITH parsed AS (
    SELECT
        booking_id,
        CASE
            WHEN booking_date ~ '^\d{4}-\d{2}-\d{2}$' THEN booking_date::date
            WHEN booking_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(booking_date, 'DD/MM/YYYY')
            ELSE NULL
        END AS booking_dt,
        CASE
            WHEN travel_date ~ '^\d{4}-\d{2}-\d{2}$' THEN travel_date::date
            WHEN travel_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(travel_date, 'DD/MM/YYYY')
            ELSE NULL
        END AS travel_dt
    FROM raw.bookings
)
SELECT
    COUNT(*) FILTER (WHERE booking_dt IS NULL) AS unparseable_booking_dates,
    COUNT(*) FILTER (WHERE travel_dt IS NULL) AS unparseable_travel_dates,
    COUNT(*) FILTER (
        WHERE booking_dt IS NOT NULL
          AND travel_dt IS NOT NULL
          AND travel_dt < booking_dt
    ) AS travel_before_booking,
    MIN(booking_dt) AS min_booking_date,
    MAX(booking_dt) AS max_booking_date,
    MIN(travel_dt) AS min_travel_date,
    MAX(travel_dt) AS max_travel_date
FROM parsed;


-- ============================================================
-- G. NUMERIC / BUSINESS-RULE PROFILING
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE rooms !~ '^-?\d+(\.\d+)?$'
           OR NULLIF(TRIM(rooms), '') IS NULL
    ) AS rooms_non_numeric,
    COUNT(*) FILTER (
        WHERE rooms ~ '^-?\d+(\.\d+)?$'
          AND rooms::numeric <= 0
    ) AS rooms_non_positive,

    COUNT(*) FILTER (
        WHERE nights !~ '^-?\d+(\.\d+)?$'
           OR NULLIF(TRIM(nights), '') IS NULL
    ) AS nights_non_numeric,
    COUNT(*) FILTER (
        WHERE nights ~ '^-?\d+(\.\d+)?$'
          AND nights::numeric <= 0
    ) AS nights_non_positive,

    COUNT(*) FILTER (
        WHERE gross_booking_value !~ '^-?\d+(\.\d+)?$'
           OR NULLIF(TRIM(gross_booking_value), '') IS NULL
    ) AS gbv_non_numeric,
    COUNT(*) FILTER (
        WHERE gross_booking_value ~ '^-?\d+(\.\d+)?$'
          AND gross_booking_value::numeric <= 0
    ) AS gbv_non_positive,

    COUNT(*) FILTER (
        WHERE supplier_cost ~ '^-?\d+(\.\d+)?$'
          AND gross_booking_value ~ '^-?\d+(\.\d+)?$'
          AND supplier_cost::numeric > gross_booking_value::numeric
    ) AS supplier_cost_gt_gbv
FROM raw.bookings;


-- ============================================================
-- H. CATEGORY CONSISTENCY
-- ============================================================

SELECT booking_status, COUNT(*) AS rows
FROM raw.bookings
GROUP BY booking_status
ORDER BY rows DESC;

SELECT payment_status, COUNT(*) AS rows
FROM raw.bookings
GROUP BY payment_status
ORDER BY rows DESC;

SELECT currency, COUNT(*) AS rows
FROM raw.bookings
GROUP BY currency
ORDER BY rows DESC;

SELECT country, COUNT(*) AS rows
FROM raw.travel_agents
GROUP BY country
ORDER BY LOWER(country), country;

SELECT country, COUNT(*) AS rows
FROM raw.destinations
GROUP BY country
ORDER BY LOWER(country), country;


-- ============================================================
-- I. FOREIGN KEY INTEGRITY
-- ============================================================

SELECT
    COUNT(*) FILTER (WHERE a.agent_id IS NULL) AS missing_agent_keys,
    COUNT(*) FILTER (WHERE h.hotel_id IS NULL) AS missing_hotel_keys,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(b.supplier_id), '') IS NOT NULL
          AND s.supplier_id IS NULL
    ) AS invalid_supplier_keys,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(b.supplier_id), '') IS NULL
    ) AS blank_supplier_keys,
    COUNT(*) FILTER (WHERE d.destination_id IS NULL) AS invalid_destination_keys
FROM raw.bookings b
LEFT JOIN raw.travel_agents a
    ON b.agent_id = a.agent_id
LEFT JOIN raw.hotels h
    ON b.hotel_id = h.hotel_id
LEFT JOIN raw.suppliers s
    ON b.supplier_id = s.supplier_id
LEFT JOIN raw.destinations d
    ON b.destination_id = d.destination_id;


-- Hotel -> destination integrity
SELECT COUNT(*) AS hotels_with_invalid_destination
FROM raw.hotels h
LEFT JOIN raw.destinations d
    ON h.destination_id = d.destination_id
WHERE d.destination_id IS NULL;


-- Cancellation -> booking integrity
SELECT COUNT(*) AS orphan_cancellations
FROM raw.cancellations c
LEFT JOIN raw.bookings b
    ON c.booking_id = b.booking_id
WHERE b.booking_id IS NULL;


-- Payment -> booking integrity
SELECT COUNT(*) AS orphan_payments
FROM raw.payments p
LEFT JOIN raw.bookings b
    ON p.booking_id = b.booking_id
WHERE b.booking_id IS NULL;


-- ============================================================
-- J. BOOKING / CANCELLATION CONSISTENCY
-- ============================================================

-- Cancelled bookings with no cancellation record
SELECT COUNT(*) AS cancelled_without_cancellation_record
FROM raw.bookings b
LEFT JOIN raw.cancellations c
    ON b.booking_id = c.booking_id
WHERE b.booking_status = 'Cancelled'
  AND c.booking_id IS NULL;

-- Cancellation records whose booking isn't marked Cancelled
SELECT COUNT(*) AS cancellation_record_but_booking_not_cancelled
FROM raw.cancellations c
JOIN raw.bookings b
    ON c.booking_id = b.booking_id
WHERE b.booking_status <> 'Cancelled';

-- Cancelled bookings still marked Paid in bookings
SELECT COUNT(*) AS cancelled_but_paid
FROM raw.bookings
WHERE booking_status = 'Cancelled'
  AND payment_status = 'Paid';


-- ============================================================
-- K. REFUND / PAYMENT CONSISTENCY
-- ============================================================

SELECT
    p.payment_status,
    COUNT(*) AS payment_rows,
    ROUND(SUM(
        CASE WHEN p.amount ~ '^-?\d+(\.\d+)?$' THEN p.amount::numeric ELSE 0 END
    ), 2) AS total_amount
FROM raw.payments p
GROUP BY p.payment_status
ORDER BY payment_rows DESC;

-- Multiple payment rows per booking are legitimate in this model,
-- but identify them so analysts do not accidentally double-count GBV.
SELECT
    booking_id,
    COUNT(*) AS payment_rows,
    SUM(CASE WHEN amount ~ '^-?\d+(\.\d+)?$' THEN amount::numeric ELSE 0 END) AS payment_amount_sum
FROM raw.payments
GROUP BY booking_id
HAVING COUNT(*) > 1
ORDER BY payment_rows DESC, payment_amount_sum DESC
LIMIT 100;


-- ============================================================
-- L. HOTEL DATA QUALITY
-- ============================================================

SELECT
    COUNT(*) AS total_hotels,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(star_rating), '') IS NULL) AS missing_star_rating,
    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(star_rating), '') IS NOT NULL
          AND star_rating !~ '^\d+(\.\d+)?$'
    ) AS non_numeric_star_rating
FROM raw.hotels;


-- ============================================================
-- M. CONSOLIDATED DATA QUALITY ISSUE SUMMARY
-- ============================================================

WITH parsed AS (
    SELECT
        *,
        CASE
            WHEN booking_date ~ '^\d{4}-\d{2}-\d{2}$' THEN booking_date::date
            WHEN booking_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(booking_date, 'DD/MM/YYYY')
            ELSE NULL
        END AS booking_dt,
        CASE
            WHEN travel_date ~ '^\d{4}-\d{2}-\d{2}$' THEN travel_date::date
            WHEN travel_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(travel_date, 'DD/MM/YYYY')
            ELSE NULL
        END AS travel_dt
    FROM raw.bookings
),
dupes AS (
    SELECT booking_id
    FROM raw.bookings
    GROUP BY booking_id
    HAVING COUNT(*) > 1
)
SELECT 'Duplicate booking IDs' AS issue, COUNT(*)::bigint AS affected_rows
FROM raw.bookings b
JOIN dupes d USING (booking_id)

UNION ALL
SELECT 'Blank supplier_id', COUNT(*)::bigint
FROM raw.bookings
WHERE NULLIF(TRIM(supplier_id), '') IS NULL

UNION ALL
SELECT 'Travel date before booking date', COUNT(*)::bigint
FROM parsed
WHERE booking_dt IS NOT NULL
  AND travel_dt IS NOT NULL
  AND travel_dt < booking_dt

UNION ALL
SELECT 'Non-positive rooms', COUNT(*)::bigint
FROM raw.bookings
WHERE rooms ~ '^-?\d+(\.\d+)?$'
  AND rooms::numeric <= 0

UNION ALL
SELECT 'Non-positive nights', COUNT(*)::bigint
FROM raw.bookings
WHERE nights ~ '^-?\d+(\.\d+)?$'
  AND nights::numeric <= 0

UNION ALL
SELECT 'Non-positive GBV', COUNT(*)::bigint
FROM raw.bookings
WHERE gross_booking_value ~ '^-?\d+(\.\d+)?$'
  AND gross_booking_value::numeric <= 0

UNION ALL
SELECT 'Cancelled but booking payment_status = Paid', COUNT(*)::bigint
FROM raw.bookings
WHERE booking_status = 'Cancelled'
  AND payment_status = 'Paid'

UNION ALL
SELECT 'Orphan cancellations', COUNT(*)::bigint
FROM raw.cancellations c
LEFT JOIN raw.bookings b
  ON c.booking_id = b.booking_id
WHERE b.booking_id IS NULL

UNION ALL
SELECT 'Missing hotel star rating', COUNT(*)::bigint
FROM raw.hotels
WHERE NULLIF(TRIM(star_rating), '') IS NULL
ORDER BY issue;


-- ============================================================
-- N. YOUR ANALYST NOTES
-- ============================================================
-- After running this script, document:
--
-- 1. Table grain for every table.
-- 2. Primary-key issues.
-- 3. Null / blank issues.
-- 4. Invalid date issues.
-- 5. Invalid numeric / logical-value issues.
-- 6. Referential-integrity issues.
-- 7. Categorical-standardization issues.
-- 8. Booking / cancellation / payment consistency issues.
-- 9. Which issues should be:
--      a) corrected,
--      b) standardized,
--      c) excluded,
--      d) escalated to source-system owners.
--
-- Do NOT delete or overwrite raw data.
-- The next phase will create:
--   staging -> clean -> analytics layers
-- ============================================================
