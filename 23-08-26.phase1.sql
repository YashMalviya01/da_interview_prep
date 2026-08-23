

/*Q1 — Customer Monthly Retention
Requirement

Identify customers who:

Have at least 6 active months
Have at least one 3-month consecutive purchase streak
Have a positive latest-month MoM growth
Have lifetime revenue above the average customer lifetime revenue
Rank in the top 5 per region*/


WITH monthly_customer_sales AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        DATE_TRUNC('month', f.order_date) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        DATE_TRUNC('month', f.order_date)
),

monthly_lag AS
(
    SELECT
        *,

        LAG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_revenue,

        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month

    FROM monthly_customer_sales
),

monthly_metrics AS
(
    SELECT
        *,

        ROUND(
            (monthly_revenue - previous_revenue) * 100.0
            / NULLIF(previous_revenue, 0),
            2
        ) AS mom_growth,

        CASE
            WHEN previous_month =
                 sales_month - INTERVAL '1 month'
                 AND monthly_revenue > previous_revenue
            THEN 1
            ELSE 0
        END AS growth_flag

    FROM monthly_lag
),

islands AS
(
    SELECT
        *,

        SUM(
            CASE
                WHEN growth_flag = 0 THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS island_id

    FROM monthly_metrics
),

streaks AS
(
    SELECT
        customer_id,
        island_id,
        COUNT(*) AS streak_length

    FROM islands

    WHERE growth_flag = 1

    GROUP BY
        customer_id,
        island_id
),

customer_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_growth_streak

    FROM streaks

    GROUP BY customer_id
),

customer_lifetime AS
(
    SELECT
        customer_id,
        SUM(sales_amount) AS lifetime_revenue,
        COUNT(DISTINCT DATE_TRUNC('month', order_date))
            AS active_months

    FROM fact_sales

    GROUP BY customer_id
),

average_revenue AS
(
    SELECT
        AVG(lifetime_revenue) AS avg_lifetime_revenue

    FROM customer_lifetime
),

latest_month AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM monthly_metrics
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        l.lifetime_revenue,
        l.active_months,

        s.longest_growth_streak,

        m.sales_month AS latest_month,
        m.monthly_revenue AS latest_month_revenue,
        m.mom_growth

    FROM dim_customers c

    JOIN customer_lifetime l
        ON c.customer_id = l.customer_id

    JOIN customer_streak s
        ON c.customer_id = s.customer_id

    JOIN latest_month m
        ON c.customer_id = m.customer_id
       AND m.rn = 1

    CROSS JOIN average_revenue a

    WHERE l.active_months >= 6
      AND s.longest_growth_streak >= 3
      AND m.mom_growth > 0
      AND l.lifetime_revenue > a.avg_lifetime_revenue
),

ranked_customers AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY region
            ORDER BY lifetime_revenue DESC
        ) AS regional_rank

    FROM customer_profile
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,
    lifetime_revenue,
    active_months,
    longest_growth_streak,
    latest_month,
    latest_month_revenue,
    mom_growth,
    regional_rank

FROM ranked_customers

WHERE regional_rank <= 5

ORDER BY
    region,
    regional_rank;


/*Q2 — Product MoM Growth + Category Share
Requirement

Find products that:

Have at least 12 active months
Have a 4-month consecutive revenue-growth streak
Contribute at least 10% of category revenue
Have positive latest-month MoM growth
Rank top 3 in their category.*/

WITH monthly_product_sales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        DATE_TRUNC('month', f.order_date) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        DATE_TRUNC('month', f.order_date)
),

monthly_lag AS
(
    SELECT
        *,

        LAG(monthly_revenue) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_revenue,

        LAG(sales_month) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_month

    FROM monthly_product_sales
),

growth_flags AS
(
    SELECT
        *,

        CASE
            WHEN previous_month =
                 sales_month - INTERVAL '1 month'
                 AND monthly_revenue > previous_revenue
            THEN 1
            ELSE 0
        END AS growth_flag

    FROM monthly_lag
),

islands AS
(
    SELECT
        *,

        SUM(
            CASE WHEN growth_flag = 0 THEN 1 ELSE 0 END
        ) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS island_id

    FROM growth_flags
),

streaks AS
(
    SELECT
        product_id,
        island_id,
        COUNT(*) AS streak_length

    FROM islands

    WHERE growth_flag = 1

    GROUP BY
        product_id,
        island_id
),

longest_streak AS
(
    SELECT
        product_id,
        MAX(streak_length) AS longest_growth_streak

    FROM streaks

    GROUP BY product_id
),

product_metrics AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,

        SUM(f.sales_amount) AS lifetime_revenue,

        COUNT(
            DISTINCT DATE_TRUNC('month', f.order_date)
        ) AS active_months

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),

category_metrics AS
(
    SELECT
        *,

        SUM(lifetime_revenue) OVER
        (
            PARTITION BY category
        ) AS category_revenue

    FROM product_metrics
),

latest_month AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM monthly_lag
),

product_profile AS
(
    SELECT
        c.product_id,
        c.product_name,
        c.category,

        c.lifetime_revenue,
        c.active_months,

        ROUND(
            c.lifetime_revenue * 100.0
            / NULLIF(c.category_revenue, 0),
            2
        ) AS category_share_pct,

        s.longest_growth_streak,

        l.sales_month AS latest_month,
        l.monthly_revenue AS latest_month_revenue,

        ROUND(
            (l.monthly_revenue - l.previous_revenue) * 100.0
            / NULLIF(l.previous_revenue, 0),
            2
        ) AS latest_mom_growth

    FROM category_metrics c

    JOIN longest_streak s
        ON c.product_id = s.product_id

    JOIN latest_month l
        ON c.product_id = l.product_id
       AND l.rn = 1
),

ranked_products AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY category
            ORDER BY lifetime_revenue DESC
        ) AS category_rank

    FROM product_profile

    WHERE active_months >= 12
      AND longest_growth_streak >= 4
      AND category_share_pct >= 10
      AND latest_mom_growth > 0
)

SELECT
    *
FROM ranked_products

WHERE category_rank <= 3

ORDER BY
    category,
    category_rank;

/*Q3 — Customer Reactivation & Recovery
Requirement

Identify customers who:

Had at least one 90+ day inactivity period
Returned after the inactivity
Reactivated at least twice
Generated more revenue after their most recent reactivation than before it
Rank top 5 per region by recovered revenue.*/


WITH customer_orders AS
(
    SELECT
        f.customer_id,
        f.order_date,
        f.sales_amount,

        LAG(f.order_date) OVER
        (
            PARTITION BY f.customer_id
            ORDER BY f.order_date
        ) AS previous_order_date

    FROM fact_sales f
),

reactivation_events AS
(
    SELECT
        customer_id,
        order_date AS reactivation_date,

        order_date - previous_order_date AS inactive_days

    FROM customer_orders

    WHERE previous_order_date IS NOT NULL
      AND order_date - previous_order_date >= 90
),

latest_reactivation AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY reactivation_date DESC
        ) AS rn

    FROM reactivation_events
),

reactivation_summary AS
(
    SELECT
        customer_id,

        COUNT(*) AS reactivation_count,
        MAX(inactive_days) AS max_inactive_days

    FROM reactivation_events

    GROUP BY customer_id
),

revenue_before_after AS
(
    SELECT
        r.customer_id,
        r.reactivation_date,

        SUM(
            CASE
                WHEN f.order_date < r.reactivation_date
                THEN f.sales_amount
                ELSE 0
            END
        ) AS revenue_before,

        SUM(
            CASE
                WHEN f.order_date >= r.reactivation_date
                THEN f.sales_amount
                ELSE 0
            END
        ) AS revenue_after

    FROM latest_reactivation r

    JOIN fact_sales f
        ON r.customer_id = f.customer_id

    WHERE r.rn = 1

    GROUP BY
        r.customer_id,
        r.reactivation_date
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        r.reactivation_count,
        r.max_inactive_days,

        b.reactivation_date,

        b.revenue_before,
        b.revenue_after,

        b.revenue_after - b.revenue_before
            AS recovered_revenue

    FROM dim_customers c

    JOIN reactivation_summary r
        ON c.customer_id = r.customer_id

    JOIN revenue_before_after b
        ON c.customer_id = b.customer_id

    WHERE r.reactivation_count >= 2
      AND r.max_inactive_days >= 90
      AND b.revenue_after > b.revenue_before
),

ranked_customers AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY region
            ORDER BY recovered_revenue DESC
        ) AS regional_rank

    FROM customer_profile
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,
    reactivation_count,
    max_inactive_days,
    reactivation_date,
    revenue_before,
    revenue_after,
    recovered_revenue,
    regional_rank

FROM ranked_customers

WHERE regional_rank <= 5

ORDER BY
    region,
    regional_rank;


 /*Q4 — Store Year-over-Year Performance
Requirement

For every store:

Calculate yearly revenue.
Previous-year revenue.
YoY growth.
3-year rolling average revenue.
Best-performing year.
Number of years with positive YoY growth.
Rank stores within their region.
Return top 3 stores per region where:
latest YoY growth > 10%
positive-growth years >= 3.*/

WITH yearly_store_sales AS
(
    SELECT
        s.store_id,
        s.store_name,
        s.region,

        EXTRACT(YEAR FROM f.order_date) AS sales_year,

        SUM(f.sales_amount) AS yearly_revenue

    FROM fact_sales f

    JOIN dim_stores s
        ON f.store_id = s.store_id

    GROUP BY
        s.store_id,
        s.store_name,
        s.region,
        EXTRACT(YEAR FROM f.order_date)
),

yearly_lag AS
(
    SELECT
        *,

        LAG(yearly_revenue) OVER
        (
            PARTITION BY store_id
            ORDER BY sales_year
        ) AS previous_year_revenue

    FROM yearly_store_sales
),

yearly_metrics AS
(
    SELECT
        *,

        ROUND(
            (yearly_revenue - previous_year_revenue) * 100.0
            / NULLIF(previous_year_revenue, 0),
            2
        ) AS yoy_growth,

        AVG(yearly_revenue) OVER
        (
            PARTITION BY store_id
            ORDER BY sales_year
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_year_average,

        CASE
            WHEN yearly_revenue > previous_year_revenue
            THEN 1
            ELSE 0
        END AS positive_growth_flag

    FROM yearly_lag
),

store_summary AS
(
    SELECT
        store_id,

        SUM(positive_growth_flag)
            AS positive_growth_years,

        MAX(yearly_revenue)
            AS best_year_revenue

    FROM yearly_metrics

    GROUP BY store_id
),

latest_year AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY store_id
            ORDER BY sales_year DESC
        ) AS rn

    FROM yearly_metrics
),

store_profile AS
(
    SELECT
        l.store_id,
        l.store_name,
        l.region,

        l.sales_year AS latest_year,
        l.yearly_revenue AS latest_year_revenue,
        l.previous_year_revenue,
        l.yoy_growth,
        l.rolling_3_year_average,

        s.positive_growth_years,
        s.best_year_revenue

    FROM latest_year l

    JOIN store_summary s
        ON l.store_id = s.store_id

    WHERE l.rn = 1
),

ranked_stores AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY region
            ORDER BY latest_year_revenue DESC
        ) AS regional_rank

    FROM store_profile

    WHERE yoy_growth > 10
      AND positive_growth_years >= 3
)

SELECT
    store_id,
    store_name,
    region,
    latest_year,
    latest_year_revenue,
    previous_year_revenue,
    yoy_growth,
    rolling_3_year_average,
    positive_growth_years,
    best_year_revenue,
    regional_rank

FROM ranked_stores

WHERE regional_rank <= 3

ORDER BY
    region,
    regional_rank;

/*Q5 — Customer Lifetime Value & Segment Ranking
Requirement

Identify high-value customers within each segment.

For every customer calculate:

Lifetime revenue
Total orders
Average order value
First purchase date
Latest purchase date
Customer lifetime in days
Revenue in the latest 6 months
Revenue contribution to their segment
Lifetime revenue rank within segment

Return the top 5 customers per segment whose latest 6-month revenue is at least 30% of their lifetime revenue.*/

WITH customer_metrics AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,

        SUM(f.sales_amount) AS lifetime_revenue,

        COUNT(DISTINCT f.order_id) AS total_orders,

        ROUND(
            SUM(f.sales_amount)
            / NULLIF(COUNT(DISTINCT f.order_id), 0),
            2
        ) AS average_order_value,

        MIN(f.order_date) AS first_purchase_date,

        MAX(f.order_date) AS latest_purchase_date

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name,
        c.segment
),

six_month_revenue AS
(
    SELECT
        customer_id,

        SUM(sales_amount) AS latest_6_month_revenue

    FROM fact_sales

    WHERE order_date >=
          CURRENT_DATE - INTERVAL '6 months'

    GROUP BY customer_id
),

segment_metrics AS
(
    SELECT
        *,

        SUM(lifetime_revenue) OVER
        (
            PARTITION BY segment
        ) AS segment_revenue

    FROM customer_metrics
),

customer_profile AS
(
    SELECT
        s.customer_id,
        s.customer_name,
        s.segment,

        s.lifetime_revenue,
        s.total_orders,
        s.average_order_value,

        s.first_purchase_date,
        s.latest_purchase_date,

        s.latest_purchase_date
        - s.first_purchase_date
            AS customer_lifetime_days,

        COALESCE(
            m.latest_6_month_revenue,
            0
        ) AS latest_6_month_revenue,

        ROUND(
            s.lifetime_revenue * 100.0
            / NULLIF(s.segment_revenue, 0),
            2
        ) AS segment_revenue_percentage

    FROM segment_metrics s

    LEFT JOIN six_month_revenue m
        ON s.customer_id = m.customer_id
),

ranked_customers AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY segment
            ORDER BY lifetime_revenue DESC
        ) AS segment_rank

    FROM customer_profile

    WHERE latest_6_month_revenue >=
          lifetime_revenue * 0.30
)

SELECT
    customer_id,
    customer_name,
    segment,
    lifetime_revenue,
    total_orders,
    average_order_value,
    first_purchase_date,
    latest_purchase_date,
    customer_lifetime_days,
    latest_6_month_revenue,
    segment_revenue_percentage,
    segment_rank

FROM ranked_customers

WHERE segment_rank <= 5

ORDER BY
    segment,
    segment_rank;
