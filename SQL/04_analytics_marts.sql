--lesson 1 :Monthly performance Mart

CREATE TABLE analytics.monthly_performance AS

SELECT
    DATE_TRUNC('month', booking_dt)::date AS booking_month,

    COUNT(*) AS total_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Completed'
    ) AS completed_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Cancelled'
    ) AS cancelled_bookings,

    SUM(gross_booking_value_inr) AS total_gbv_inr,

    SUM(net_revenue_inr) AS total_net_revenue_inr,

    ROUND(
        SUM(gross_booking_value_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_booking_value_inr,

    ROUND(
        (
            SUM(net_revenue_inr)
            / NULLIF(SUM(gross_booking_value_inr), 0)
        ) * 100,
        2
    ) AS gross_margin_pct,

    ROUND(
        (
            COUNT(*) FILTER (
                WHERE booking_status = 'Cancelled'
            )::numeric
            / NULLIF(COUNT(*), 0)
        ) * 100,
        2
    ) AS cancellation_rate_pct

FROM analytics.fact_bookings_fx

WHERE is_fx_missing = 0

GROUP BY
    DATE_TRUNC('month', booking_dt)::date

ORDER BY booking_month;

--validate the mart
SELECT
    COUNT(*) AS total_months,
    MIN(booking_month) AS first_month,
    MAX(booking_month) AS last_month
FROM analytics.monthly_performance;

--inspect 
SELECT * 
FROM 
analytics.monthly_performance
ORDER BY booking_month
LIMIT 5

--lesson 2:Reconciliation
--step 1 totals from the booking fact table
SELECT
    COUNT(*) AS fact_total_bookings,
    SUM(gross_booking_value_inr) AS fact_total_gbv_inr,
    SUM(net_revenue_inr) AS fact_total_net_revenue_inr
FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0;

--step2 -totals from the monthly mart
SELECT
    SUM(total_bookings) AS mart_total_bookings,
    SUM(total_gbv_inr) AS mart_total_gbv_inr,
    SUM(total_net_revenue_inr) AS mart_total_net_revenue_inr
FROM analytics.monthly_performance;

--step3-check the difference directly
SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_bookings_fx
        WHERE is_fx_missing = 0
    )
    -
    (
        SELECT SUM(total_bookings)
        FROM analytics.monthly_performance
    ) AS booking_difference,

    (
        SELECT SUM(gross_booking_value_inr)
        FROM analytics.fact_bookings_fx
        WHERE is_fx_missing = 0
    )
    -
    (
        SELECT SUM(total_gbv_inr)
        FROM analytics.monthly_performance
    ) AS gbv_difference,

    (
        SELECT SUM(net_revenue_inr)
        FROM analytics.fact_bookings_fx
        WHERE is_fx_missing = 0
    )
    -
    (
        SELECT SUM(total_net_revenue_inr)
        FROM analytics.monthly_performance
    ) AS revenue_difference;

--lesson 3: Month-over-month Growth
CREATE TABLE analytics.monthly_growth AS

WITH previous_month_values AS (

    SELECT
        booking_month,
        total_bookings,
        total_gbv_inr,
        total_net_revenue_inr,

        LAG(total_bookings) OVER (
            ORDER BY booking_month
        ) AS previous_month_bookings,

        LAG(total_gbv_inr) OVER (
            ORDER BY booking_month
        ) AS previous_month_gbv_inr,

        LAG(total_net_revenue_inr) OVER (
            ORDER BY booking_month
        ) AS previous_month_net_revenue_inr

    FROM analytics.monthly_performance
)

SELECT
    booking_month,

    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,

    previous_month_bookings,
    previous_month_gbv_inr,
    previous_month_net_revenue_inr,

    ROUND(
        (
            (total_bookings - previous_month_bookings)::numeric
            / NULLIF(previous_month_bookings, 0)
        ) * 100,
        2
    ) AS booking_growth_pct,

    ROUND(
        (
            (total_gbv_inr - previous_month_gbv_inr)
            / NULLIF(previous_month_gbv_inr, 0)
        ) * 100,
        2
    ) AS gbv_growth_pct,

    ROUND(
        (
            (total_net_revenue_inr - previous_month_net_revenue_inr)
            / NULLIF(previous_month_net_revenue_inr, 0)
        ) * 100,
        2
    ) AS net_revenue_growth_pct

FROM previous_month_values

ORDER BY booking_month;

--inspect the result
SELECT * 
FROM analytics.monthly_growth
ORDER BY booking_month
LIMIT 6

--validate 
SELECT 
	COUNT(*) AS  total_month,
	COUNT(*) FILTER ( WHERE booking_growth_pct IS NULL ) AS months_without_booking_growth
FROM analytics.Monthly_Growth;

--lesson 4: Agent performance
CREATE TABLE analytics.agent_performance AS

SELECT
    agent_id,

    COUNT(*) AS total_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Completed'
    ) AS completed_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Cancelled'
    ) AS cancelled_bookings,

    SUM(gross_booking_value_inr) AS total_gbv_inr,

    SUM(net_revenue_inr) AS total_net_revenue_inr,

    ROUND(
        SUM(gross_booking_value_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_booking_value_inr,

    ROUND(
        (
            SUM(net_revenue_inr)
            / NULLIF(SUM(gross_booking_value_inr), 0)
        ) * 100,
        2
    ) AS gross_margin_pct,

    ROUND(
        (
            COUNT(*) FILTER (
                WHERE booking_status = 'Cancelled'
            )::numeric
            / NULLIF(COUNT(*), 0)
        ) * 100,
        2
    ) AS cancellation_rate_pct

FROM analytics.fact_bookings_fx

WHERE is_fx_missing = 0

GROUP BY agent_id;

--validate uniqueness
SELECT 
	COUNT(*) AS total_rows,
	COUNT(DISTINCT agent_id) AS unique_agents,
	COUNT(*)- COUNT(DISTINCT agent_id) AS duplicate_agents
FROM 
analytics.agent_performance;

--Find the most active agents
SELECT 
	agent_id,
	total_bookings,
	total_gbv_inr,
	total_net_revenue_inr,
	cancellation_rate_pct
FROM 
analytics.agent_performance
ORDER BY total_bookings DESC
LIMIT 10;

--lesson 5 Destination Performance
--create the destination mart
CREATE TABLE analytics.destination_performance AS

SELECT
    destination_id,

    COUNT(*) AS total_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Completed'
    ) AS completed_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Cancelled'
    ) AS cancelled_bookings,

    SUM(gross_booking_value_inr) AS total_gbv_inr,

    SUM(net_revenue_inr) AS total_net_revenue_inr,

    ROUND(
        SUM(gross_booking_value_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_booking_value_inr,

    ROUND(
        (
            SUM(net_revenue_inr)
            / NULLIF(SUM(gross_booking_value_inr), 0)
        ) * 100,
        2
    ) AS gross_margin_pct,

    ROUND(
        (
            COUNT(*) FILTER (
                WHERE booking_status = 'Cancelled'
            )::numeric
            / NULLIF(COUNT(*), 0)
        ) * 100,
        2
    ) AS cancellation_rate_pct

FROM analytics.fact_bookings_fx

WHERE is_fx_missing = 0

GROUP BY destination_id;

--validate uniqueness
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT destination_id) AS unique_destinations,
    COUNT(*) - COUNT(DISTINCT destination_id) AS duplicate_destinations
FROM analytics.destination_performance;

--inspect top destinations by GBV
SELECT
    destination_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.destination_performance
ORDER BY total_gbv_inr DESC
LIMIT 10;

--lesson 6 Supplier performance
--create the supplier mart
CREATE TABLE analytics.supplier_performance AS

SELECT
    CASE
        WHEN is_supplier_missing = 1 THEN 'UNKNOWN'
        ELSE supplier_id
    END AS supplier_id,

    COUNT(*) AS total_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Completed'
    ) AS completed_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Cancelled'
    ) AS cancelled_bookings,

    SUM(gross_booking_value_inr) AS total_gbv_inr,

    SUM(supplier_cost_inr) AS total_supplier_cost_inr,

    SUM(net_revenue_inr) AS total_net_revenue_inr,

    ROUND(
        SUM(gross_booking_value_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_booking_value_inr,

    ROUND(
        (
            SUM(net_revenue_inr)
            / NULLIF(SUM(gross_booking_value_inr), 0)
        ) * 100,
        2
    ) AS gross_margin_pct,

    ROUND(
        (
            COUNT(*) FILTER (
                WHERE booking_status = 'Cancelled'
            )::numeric
            / NULLIF(COUNT(*), 0)
        ) * 100,
        2
    ) AS cancellation_rate_pct

FROM analytics.fact_bookings_fx

WHERE is_fx_missing = 0

GROUP BY
    CASE
        WHEN is_supplier_missing = 1 THEN 'UNKNOWN'
        ELSE supplier_id
    END;

--validate the grain
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT supplier_id) AS unique_suppliers,
    COUNT(*) - COUNT(DISTINCT supplier_id) AS duplicate_suppliers
FROM analytics.supplier_performance;

--check the UNKNOWN bucket
SELECT *
FROM analytics.supplier_performance
WHERE supplier_id = 'UNKNOWN';

--inspect supplier by GBV
SELECT
    supplier_id,
    total_bookings,
    total_gbv_inr,
    total_supplier_cost_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.supplier_performance
ORDER BY total_gbv_inr DESC
LIMIT 10;

--diagontics
SELECT
    COUNT(*) FILTER (
        WHERE supplier_id IS NULL
    ) AS null_supplier_rows,

    COUNT(*) FILTER (
        WHERE TRIM(COALESCE(supplier_id, '')) = ''
    ) AS blank_or_null_supplier_rows,

    COUNT(*) FILTER (
        WHERE is_supplier_missing = 1
    ) AS flagged_missing_supplier_rows

FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0;

--
SELECT
    supplier_id,
    total_bookings
FROM analytics.supplier_performance
WHERE supplier_id IS NULL
   OR TRIM(COALESCE(supplier_id, '')) = ''
   OR supplier_id = 'UNKNOWN';

 --lesson 7 :Hotel performance
 --create the hotel mart
 CREATE TABLE analytics.hotel_performance AS

SELECT
    hotel_id,

    COUNT(*) AS total_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Completed'
    ) AS completed_bookings,

    COUNT(*) FILTER (
        WHERE booking_status = 'Cancelled'
    ) AS cancelled_bookings,

    SUM(gross_booking_value_inr) AS total_gbv_inr,

    SUM(net_revenue_inr) AS total_net_revenue_inr,

    ROUND(
        SUM(gross_booking_value_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_booking_value_inr,

    ROUND(
        (
            SUM(net_revenue_inr)
            / NULLIF(SUM(gross_booking_value_inr), 0)
        ) * 100,
        2
    ) AS gross_margin_pct,

    ROUND(
        (
            COUNT(*) FILTER (
                WHERE booking_status = 'Cancelled'
            )::numeric
            / NULLIF(COUNT(*), 0)
        ) * 100,
        2
    ) AS cancellation_rate_pct

FROM analytics.fact_bookings_fx

WHERE is_fx_missing = 0

GROUP BY hotel_id;

--validate uniqueness
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT hotel_id) AS unique_hotels,
    COUNT(*) - COUNT(DISTINCT hotel_id) AS duplicate_hotels
FROM analytics.hotel_performance;

--inspect hotels by GBV
SELECT
    hotel_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.hotel_performance
ORDER BY total_gbv_inr DESC
LIMIT 10;

--lesson 8 cancellation analysis
--create the cancellation mart
CREATE TABLE analytics.cancellation_analysis AS

SELECT
    cancellation_reason,

    COUNT(*) AS total_cancellations,

    SUM(refund_amount_inr) AS total_refund_amount_inr,

    SUM(cancellation_fee_inr) AS total_cancellation_fee_inr,

    ROUND(
        SUM(refund_amount_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_refund_amount_inr,

    ROUND(
        SUM(cancellation_fee_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_cancellation_fee_inr

FROM analytics.fact_cancellations_fx

WHERE is_fx_missing = 0

GROUP BY cancellation_reason

ORDER BY total_cancellations DESC;

--validate the mart
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT cancellation_reason) AS unique_reasons,
    COUNT(*) - COUNT(DISTINCT cancellation_reason) AS duplicate_reasons
FROM analytics.cancellation_analysis;

--reconcile cancellation counts
SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_cancellations_fx
        WHERE is_fx_missing = 0
    )
    -
    (
        SELECT SUM(total_cancellations)
        FROM analytics.cancellation_analysis
    ) AS cancellation_difference;

--rerun
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT cancellation_reason) AS unique_reasons,
    COUNT(*) - COUNT(DISTINCT cancellation_reason) AS duplicate_reasons
FROM analytics.cancellation_analysis;

--lesson 9 :final mart validate + Indexes
--step 1 create unique indexes 
--moonthly performance
CREATE UNIQUE INDEX IF NOT EXISTS idx_monthly_performance_month
ON analytics.monthly_performance (booking_month);

--monthly Growth
CREATE UNIQUE INDEX IF NOT EXISTS idx_monthly_growth_month
ON analytics.monthly_growth (booking_month);

--for agents
CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_performance_agent
ON analytics.agent_performance (agent_id);

--for destinations
CREATE UNIQUE INDEX IF NOT EXISTS idx_destination_performance_destination
ON analytics.destination_performance (destination_id);

--for suppliers
CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_performance_supplier
ON analytics.supplier_performance (supplier_id);

--for hotels
CREATE UNIQUE INDEX IF NOT EXISTS idx_hotel_performance_hotel
ON analytics.hotel_performance (hotel_id);

--for cancellation reason
CREATE UNIQUE INDEX IF NOT EXISTS idx_cancellation_analysis_reason
ON analytics.cancellation_analysis (cancellation_reason);

--step 2 check all mart row counts
SELECT 'monthly_performance' AS mart_name,
       COUNT(*) AS row_count
FROM analytics.monthly_performance

UNION ALL

SELECT 'monthly_growth',
       COUNT(*)
FROM analytics.monthly_growth

UNION ALL

SELECT 'agent_performance',
       COUNT(*)
FROM analytics.agent_performance

UNION ALL

SELECT 'destination_performance',
       COUNT(*)
FROM analytics.destination_performance

UNION ALL

SELECT 'supplier_performance',
       COUNT(*)
FROM analytics.supplier_performance

UNION ALL

SELECT 'hotel_performance',
       COUNT(*)
FROM analytics.hotel_performance

UNION ALL

SELECT 'cancellation_analysis',
       COUNT(*)
FROM analytics.cancellation_analysis;

--step 3 final finacial reconciliation
SELECT
    COUNT(*) AS fact_bookings,
    SUM(gross_booking_value_inr) AS fact_gbv_inr,
    SUM(net_revenue_inr) AS fact_net_revenue_inr
FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0;

--main marts
SELECT
    'monthly_performance' AS mart_name,
    SUM(total_bookings) AS total_bookings,
    SUM(total_gbv_inr) AS total_gbv_inr,
    SUM(total_net_revenue_inr) AS total_net_revenue_inr
FROM analytics.monthly_performance

UNION ALL

SELECT
    'agent_performance',
    SUM(total_bookings),
    SUM(total_gbv_inr),
    SUM(total_net_revenue_inr)
FROM analytics.agent_performance

UNION ALL

SELECT
    'destination_performance',
    SUM(total_bookings),
    SUM(total_gbv_inr),
    SUM(total_net_revenue_inr)
FROM analytics.destination_performance

UNION ALL

SELECT
    'supplier_performance',
    SUM(total_bookings),
    SUM(total_gbv_inr),
    SUM(total_net_revenue_inr)
FROM analytics.supplier_performance

UNION ALL

SELECT
    'hotel_performance',
    SUM(total_bookings),
    SUM(total_gbv_inr),
    SUM(total_net_revenue_inr)
FROM analytics.hotel_performance;

--
SELECT
    COUNT(*) FILTER (
        WHERE supplier_id IS NULL
    ) AS null_supplier_rows,

    COUNT(*) FILTER (
        WHERE TRIM(COALESCE(supplier_id, '')) = ''
    ) AS blank_or_null_supplier_rows,

    COUNT(*) FILTER (
        WHERE is_supplier_missing = 1
    ) AS flagged_missing_supplier_rows
FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0;

