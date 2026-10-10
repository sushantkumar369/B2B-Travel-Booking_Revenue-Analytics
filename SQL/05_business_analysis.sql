--phase 5 Bussiness Analysis with SQL 

--Lesson 1 - overall Business Performance

SELECT
    COUNT(*) AS total_bookings,

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

WHERE is_fx_missing = 0;

--lesson2 Monthly growth and trend analysis
--step1 view the monthly trend
SELECT
    booking_month,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    booking_growth_pct,
    gbv_growth_pct,
    net_revenue_growth_pct
FROM analytics.monthly_growth
ORDER BY booking_month;

--step2 find the month with the highest GBV growth
SELECT
    booking_month,
    total_gbv_inr,
    gbv_growth_pct
FROM analytics.monthly_growth
WHERE gbv_growth_pct IS NOT NULL
ORDER BY gbv_growth_pct DESC
LIMIT 5;

--step 3 find the strongest decline
SELECT
    booking_month,
    total_gbv_inr,
    gbv_growth_pct
FROM analytics.monthly_growth
WHERE gbv_growth_pct IS NOT NULL
ORDER BY gbv_growth_pct ASC
LIMIT 5;

--step 4 compare GBV growth with revenue growth
SELECT
    booking_month,
    gbv_growth_pct,
    net_revenue_growth_pct
FROM analytics.monthly_growth
WHERE gbv_growth_pct IS NOT NULL
ORDER BY booking_month;

--lesson 3 agent performance analysis
--step1 top agents by bookings
SELECT
    agent_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    cancellation_rate_pct
FROM analytics.agent_performance
ORDER BY total_bookings DESC
LIMIT 10;

--step2 top agents by net revenue
SELECT
    agent_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.agent_performance
ORDER BY total_net_revenue_inr DESC
LIMIT 10;

--step3 find high cancellation agents
SELECT
    agent_id,
    total_bookings,
    cancelled_bookings,
    cancellation_rate_pct,
    total_gbv_inr,
    total_net_revenue_inr
FROM analytics.agent_performance
WHERE total_bookings >= 20
ORDER BY cancellation_rate_pct DESC
LIMIT 10;

--step4 why minimum booking volume matters

--lesson 4 Destination performance 
--step1 top destinations by GBV
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

--step2 top destinations by net revenue
SELECT
    destination_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.destination_performance
ORDER BY total_net_revenue_inr DESC
LIMIT 10;

--step3 destinations with high cancellation rates
SELECT
    destination_id,
    total_bookings,
    cancelled_bookings,
    cancellation_rate_pct,
    total_gbv_inr,
    total_net_revenue_inr
FROM analytics.destination_performance
WHERE total_bookings >= 100
ORDER BY cancellation_rate_pct DESC
LIMIT 10;

--step 4 compare volume and quality together

--lesson 5 supplier profitability
--step1 top suppliers by GBV

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

--step 2 top suppliers by net revenue
SELECT
    supplier_id,
    total_bookings,
    total_gbv_inr,
    total_supplier_cost_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.supplier_performance
ORDER BY total_net_revenue_inr DESC
LIMIT 10;

--step 3 suppliers with strong margins
SELECT
    supplier_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct
FROM analytics.supplier_performance
WHERE total_bookings >= 100
ORDER BY gross_margin_pct DESC
LIMIT 10;

--step 4 suppliers with weaker margins 
SELECT
    supplier_id,
    total_bookings,
    total_gbv_inr,
    total_supplier_cost_inr,
    total_net_revenue_inr,
    gross_margin_pct
FROM analytics.supplier_performance
WHERE total_bookings >= 100
ORDER BY gross_margin_pct ASC
LIMIT 10;

--lesson 6 Hotel performance
--step1 top hotels by bookings
SELECT
    hotel_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.hotel_performance
ORDER BY total_bookings DESC
LIMIT 10;

--step2 top hotels by net revenue
SELECT
    hotel_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct,
    cancellation_rate_pct
FROM analytics.hotel_performance
ORDER BY total_net_revenue_inr DESC
LIMIT 10;

--step 3 Hotels with high cancellation rates
SELECT
    hotel_id,
    total_bookings,
    cancelled_bookings,
    cancellation_rate_pct,
    total_gbv_inr,
    total_net_revenue_inr
FROM analytics.hotel_performance
WHERE total_bookings >= 50
ORDER BY cancellation_rate_pct DESC
LIMIT 10;

--step 4 Hotels with stronger and weaker margins
SELECT
    hotel_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct
FROM analytics.hotel_performance
WHERE total_bookings >= 50
ORDER BY gross_margin_pct DESC
LIMIT 10;

--weak margin 
SELECT
    hotel_id,
    total_bookings,
    total_gbv_inr,
    total_net_revenue_inr,
    gross_margin_pct
FROM analytics.hotel_performance
WHERE total_bookings >= 50
ORDER BY gross_margin_pct ASC
LIMIT 10;

--lesson 7 Cancellation & refund analysis
--step1 most common cancellations reasons
SELECT
    cancellation_reason,
    total_cancellations,
    total_refund_amount_inr,
    total_cancellation_fee_inr,
    avg_refund_amount_inr,
    avg_cancellation_fee_inr
FROM analytics.cancellation_analysis
ORDER BY total_cancellations DESC;

--step2 Reasons causing the highest refund value
SELECT
    cancellation_reason,
    total_cancellations,
    total_refund_amount_inr,
    avg_refund_amount_inr
FROM analytics.cancellation_analysis
ORDER BY total_refund_amount_inr DESC;

--step 3 reasons with the highest average refund
SELECT
    cancellation_reason,
    total_cancellations,
    total_refund_amount_inr,
    avg_refund_amount_inr
FROM analytics.cancellation_analysis
ORDER BY avg_refund_amount_inr DESC;

--step4 compare refunds and cancellation fees
SELECT
    cancellation_reason,
    total_refund_amount_inr,
    total_cancellation_fee_inr,

    ROUND(
        total_cancellation_fee_inr
        / NULLIF(total_refund_amount_inr, 0)
        * 100,
        2
    ) AS fee_to_refund_pct

FROM analytics.cancellation_analysis
ORDER BY fee_to_refund_pct DESC;

--lesson 8 final business insights
--build a final SQL insight summary

SELECT
    COUNT(*) AS total_bookings,

    ROUND(SUM(gross_booking_value_inr), 2) AS total_gbv_inr,

    ROUND(SUM(net_revenue_inr), 2) AS total_net_revenue_inr,

    ROUND(
        SUM(gross_booking_value_inr)
        / NULLIF(COUNT(*), 0),
        2
    ) AS avg_booking_value_inr,

    ROUND(
        SUM(net_revenue_inr)
        / NULLIF(SUM(gross_booking_value_inr), 0)
        * 100,
        2
    ) AS gross_margin_pct,

    ROUND(
        COUNT(*) FILTER (
            WHERE booking_status = 'Cancelled'
        )::numeric
        / NULLIF(COUNT(*), 0)
        * 100,
        2
    ) AS cancellation_rate_pct

FROM analytics.fact_bookings_fx
WHERE is_fx_missing = 0;

--END SQL ---