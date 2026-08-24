/*Q1/5 — Customer Monthly Performance
Requirement

For every customer:

Calculate monthly revenue.
Calculate previous month's revenue.
Calculate MoM growth %.
Calculate a 3-month rolling average.
Find the customer's longest consecutive month-over-month revenue growth streak.
Identify the latest active month.
Return customers whose:
longest growth streak ≥ 3
latest MoM growth > 0
lifetime revenue > overall customer average

Then rank them by lifetime revenue within region and return the top 5 per region.*/

WITH customer_monthly_sales AS
(
    SELECT  
        c.customer_id,
        c.customer_name, 
        c.segment,
        c.region,
        DATE_TRUNC('month', f.order_date) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue
    FROM fact_sales f    
    JOIN dim_customers c ON f.customer_id = c.customer_id
    GROUP BY c.customer_id,
        c.customer_name, 
        c.segment,
        c.region,
        DATE_TRUNC('month', f.order_date) 
),

monthly_metrics AS
(
    SELECT
        *,

        LAG(monthly_revenue) OVER (PARTITION BY customer_id ORDER BY sales_month) AS previous_month_revenue,

        LAG(sales_month) OVER (PARTITION BY customer_id ORDER BY sales_month) AS previous_month,

        AVG(monthly_revenue) OVER (PARTITION BY customer_id ORDER BY sales_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3_month_revenue
   
        FROM customer_monthly_sales

       
),

growth_flags AS

(
    SELECT 
        *,

        ROUND( (monthly_revenue - previous_month_revenue) * 100.0/ NULLIF(previous_month_revenue,0),2) AS mom_growth,

        CASE WHEN previous_month = sales_month - INTERVAL '1 month' AND monthly_revenue > previous_month_revenue THEN 1 ELSE 0 END AS growth_flag
        FROM monthly_metrics
),

island AS

(
    SELECT 
        *,

        SUM(CASE WHEN growth_flag = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY customer_id ORDER BY sales_month) AS island_id

        FROM growth_flags
),

streaks AS 
(
    SELECT 
        customer_id,
        island_id,
        COUNT(*) AS streak_length
    FROM island
    WHERE growth_flag = 1
    GROUP BY customer_id, island_id
),

max_streaks AS 
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
        SUM(sales_amount) AS lifetime_revenue
    FROM fact_sales
    GROUP BY customer_id
),

overall_avg_revenue AS 
(
    SELECT 
        AVG(lifetime_revenue) AS avg_lifetime_revenue
    FROM customer_lifetime
),

latest_month_metrics AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY sales_month DESC) AS rn
    FROM growth_flags
),

filtered_customers AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        l.lifetime_revenue,
        lm.sales_month AS latest_month,
        lm.monthly_revenue AS latest_month_revenue,
        lm.mom_growth AS latest_mom_growth,
        lm.rolling_3_month_revenue,
        COALESCE(ms.longest_growth_streak, 0) AS longest_growth_streak
    FROM dim_customers c
    JOIN customer_lifetime l ON c.customer_id = l.customer_id
    JOIN latest_month_metrics lm ON c.customer_id = lm.customer_id AND lm.rn = 1
    LEFT JOIN max_streaks ms ON c.customer_id = ms.customer_id
    CROSS JOIN overall_avg_revenue avg_rev
    WHERE 
        COALESCE(ms.longest_growth_streak, 0) >= 3
        AND lm.mom_growth > 0
        AND l.lifetime_revenue > avg_rev.avg_lifetime_revenue
),

ranked_customers AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY region ORDER BY lifetime_revenue DESC
        ) AS regional_rank
    FROM filtered_customers
)

SELECT 
    customer_id,
    customer_name,
    segment,
    region,
    lifetime_revenue,
    latest_month,
    latest_month_revenue,
    latest_mom_growth,
    rolling_3_month_revenue,
    longest_growth_streak,
    regional_rank
FROM ranked_customers
WHERE regional_rank <= 5
ORDER BY region, regional_rank;


/*Q2 — Product Category Leaders*/

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

monthly_metrics AS
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
    FROM monthly_metrics
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

product_lifetime AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(f.sales_amount) AS lifetime_revenue
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
        AVG(lifetime_revenue) OVER
        (
            PARTITION BY category
        ) AS category_avg_revenue,

        SUM(lifetime_revenue) OVER
        (
            PARTITION BY category
        ) AS category_revenue
    FROM product_lifetime
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
    FROM growth_flags
),

product_profile AS
(
    SELECT
        c.product_id,
        c.product_name,
        c.category,
        c.lifetime_revenue,
        c.category_avg_revenue,

        ROUND(
            c.lifetime_revenue * 100.0
            / NULLIF(c.category_revenue, 0),
            2
        ) AS category_contribution_pct,

        s.longest_growth_streak,

        l.sales_month AS latest_month,
        l.monthly_revenue AS latest_month_revenue,
        l.mom_growth AS latest_mom_growth

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
    WHERE lifetime_revenue > category_avg_revenue
      AND category_contribution_pct >= 10
      AND longest_growth_streak >= 3
      AND latest_mom_growth > 0
)

SELECT
    product_id,
    product_name,
    category,
    lifetime_revenue,
    category_avg_revenue,
    category_contribution_pct,
    longest_growth_streak,
    latest_month,
    latest_month_revenue,
    latest_mom_growth,
    category_rank
FROM ranked_products
WHERE category_rank <= 3
ORDER BY
    category,
    category_rank;


/*Q3 — Customer Reactivation*/

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
      AND order_date - previous_order_date >= 60
),

reactivation_summary AS
(
    SELECT
        customer_id,
        COUNT(*) AS reactivation_count,
        MAX(inactive_days) AS longest_inactive_days
    FROM reactivation_events
    GROUP BY customer_id
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
        r.longest_inactive_days,

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
      AND r.longest_inactive_days >= 60
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
    *
FROM ranked_customers
WHERE regional_rank <= 5
ORDER BY
    region,
    regional_rank;

/*Q4 — Store YoY Performance*/


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

yearly_metrics AS
(
    SELECT
        *,

        LAG(yearly_revenue) OVER
        (
            PARTITION BY store_id
            ORDER BY sales_year
        ) AS previous_year_revenue,

        AVG(yearly_revenue) OVER
        (
            PARTITION BY store_id
            ORDER BY sales_year
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_year_average

    FROM yearly_store_sales
),

growth_metrics AS
(
    SELECT
        *,

        ROUND(
            (yearly_revenue - previous_year_revenue) * 100.0
            / NULLIF(previous_year_revenue, 0),
            2
        ) AS yoy_growth,

        CASE
            WHEN yearly_revenue > previous_year_revenue
            THEN 1
            ELSE 0
        END AS positive_growth_flag

    FROM yearly_metrics
),

store_summary AS
(
    SELECT
        store_id,

        SUM(positive_growth_flag)
            AS positive_growth_years,

        MAX(yearly_revenue)
            AS best_year_revenue

    FROM growth_metrics

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
    FROM growth_metrics
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
    *
FROM ranked_stores
WHERE regional_rank <= 3
ORDER BY
    region,
    regional_rank;

/*Q5 — Salesperson Quarterly Performance*/

WITH quarterly_sales AS
(
    SELECT
        s.salesperson_id,
        s.salesperson_name,
        s.region,

        DATE_TRUNC('quarter', f.order_date) AS sales_quarter,

        SUM(f.sales_amount) AS quarterly_revenue

    FROM fact_sales f

    JOIN dim_salespersons s
        ON f.salesperson_id = s.salesperson_id

    GROUP BY
        s.salesperson_id,
        s.salesperson_name,
        s.region,
        DATE_TRUNC('quarter', f.order_date)
),

quarterly_metrics AS
(
    SELECT
        *,

        LAG(quarterly_revenue) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_quarter
        ) AS previous_quarter_revenue,

        LAG(sales_quarter) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_quarter
        ) AS previous_quarter

    FROM quarterly_sales
),

growth_flags AS
(
    SELECT
        *,

        ROUND(
            (quarterly_revenue - previous_quarter_revenue)
            * 100.0
            / NULLIF(previous_quarter_revenue, 0),
            2
        ) AS qoq_growth,

        CASE
            WHEN previous_quarter =
                 sales_quarter - INTERVAL '3 months'
                 AND quarterly_revenue > previous_quarter_revenue
            THEN 1
            ELSE 0
        END AS growth_flag

    FROM quarterly_metrics
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
            PARTITION BY salesperson_id
            ORDER BY sales_quarter
        ) AS island_id

    FROM growth_flags
),

streaks AS
(
    SELECT
        salesperson_id,
        island_id,
        COUNT(*) AS streak_length

    FROM islands

    WHERE growth_flag = 1

    GROUP BY
        salesperson_id,
        island_id
),

longest_streak AS
(
    SELECT
        salesperson_id,
        MAX(streak_length) AS longest_growth_streak

    FROM streaks

    GROUP BY salesperson_id
),

yearly_sales AS
(
    SELECT
        salesperson_id,
        EXTRACT(YEAR FROM sales_quarter) AS sales_year,
        SUM(quarterly_revenue) AS yearly_revenue

    FROM quarterly_sales

    GROUP BY
        salesperson_id,
        EXTRACT(YEAR FROM sales_quarter)
),

yearly_metrics AS
(
    SELECT
        *,

        LAG(yearly_revenue) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_year
        ) AS previous_year_revenue

    FROM yearly_sales
),

yoy_metrics AS
(
    SELECT
        *,

        ROUND(
            (yearly_revenue - previous_year_revenue)
            * 100.0
            / NULLIF(previous_year_revenue, 0),
            2
        ) AS yoy_growth

    FROM yearly_metrics
),

latest_year AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_year DESC
        ) AS rn

    FROM yoy_metrics
),

regional_metrics AS
(
    SELECT
        salesperson_id,
        region,

        SUM(quarterly_revenue) AS salesperson_revenue,

        SUM(SUM(quarterly_revenue)) OVER
        (
            PARTITION BY region
        ) AS regional_revenue

    FROM quarterly_sales

    GROUP BY
        salesperson_id,
        region
),

regional_share AS
(
    SELECT
        *,

        ROUND(
            salesperson_revenue * 100.0
            / NULLIF(regional_revenue, 0),
            2
        ) AS regional_contribution_pct

    FROM regional_metrics
),

latest_quarter AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_quarter DESC
        ) AS rn

    FROM growth_flags
),

salesperson_profile AS
(
    SELECT
        q.salesperson_id,
        q.salesperson_name,
        q.region,

        q.sales_quarter AS latest_quarter,
        q.quarterly_revenue AS latest_quarter_revenue,
        q.qoq_growth,

        y.sales_year,
        y.yearly_revenue,
        y.yoy_growth,

        s.longest_growth_streak,

        r.regional_contribution_pct

    FROM latest_quarter q

    JOIN latest_year y
        ON q.salesperson_id = y.salesperson_id
       AND y.rn = 1

    JOIN longest_streak s
        ON q.salesperson_id = s.salesperson_id

    JOIN regional_share r
        ON q.salesperson_id = r.salesperson_id

    WHERE q.rn = 1
),

ranked_salespeople AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY region
            ORDER BY yearly_revenue DESC
        ) AS regional_rank

    FROM salesperson_profile

    WHERE longest_growth_streak >= 3
      AND yoy_growth > 0
      AND regional_contribution_pct >= 10
)

SELECT
    *
FROM ranked_salespeople
WHERE regional_rank <= 3
ORDER BY
    region,
    regional_rank;
