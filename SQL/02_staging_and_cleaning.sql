-- ============================================================
-- PROJECT 2: B2B TRAVEL BOOKING & REVENUE ANALYTICS
-- PHASE 2: STAGING + CLEAN DATA LAYERS
-- Database: PostgreSQL
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS clean;

-- ------------------------------------------------------------
-- 1. STANDARDIZE / TYPE BOOKINGS IN STAGING
-- ------------------------------------------------------------

DROP TABLE IF EXISTS staging.bookings_typed;

CREATE TABLE staging.bookings_typed AS
WITH base AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY booking_id
            ORDER BY ctid
        ) AS duplicate_rank
    FROM raw.bookings
)
SELECT
    booking_id,

    CASE
        WHEN booking_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN booking_date::date
        WHEN booking_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(booking_date, 'DD/MM/YYYY')
        ELSE NULL
    END AS booking_date,

    CASE
        WHEN travel_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN travel_date::date
        WHEN travel_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(travel_date, 'DD/MM/YYYY')
        ELSE NULL
    END AS travel_date,

    NULLIF(TRIM(agent_id), '') AS agent_id,
    NULLIF(TRIM(hotel_id), '') AS hotel_id,
    NULLIF(TRIM(supplier_id), '') AS supplier_id,
    NULLIF(TRIM(destination_id), '') AS destination_id,

    CASE WHEN rooms ~ '^-?\d+(\.\d+)?$' THEN rooms::numeric END AS rooms,
    CASE WHEN nights ~ '^-?\d+(\.\d+)?$' THEN nights::numeric END AS nights,
    CASE WHEN guests ~ '^-?\d+(\.\d+)?$' THEN guests::numeric END AS guests,

    INITCAP(TRIM(booking_status)) AS booking_status,
    UPPER(TRIM(currency)) AS currency,

    CASE WHEN gross_booking_value ~ '^-?\d+(\.\d+)?$'
         THEN gross_booking_value::numeric END AS gross_booking_value,

    CASE WHEN supplier_cost ~ '^-?\d+(\.\d+)?$'
         THEN supplier_cost::numeric END AS supplier_cost,

    CASE WHEN discount_amount ~ '^-?\d+(\.\d+)?$'
         THEN discount_amount::numeric END AS discount_amount,

    CASE WHEN tax_amount ~ '^-?\d+(\.\d+)?$'
         THEN tax_amount::numeric END AS tax_amount,

    INITCAP(TRIM(payment_status)) AS payment_status,
    duplicate_rank,

    -- Data quality flags
    CASE WHEN duplicate_rank > 1 THEN 1 ELSE 0 END AS is_duplicate,
    CASE WHEN NULLIF(TRIM(supplier_id), '') IS NULL THEN 1 ELSE 0 END AS is_supplier_missing,
    CASE WHEN rooms ~ '^-?\d+(\.\d+)?$' AND rooms::numeric <= 0 THEN 1 ELSE 0 END AS is_rooms_invalid,
    CASE WHEN nights ~ '^-?\d+(\.\d+)?$' AND nights::numeric <= 0 THEN 1 ELSE 0 END AS is_nights_invalid,
    CASE WHEN gross_booking_value ~ '^-?\d+(\.\d+)?$'
              AND gross_booking_value::numeric <= 0 THEN 1 ELSE 0 END AS is_gbv_invalid,

    CASE
        WHEN
            (
                CASE
                    WHEN booking_date ~ '^\d{4}-\d{2}-\d{2}$' THEN booking_date::date
                    WHEN booking_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(booking_date, 'DD/MM/YYYY')
                END
            ) IS NOT NULL
            AND
            (
                CASE
                    WHEN travel_date ~ '^\d{4}-\d{2}-\d{2}$' THEN travel_date::date
                    WHEN travel_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(travel_date, 'DD/MM/YYYY')
                END
            ) IS NOT NULL
            AND
            (
                CASE
                    WHEN travel_date ~ '^\d{4}-\d{2}-\d{2}$' THEN travel_date::date
                    WHEN travel_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(travel_date, 'DD/MM/YYYY')
                END
            ) <
            (
                CASE
                    WHEN booking_date ~ '^\d{4}-\d{2}-\d{2}$' THEN booking_date::date
                    WHEN booking_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(booking_date, 'DD/MM/YYYY')
                END
            )
        THEN 1 ELSE 0
    END AS is_date_invalid

FROM base;


-- ------------------------------------------------------------
-- 2. STANDARDIZE AGENTS
-- ------------------------------------------------------------

DROP TABLE IF EXISTS staging.travel_agents_std;

CREATE TABLE staging.travel_agents_std AS
SELECT
    agent_id,
    INITCAP(TRIM(agent_name)) AS agent_name,

    CASE
        WHEN UPPER(TRIM(country)) IN ('UAE','U.A.E.','UNITED ARAB EMIRATES')
            THEN 'United Arab Emirates'
        WHEN UPPER(TRIM(country)) = 'INDIA'
            THEN 'India'
        WHEN UPPER(TRIM(country)) = 'UNITED KINGDOM'
            THEN 'United Kingdom'
        WHEN UPPER(TRIM(country)) = 'UNITED STATES'
            THEN 'United States'
        ELSE INITCAP(TRIM(country))
    END AS country,

    INITCAP(TRIM(city)) AS city,
    registration_date::date AS registration_date,
    INITCAP(TRIM(agent_type)) AS agent_type,
    TRIM(sales_region) AS sales_region,
    TRIM(account_manager) AS account_manager
FROM raw.travel_agents;


-- ------------------------------------------------------------
-- 3. STANDARDIZE DESTINATIONS
-- ------------------------------------------------------------

DROP TABLE IF EXISTS staging.destinations_std;

CREATE TABLE staging.destinations_std AS
SELECT
    destination_id,
    INITCAP(TRIM(city)) AS city,

    CASE
        WHEN UPPER(TRIM(country)) IN ('UAE','U.A.E.','UNITED ARAB EMIRATES')
            THEN 'United Arab Emirates'
        WHEN UPPER(TRIM(country)) = 'INDIA'
            THEN 'India'
        WHEN UPPER(TRIM(country)) = 'UNITED KINGDOM'
            THEN 'United Kingdom'
        WHEN UPPER(TRIM(country)) = 'UNITED STATES'
            THEN 'United States'
        ELSE INITCAP(TRIM(country))
    END AS country,

    TRIM(region) AS region,
    INITCAP(TRIM(destination_type)) AS destination_type
FROM raw.destinations;


-- ------------------------------------------------------------
-- 4. TYPE / STANDARDIZE HOTELS
-- ------------------------------------------------------------

DROP TABLE IF EXISTS staging.hotels_std;

CREATE TABLE staging.hotels_std AS
SELECT
    hotel_id,
    TRIM(hotel_name) AS hotel_name,
    destination_id,
    CASE WHEN star_rating ~ '^\d+(\.\d+)?$'
         THEN star_rating::numeric END AS star_rating,
    INITCAP(TRIM(hotel_category)) AS hotel_category,
    TRIM(chain_name) AS chain_name,
    UPPER(TRIM(active_flag)) AS active_flag
FROM raw.hotels;


-- ------------------------------------------------------------
-- 5. TYPE / STANDARDIZE SUPPLIERS
-- ------------------------------------------------------------

DROP TABLE IF EXISTS staging.suppliers_std;

CREATE TABLE staging.suppliers_std AS
SELECT
    supplier_id,
    TRIM(supplier_name) AS supplier_name,
    INITCAP(TRIM(supplier_country)) AS supplier_country,
    INITCAP(TRIM(supplier_type)) AS supplier_type,
    INITCAP(TRIM(contract_type)) AS contract_type,
    CASE WHEN commission_rate ~ '^-?\d+(\.\d+)?$'
         THEN commission_rate::numeric END AS commission_rate
FROM raw.suppliers;


-- ------------------------------------------------------------
-- 6. TYPE CANCELLATIONS
-- ------------------------------------------------------------

DROP TABLE IF EXISTS staging.cancellations_typed;

CREATE TABLE staging.cancellations_typed AS
SELECT
    cancellation_id,
    booking_id,
    CASE
        WHEN cancellation_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN cancellation_date::date
        WHEN cancellation_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(cancellation_date, 'DD/MM/YYYY')
        ELSE NULL
    END AS cancellation_date,
    INITCAP(TRIM(cancellation_reason)) AS cancellation_reason,
    CASE WHEN refund_amount ~ '^-?\d+(\.\d+)?$'
         THEN refund_amount::numeric END AS refund_amount,
    CASE WHEN cancellation_fee ~ '^-?\d+(\.\d+)?$'
         THEN cancellation_fee::numeric END AS cancellation_fee,
    INITCAP(TRIM(cancelled_by)) AS cancelled_by
FROM raw.cancellations;


-- ------------------------------------------------------------
-- 7. TYPE PAYMENTS
-- ------------------------------------------------------------

DROP TABLE IF EXISTS staging.payments_typed;

CREATE TABLE staging.payments_typed AS
SELECT
    payment_id,
    booking_id,
    CASE
        WHEN payment_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN payment_date::date
        WHEN payment_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(payment_date, 'DD/MM/YYYY')
        ELSE NULL
    END AS payment_date,
    INITCAP(TRIM(payment_method)) AS payment_method,
    CASE WHEN amount ~ '^-?\d+(\.\d+)?$'
         THEN amount::numeric END AS amount,
    INITCAP(TRIM(payment_status)) AS payment_status
FROM raw.payments;


-- ------------------------------------------------------------
-- 8. CREATE CLEAN DIMENSIONS
-- ------------------------------------------------------------

DROP TABLE IF EXISTS clean.dim_agents;
CREATE TABLE clean.dim_agents AS
SELECT DISTINCT *
FROM staging.travel_agents_std;

ALTER TABLE clean.dim_agents
ADD PRIMARY KEY (agent_id);


DROP TABLE IF EXISTS clean.dim_destinations;
CREATE TABLE clean.dim_destinations AS
SELECT DISTINCT *
FROM staging.destinations_std;

ALTER TABLE clean.dim_destinations
ADD PRIMARY KEY (destination_id);


DROP TABLE IF EXISTS clean.dim_hotels;
CREATE TABLE clean.dim_hotels AS
SELECT DISTINCT *
FROM staging.hotels_std;

ALTER TABLE clean.dim_hotels
ADD PRIMARY KEY (hotel_id);


DROP TABLE IF EXISTS clean.dim_suppliers;
CREATE TABLE clean.dim_suppliers AS
SELECT DISTINCT *
FROM staging.suppliers_std;

ALTER TABLE clean.dim_suppliers
ADD PRIMARY KEY (supplier_id);


-- ------------------------------------------------------------
-- 9. CREATE CLEAN BOOKINGS FACT
-- ------------------------------------------------------------
-- Rules:
-- - remove duplicate copies
-- - exclude structurally invalid booking records from KPI layer
-- - keep supplier_id nullable so missing supplier mapping can still be tracked
-- - preserve cancelled bookings; they are valid business events

DROP TABLE IF EXISTS clean.fact_bookings;

CREATE TABLE clean.fact_bookings AS
SELECT
    b.booking_id,
    b.booking_date,
    b.travel_date,
    b.agent_id,
    b.hotel_id,
    b.supplier_id,
    b.destination_id,
    b.rooms::integer AS rooms,
    b.nights::integer AS nights,
    b.guests::integer AS guests,
    b.booking_status,
    b.currency,
    b.gross_booking_value,
    b.supplier_cost,
    COALESCE(b.discount_amount,0) AS discount_amount,
    COALESCE(b.tax_amount,0) AS tax_amount,
    b.payment_status,

    -- Commercial metrics at booking grain
    (
        b.gross_booking_value
        - COALESCE(b.supplier_cost,0)
        - COALESCE(b.discount_amount,0)
    ) AS net_revenue,

    CASE
        WHEN b.gross_booking_value > 0 THEN
            (
                b.gross_booking_value
                - COALESCE(b.supplier_cost,0)
                - COALESCE(b.discount_amount,0)
            ) / b.gross_booking_value
        ELSE NULL
    END AS gross_margin_pct,

    (b.travel_date - b.booking_date) AS lead_days,

    CASE WHEN b.booking_status = 'Cancelled' THEN 1 ELSE 0 END AS is_cancelled,
    CASE WHEN b.supplier_id IS NULL THEN 1 ELSE 0 END AS is_supplier_missing

FROM staging.bookings_typed b
WHERE b.duplicate_rank = 1
  AND b.booking_id IS NOT NULL
  AND b.booking_date IS NOT NULL
  AND b.travel_date IS NOT NULL
  AND b.is_date_invalid = 0
  AND b.is_rooms_invalid = 0
  AND b.is_nights_invalid = 0
  AND b.is_gbv_invalid = 0
  AND b.agent_id IS NOT NULL
  AND b.hotel_id IS NOT NULL
  AND b.destination_id IS NOT NULL;


ALTER TABLE clean.fact_bookings
ADD PRIMARY KEY (booking_id);


-- ------------------------------------------------------------
-- 10. CLEAN CANCELLATIONS
-- ------------------------------------------------------------
-- Keep only cancellation records attached to known clean bookings.

DROP TABLE IF EXISTS clean.fact_cancellations;

CREATE TABLE clean.fact_cancellations AS
SELECT
    c.*
FROM staging.cancellations_typed c
JOIN clean.fact_bookings b
    ON c.booking_id = b.booking_id;

ALTER TABLE clean.fact_cancellations
ADD PRIMARY KEY (cancellation_id);


-- ------------------------------------------------------------
-- 11. PAYMENT AGGREGATE AT BOOKING GRAIN
-- ------------------------------------------------------------
-- Critical: this prevents booking duplication when joining payments.

DROP TABLE IF EXISTS clean.payment_booking_summary;

CREATE TABLE clean.payment_booking_summary AS
SELECT
    booking_id,
    COUNT(*) AS payment_transaction_count,
    SUM(amount) AS total_payment_amount,
    SUM(CASE WHEN payment_status = 'Successful' THEN amount ELSE 0 END) AS successful_payment_amount,
    SUM(CASE WHEN payment_status = 'Refunded' THEN amount ELSE 0 END) AS refunded_payment_amount,
    SUM(CASE WHEN payment_status = 'Failed' THEN amount ELSE 0 END) AS failed_payment_amount,
    MAX(payment_date) AS latest_payment_date
FROM staging.payments_typed
GROUP BY booking_id;


-- ------------------------------------------------------------
-- 12. DATA QUALITY EXCEPTION TABLE
-- ------------------------------------------------------------
-- In industry, bad rows should be traceable rather than silently deleted.

DROP TABLE IF EXISTS clean.booking_data_quality_exceptions;

CREATE TABLE clean.booking_data_quality_exceptions AS
SELECT
    booking_id,
    booking_date,
    travel_date,
    agent_id,
    hotel_id,
    supplier_id,
    destination_id,
    rooms,
    nights,
    gross_booking_value,

    CONCAT_WS(' | ',
        CASE WHEN is_duplicate = 1 THEN 'DUPLICATE' END,
        CASE WHEN is_supplier_missing = 1 THEN 'MISSING_SUPPLIER' END,
        CASE WHEN is_rooms_invalid = 1 THEN 'INVALID_ROOMS' END,
        CASE WHEN is_nights_invalid = 1 THEN 'INVALID_NIGHTS' END,
        CASE WHEN is_gbv_invalid = 1 THEN 'INVALID_GBV' END,
        CASE WHEN is_date_invalid = 1 THEN 'INVALID_DATE_SEQUENCE' END,
        CASE WHEN booking_date IS NULL THEN 'UNPARSEABLE_BOOKING_DATE' END,
        CASE WHEN travel_date IS NULL THEN 'UNPARSEABLE_TRAVEL_DATE' END
    ) AS issue_reason

FROM staging.bookings_typed
WHERE is_duplicate = 1
   OR is_supplier_missing = 1
   OR is_rooms_invalid = 1
   OR is_nights_invalid = 1
   OR is_gbv_invalid = 1
   OR is_date_invalid = 1
   OR booking_date IS NULL
   OR travel_date IS NULL;


-- ------------------------------------------------------------
-- 13. CLEAN-LAYER VALIDATION
-- ------------------------------------------------------------

SELECT 'raw_bookings' AS metric, COUNT(*) AS value
FROM raw.bookings

UNION ALL

SELECT 'staging_bookings', COUNT(*)
FROM staging.bookings_typed

UNION ALL

SELECT 'clean_bookings', COUNT(*)
FROM clean.fact_bookings

UNION ALL

SELECT 'dq_exception_rows', COUNT(*)
FROM clean.booking_data_quality_exceptions;


-- Check clean primary-key uniqueness
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT booking_id) AS distinct_booking_ids,
    COUNT(*) - COUNT(DISTINCT booking_id) AS duplicate_rows
FROM clean.fact_bookings;


-- Check clean logical rules
SELECT
    COUNT(*) FILTER (WHERE travel_date < booking_date) AS invalid_date_sequence,
    COUNT(*) FILTER (WHERE rooms <= 0) AS invalid_rooms,
    COUNT(*) FILTER (WHERE nights <= 0) AS invalid_nights,
    COUNT(*) FILTER (WHERE gross_booking_value <= 0) AS invalid_gbv
FROM clean.fact_bookings;


-- ------------------------------------------------------------
-- 14. FIRST BUSINESS-SAFE KPI CHECK
-- ------------------------------------------------------------
-- NOTE:
-- These values are still in transaction currencies.
-- Do NOT sum them across currencies as a single company-wide monetary KPI.
-- FX normalization comes in Phase 3.

SELECT
    currency,
    COUNT(*) AS bookings,
    SUM(gross_booking_value) AS gbv,
    SUM(net_revenue) AS net_revenue,
    ROUND(AVG(gross_margin_pct) * 100, 2) AS avg_booking_margin_pct,
    ROUND(
        100.0 * SUM(is_cancelled) / NULLIF(COUNT(*),0),
        2
    ) AS cancellation_rate_pct
FROM clean.fact_bookings
GROUP BY currency
ORDER BY bookings DESC;


-- ============================================================
-- PHASE 2 COMPLETE
-- ============================================================
-- Next:
-- 1. Build FX conversion table / normalize monetary metrics.
-- 2. Create analytics marts at controlled grains.
-- 3. Write management SQL for revenue, agents, destinations,
--    suppliers, cancellations and trends.
-- 4. Only after that build the Power BI semantic model.
-- ============================================================
