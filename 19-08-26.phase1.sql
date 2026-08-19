/*Query 1 — Customer Lifecycle Intelligence
Business requirement

Identify customers who:

Have purchased in at least 3 consecutive months
Have lifetime revenue above the overall customer average
Have experienced at least one 60+ day inactivity period
Subsequently returned
Have positive revenue growth in their latest active month
Rank in the top 5 customers within their region by lifetime revenue
Tables*/

WITH customer_months AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', order_date) AS sales_month
    FROM fact_sales
),

monthly_revenue AS
(
    SELECT
        customer_id,
        DATE_TRUNC('month', order_date) AS sales_month,
        SUM(sales_amount) AS monthly_revenue
    FROM fact_sales
    GROUP BY
        customer_id,
        DATE_TRUNC('month', order_date)
),

monthly_lag AS
(
    SELECT
        *,
        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month,

        LAG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_revenue
    FROM monthly_revenue
),

growth_flags AS
(
    SELECT
        *,
        CASE
            WHEN previous_month = sales_month - INTERVAL '1 month'
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
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS island_id
    FROM growth_flags
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

longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_monthly_streak
    FROM streaks
    GROUP BY customer_id
),

purchase_gaps AS
(
    SELECT
        customer_id,
        order_date,

        LAG(order_date) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS previous_order_date

    FROM fact_sales
),

reactivations AS
(
    SELECT
        customer_id,
        order_date,

        order_date - previous_order_date AS inactive_days

    FROM purchase_gaps

    WHERE previous_order_date IS NOT NULL
      AND order_date - previous_order_date >= 60
),

customer_lifetime AS
(
    SELECT
        customer_id,
        SUM(sales_amount) AS lifetime_revenue
    FROM fact_sales
    GROUP BY customer_id
),

average_customer_revenue AS
(
    SELECT
        AVG(lifetime_revenue) AS avg_revenue
    FROM customer_lifetime
),

reactivation_metrics AS
(
    SELECT
        customer_id,
        MAX(inactive_days) AS max_inactive_days,
        COUNT(*) AS reactivation_count
    FROM reactivations
    GROUP BY customer_id
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
    FROM monthly_lag
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        l.lifetime_revenue,

        s.longest_monthly_streak,

        r.max_inactive_days,
        r.reactivation_count,

        m.sales_month AS latest_month,
        m.monthly_revenue AS latest_month_revenue,

        ROUND(
            (m.monthly_revenue - m.previous_revenue)
            * 100.0
            / NULLIF(m.previous_revenue, 0),
            2
        ) AS latest_mom_growth

    FROM dim_customers c

    JOIN customer_lifetime l
        ON c.customer_id = l.customer_id

    JOIN longest_streak s
        ON c.customer_id = s.customer_id

    JOIN reactivation_metrics r
        ON c.customer_id = r.customer_id

    JOIN latest_month m
        ON c.customer_id = m.customer_id
       AND m.rn = 1

    CROSS JOIN average_customer_revenue a

    WHERE l.lifetime_revenue > a.avg_revenue
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

    WHERE longest_monthly_streak >= 3
      AND max_inactive_days >= 60
      AND reactivation_count >= 1
      AND latest_mom_growth > 0
)

SELECT
    *
FROM ranked_customers
WHERE regional_rank <= 5
ORDER BY
    region,
    regional_rank;


/*Query 2 — Product Growth & Category Dominance
Requirement

Identify products that:

Have revenue growth for 3+ consecutive months
Have lifetime revenue above their category average
Contribute at least 10% of category revenue
Have positive growth in their latest month
Rank among the top 3 products in their category*/


WITH monthly_product_revenue AS
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

    FROM monthly_product_revenue
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

growth_islands AS
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

growth_streaks AS
(
    SELECT
        product_id,
        island_id,
        COUNT(*) AS streak_length
    FROM growth_islands
    WHERE growth_flag = 1
    GROUP BY
        product_id,
        island_id
),

longest_growth AS
(
    SELECT
        product_id,
        MAX(streak_length) AS longest_growth_streak
    FROM growth_streaks
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
        SUM(lifetime_revenue) OVER
        (
            PARTITION BY category
        ) AS category_revenue,

        AVG(lifetime_revenue) OVER
        (
            PARTITION BY category
        ) AS category_avg_revenue

    FROM product_lifetime
),

latest_product_month AS
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
        c.category_revenue,
        c.category_avg_revenue,

        ROUND(
            c.lifetime_revenue * 100.0
            / NULLIF(c.category_revenue, 0),
            2
        ) AS category_contribution_pct,

        g.longest_growth_streak,

        l.sales_month AS latest_month,
        l.monthly_revenue AS latest_month_revenue,

        ROUND(
            (l.monthly_revenue - l.previous_revenue)
            * 100.0
            / NULLIF(l.previous_revenue, 0),
            2
        ) AS latest_mom_growth

    FROM category_metrics c

    JOIN longest_growth g
        ON c.product_id = g.product_id

    JOIN latest_product_month l
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
    *
FROM ranked_products
WHERE category_rank <= 3

ORDER BY
    category,
    category_rank;


/*Query 3 — Salesperson Performance Intelligence
Requirement

For every salesperson:

Calculate monthly revenue.
Calculate MoM growth.
Calculate 3-month rolling revenue.
Calculate yearly revenue.
Calculate YoY growth.
Find their longest consecutive monthly revenue-growth streak.
Find their highest-revenue quarter.
Calculate their percentage contribution to regional revenue.
Rank them within their region.
Return the top 3 salespeople per region who:
have at least a 3-month growth streak
have positive YoY growth
contribute at least 10% of regional revenue.*/

WITH monthly_sales AS
(
    SELECT
        s.salesperson_id,
        s.salesperson_name,
        s.region,
        DATE_TRUNC('month', f.order_date) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue

    FROM fact_sales f

    JOIN dim_salespersons s
        ON f.salesperson_id = s.salesperson_id

    GROUP BY
        s.salesperson_id,
        s.salesperson_name,
        s.region,
        DATE_TRUNC('month', f.order_date)
),

monthly_lag AS
(
    SELECT
        *,
        LAG(monthly_revenue) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_month
        ) AS previous_revenue,

        LAG(sales_month) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_month
        ) AS previous_month

    FROM monthly_sales
),

monthly_growth AS
(
    SELECT
        *,
        ROUND(
            (monthly_revenue - previous_revenue)
            * 100.0
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

growth_islands AS
(
    SELECT
        *,
        SUM(
            CASE WHEN growth_flag = 0 THEN 1 ELSE 0 END
        ) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_month
        ) AS island_id

    FROM monthly_growth
),

growth_streaks AS
(
    SELECT
        salesperson_id,
        island_id,
        COUNT(*) AS streak_length
    FROM growth_islands
    WHERE growth_flag = 1
    GROUP BY
        salesperson_id,
        island_id
),

longest_growth AS
(
    SELECT
        salesperson_id,
        MAX(streak_length) AS longest_growth_streak
    FROM growth_streaks
    GROUP BY salesperson_id
),

yearly_sales AS
(
    SELECT
        salesperson_id,
        EXTRACT(YEAR FROM sales_month) AS sales_year,
        SUM(monthly_revenue) AS yearly_revenue
    FROM monthly_sales
    GROUP BY
        salesperson_id,
        EXTRACT(YEAR FROM sales_month)
),

yearly_lag AS
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

    FROM yearly_lag
),

quarterly_sales AS
(
    SELECT
        salesperson_id,
        EXTRACT(YEAR FROM sales_month) AS sales_year,
        EXTRACT(QUARTER FROM sales_month) AS sales_quarter,
        SUM(monthly_revenue) AS quarterly_revenue

    FROM monthly_sales

    GROUP BY
        salesperson_id,
        EXTRACT(YEAR FROM sales_month),
        EXTRACT(QUARTER FROM sales_month)
),

best_quarter AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY salesperson_id
            ORDER BY quarterly_revenue DESC
        ) AS rn

    FROM quarterly_sales
),

regional_revenue AS
(
    SELECT
        salesperson_id,
        region,
        SUM(monthly_revenue) AS salesperson_revenue,

        SUM(SUM(monthly_revenue)) OVER
        (
            PARTITION BY region
        ) AS regional_revenue

    FROM monthly_sales

    GROUP BY
        salesperson_id,
        region
),

regional_metrics AS
(
    SELECT
        salesperson_id,
        region,
        salesperson_revenue,
        regional_revenue,

        ROUND(
            salesperson_revenue * 100.0
            / NULLIF(regional_revenue, 0),
            2
        ) AS regional_contribution_pct

    FROM regional_revenue
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

salesperson_profile AS
(
    SELECT
        m.salesperson_id,
        m.salesperson_name,
        m.region,

        g.longest_growth_streak,

        y.sales_year,
        y.yearly_revenue,
        y.yoy_growth,

        q.sales_quarter,
        q.quarterly_revenue AS highest_quarterly_revenue,

        r.regional_contribution_pct

    FROM monthly_sales m

    JOIN longest_growth g
        ON m.salesperson_id = g.salesperson_id

    JOIN latest_year y
        ON m.salesperson_id = y.salesperson_id
       AND y.rn = 1

    JOIN best_quarter q
        ON m.salesperson_id = q.salesperson_id
       AND q.rn = 1

    JOIN regional_metrics r
        ON m.salesperson_id = r.salesperson_id

    GROUP BY
        m.salesperson_id,
        m.salesperson_name,
        m.region,
        g.longest_growth_streak,
        y.sales_year,
        y.yearly_revenue,
        y.yoy_growth,
        q.sales_quarter,
        q.quarterly_revenue,
        r.regional_contribution_pct
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
