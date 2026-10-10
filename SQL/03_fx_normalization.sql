--phase 3 lesson 1 create the analytics layer

create schema if not exists analytics;

--lesson 2 exercise

SELECT 
	MIN(booking_dt) AS first_booking_date,
	MAX(booking_dt) AS last_booking_date
FROM clean.fact_bookings;

--lesson 3 create the base FX Rate Table

CREATE TABLE 
	analytics.fx_base_rates(currency VARCHAR(3) PRIMARY KEY,base_rate_to_inr NUMERIC(12,4));

--insert the 15 currencies
INSERT INTO analytics.fx_base_rates
    (currency, base_rate_to_inr)
VALUES
    ('INR', 1.0000),
    ('USD', 83.0000),
    ('EUR', 90.0000),
    ('GBP', 105.0000),
    ('AED', 22.6000),
    ('SAR', 22.1000),
    ('QAR', 22.8000),
    ('AUD', 54.0000),
    ('SGD', 62.0000),
    ('MYR', 17.7000),
    ('JPY', 0.5600),
    ('THB', 2.3000),
    ('IDR', 0.0053),
    ('TRY', 2.6000),
    ('EGP', 1.7000);

--validate the table
SELECT *
FROM analytics.fx_base_rates
ORDER BY currency;

--
SELECT COUNT(*) AS currency_count
FROM analytics.fx_base_rates;

--lesson 4: create monthly fx rates
CREATE TABLE analytics.fx_rates AS

WITH month_range AS (
    SELECT
        DATE_TRUNC('month', MIN(booking_dt))::date AS start_month,
        DATE_TRUNC('month', MAX(booking_dt))::date AS end_month
    FROM clean.fact_bookings
),

months AS (
    SELECT
        GENERATE_SERIES(
            start_month,
            end_month,
            INTERVAL '1 month'
        )::date AS fx_month
    FROM month_range
)

SELECT
    m.fx_month,
    f.currency,
    f.base_rate_to_inr AS rate_to_inr

FROM months AS m

CROSS JOIN analytics.fx_base_rates AS f;

--validate the FX table
SELECT
    COUNT(*) AS total_fx_rows,
    COUNT(DISTINCT fx_month) AS total_months,
    COUNT(DISTINCT currency) AS total_currencies
FROM analytics.fx_rates;

SELECT *
FROM analytics.fx_rates
WHERE currency = 'INR'
ORDER BY fx_month;

--lesson 5: validate check the monthly FX table
SELECT
	COUNT(*) AS total_fx_rows,
	COUNT(DISTINCT fx_month) AS total_months,
	COUNT(DISTINCT currency) AS total_currencies
FROM analytics.fx_rates;

--check INR rates:

SELECT * 
FROM analytics.fx_rates
WHERE currency='INR'
ORDER BY fx_month;

--lesson 5 convert booking values into INR
--step 1 create analytics.fact_bookings_fx
CREATE TABLE analytics.fact_bookings_fx AS

SELECT
    b.*,

    DATE_TRUNC('month', b.booking_dt)::date AS fx_month,

    fx.rate_to_inr,

    CASE
        WHEN fx.rate_to_inr IS NULL THEN 1
        ELSE 0
    END AS is_fx_missing,

    b.gross_booking_value * fx.rate_to_inr
        AS gross_booking_value_inr,

    b.supplier_cost * fx.rate_to_inr
        AS supplier_cost_inr,

    b.discount_amount * fx.rate_to_inr
        AS discount_amount_inr,

    b.net_revenue * fx.rate_to_inr
        AS net_revenue_inr

FROM clean.fact_bookings AS b

LEFT JOIN analytics.fx_rates AS fx
    ON DATE_TRUNC('month', b.booking_dt)::date = fx.fx_month
   AND b.currency = fx.currency;

--validate the FX conversion
SELECT 
	COUNT(*) AS total_rows,
	COUNT(*) FILTER (WHERE is_fx_missing = 1) AS missing_fx_rows
FROM analytics.fact_bookings_fx;

--check INR bookings
SELECT 
	booking_id,
	currency,
	gross_booking_value,
	rate_to_inr,
	ROUND((gross_booking_value_inr),2)
FROM
analytics.fact_bookings_fx
WHERE currency='INR'
LIMIT 10;

--lesson 6 : validate the FX conversion
--step 1 inspect a few converted bookings

SELECT
    booking_id,
    currency,
    gross_booking_value,
    rate_to_inr,
    gross_booking_value_inr

FROM analytics.fact_bookings_fx

WHERE currency <> 'INR'

LIMIT 10;

--step 2 let postgreSQL validate every row
SELECT
    COUNT(*) AS conversion_mismatch_rows
FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0 AND ABS(gross_booking_value_inr- (gross_booking_value * rate_to_inr)) > 0.01;

--step 3 validate INR booking separately

SELECT
    COUNT(*) AS incorrect_inr_rows
FROM analytics.fact_bookings_fx
WHERE currency = 'INR'
  AND (rate_to_inr <> 1 OR gross_booking_value_inr <> gross_booking_value);

--lesson 7 : calculate consolidate INR KPIs
SELECT
    COUNT(*) AS total_bookings,

    SUM(gross_booking_value_inr) AS total_gbv_inr,

    SUM(net_revenue_inr) AS total_net_revenue_inr,

    ROUND(SUM(gross_booking_value_inr) / COUNT(*),2 ) AS avg_booking_value_inr,

    ROUND((SUM(net_revenue_inr)/ NULLIF(SUM(gross_booking_value_inr), 0) ) * 100,2) AS gross_margin_pct

FROM analytics.fact_bookings_fx

WHERE is_fx_missing = 0;

--lesson 8 convert cancellations refunds into INR

SELECT 
	MIN(cancellation_date) AS first_cancellation_date,
	MAX(cancellation_date) AS last_cancellation_date
FROM clean.fact_cancellations;

SELECT 
	MIN(fx_month) AS first_fx_month,
	MAX(fx_month) AS last_fx_month
FROM analytics.fx_rates;

--lesson 8B : extend the FX table

INSERT INTO analytics.fx_rates (
    fx_month,
    currency,
    rate_to_inr
)

SELECT
    m.fx_month::date,
    f.currency,
    f.base_rate_to_inr

FROM GENERATE_SERIES(
    (
        SELECT MAX(fx_month) + INTERVAL '1 month'
        FROM analytics.fx_rates
    ),
    (
        SELECT
            DATE_TRUNC(
                'month',
                MAX(cancellation_date)
            )::date
        FROM clean.fact_cancellations
    ),
    INTERVAL '1 month'
) AS m(fx_month)

CROSS JOIN analytics.fx_base_rates AS f;

--validate it 
SELECT
    COUNT(*) AS total_fx_rows,
    COUNT(DISTINCT fx_month) AS total_months,
    COUNT(DISTINCT currency) AS total_currencies,
    MIN(fx_month) AS first_fx_month,
    MAX(fx_month) AS last_fx_month
FROM analytics.fx_rates;

--lesson 8C: create analytics.fact_cancellations_fx

CREATE TABLE analytics.fact_cancellations_fx AS

SELECT
    c.*,

    DATE_TRUNC('month', c.cancellation_date)::date AS fx_month,

    b.currency,

    fx.rate_to_inr,

    CASE
        WHEN fx.rate_to_inr IS NULL THEN 1
        ELSE 0
    END AS is_fx_missing,

    c.refund_amount * fx.rate_to_inr
        AS refund_amount_inr,

    c.cancellation_fee * fx.rate_to_inr
        AS cancellation_fee_inr

FROM clean.fact_cancellations AS c

LEFT JOIN clean.booking_deduped AS b
    ON c.booking_id = b.booking_id

LEFT JOIN analytics.fx_rates AS fx
    ON DATE_TRUNC('month', c.cancellation_date)::date = fx.fx_month
   AND b.currency = fx.currency;

--validate the table

SELECT 
	COUNT(*) AS total_rows,
	COUNT(*) FILTER ( WHERE is_fx_missing=1 ) AS missing_fx_rows
FROM analytics.fact_cancellations_fx;

SELECT
    booking_id,
    currency,
    refund_amount,
    rate_to_inr,
    refund_amount_inr
FROM analytics.fact_cancellations_fx
WHERE currency = 'INR'
LIMIT 10;

--lesson 9:Normalize payment into INR
--leeson 9A : check payment date coverage

SELECT 
	MIN(payment_dt) AS first_payment_date,
	MAX(payment_dt) AS last_payment_date
FROM staging.payments_typed;

SELECT 
	MIN(fx_month) AS first_fx_months,
	MAX(fx_month) AS last_fx_months
FROM analytics.fx_rates;

--lesson 9B: convert each payment transaction into INR
CREATE TABLE analytics.payment_transactions_fx AS

SELECT
    p.*,

    b.currency,

    DATE_TRUNC('month', p.payment_dt)::date AS fx_month,

    fx.rate_to_inr,

    CASE
        WHEN fx.rate_to_inr IS NULL THEN 1
        ELSE 0
    END AS is_fx_missing,

    p.amount_num * fx.rate_to_inr AS amount_inr

FROM staging.payments_typed AS p

LEFT JOIN clean.booking_deduped AS b
    ON p.booking_id = b.booking_id

LEFT JOIN analytics.fx_rates AS fx
    ON DATE_TRUNC('month', p.payment_dt)::date = fx.fx_month
   AND b.currency = fx.currency;

-- validate the transaction level conversion
SELECT
    COUNT(*) AS total_payment_rows,

    COUNT(*) FILTER (
        WHERE is_fx_missing = 1
    ) AS missing_fx_rows,

    COUNT(*) FILTER (
        WHERE currency IS NULL
    ) AS missing_currency_rows

FROM analytics.payment_transactions_fx;

--then check the math
SELECT
    COUNT(*) AS conversion_mismatch_rows
FROM analytics.payment_transactions_fx
WHERE is_fx_missing = 0
  AND ABS(
        amount_inr - (amount_num * rate_to_inr)
      ) > 0.01;

--lesson 9C: aggregate INR payments to Booking level
CREATE TABLE analytics.payment_booking_summary_fx AS

SELECT
    booking_id,

    COUNT(*) AS payment_rows,

    SUM(amount_inr) AS total_payment_amount_inr,

    SUM(
        CASE
            WHEN payment_status_std = 'Paid'
            THEN amount_inr
            ELSE 0
        END
    ) AS paid_amount_inr,

    SUM(
        CASE
            WHEN payment_status_std = 'Refunded'
            THEN amount_inr
            ELSE 0
        END
    ) AS refunded_amount_inr,

    MIN(payment_dt) AS first_payment_date,

    MAX(payment_dt) AS last_payment_date

FROM analytics.payment_transactions_fx

WHERE is_fx_missing = 0

GROUP BY booking_id;

--validate the summary table
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT booking_id) AS unique_booking_ids,
    COUNT(*) - COUNT(DISTINCT booking_id) AS duplicate_booking_ids
FROM analytics.payment_booking_summary_fx;

SELECT
    booking_id,
    payment_rows,
    total_payment_amount_inr,
    paid_amount_inr,
    refunded_amount_inr
FROM analytics.payment_booking_summary_fx
WHERE booking_id = 'B0088132';

--lesson 10: reconcile payments with bookings

--step1 compare payments with the final clean fact table
SELECT
    COUNT(*) AS total_payment_bookings,

    COUNT(*) FILTER (
        WHERE b.booking_id IS NOT NULL
    ) AS payments_linked_to_valid_bookings,

    COUNT(*) FILTER (
        WHERE b.booking_id IS NULL
    ) AS payments_not_in_clean_fact

FROM analytics.payment_booking_summary_fx AS p

LEFT JOIN clean.fact_bookings AS b
    ON p.booking_id = b.booking_id;

--step2 check for true ophan payment bookings
SELECT
    COUNT(*) AS true_orphan_payment_bookings
FROM analytics.payment_booking_summary_fx AS p

LEFT JOIN clean.booking_deduped AS b
    ON p.booking_id = b.booking_id

WHERE b.booking_id IS NULL;

--lesson 11 final FX validation
SELECT
    (SELECT COUNT(*)
     FROM analytics.fact_bookings_fx
     WHERE is_fx_missing = 1
    ) AS booking_missing_fx,

    (SELECT COUNT(*)
     FROM analytics.fact_cancellations_fx
     WHERE is_fx_missing = 1
    ) AS cancellation_missing_fx,

    (SELECT COUNT(*)
     FROM analytics.payment_transactions_fx
     WHERE is_fx_missing = 1
    ) AS payment_missing_fx;
--check INR rate
SELECT
	COUNT(*) AS incorrect_inr_fx_rows
FROM analytics.fx_rates
WHERE currency = 'INR'
  AND rate_to_inr <> 1;

--varify booking grain
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT booking_id) AS unique_booking_ids,
    COUNT(*) - COUNT(DISTINCT booking_id) AS duplicate_rows
FROM analytics.fact_bookings_fx;

--check cancellation grain
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT cancellation_id) AS unique_cancellation_ids,
    COUNT(*) - COUNT(DISTINCT cancellation_id) AS duplicate_rows
FROM analytics.fact_cancellations_fx;

--lesson 12: Final KPI Reconciliation and Completion
SELECT
    COUNT(*) AS total_bookings,

    SUM(gross_booking_value_inr) AS total_gbv_inr,

    SUM(net_revenue_inr) AS total_net_revenue_inr,

    ROUND(
        SUM(gross_booking_value_inr) / COUNT(*),
        2
    ) AS avg_booking_value_inr,

    ROUND(
        (
            SUM(net_revenue_inr)
            / NULLIF(SUM(gross_booking_value_inr), 0)
        ) * 100,
        2
    ) AS gross_margin_pct

FROM analytics.fact_bookings_fx

WHERE is_fx_missing = 0;

--for ABV
SELECT
    ROUND(
        SUM(gross_booking_value_inr) / COUNT(*),
        2
    ) AS recalculated_abv
FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0;

--for gross margin
SELECT
    ROUND(
        (
            SUM(net_revenue_inr)
            / NULLIF(SUM(gross_booking_value_inr), 0)
        ) * 100,
        2
    ) AS recalculated_margin_pct
FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0;


