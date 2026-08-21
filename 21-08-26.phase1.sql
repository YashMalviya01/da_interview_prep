/*Question 1/4 — Customer Revenue Cohort Analysis

An e-commerce company wants to understand how customer revenue evolves after customers make their first purchase.
Business requirement

For every customer:

Identify their first purchase month.
Calculate their monthly revenue.
Calculate the number of months since their first purchase.
Calculate their cumulative revenue since acquisition.
Calculate their 3-month rolling revenue.
Identify their highest-revenue month.
Calculate their revenue contribution within their cohort.
Identify whether they made a purchase in 3 consecutive months at any point.*/


WITH customer_revenue AS
(
    -- Grain: one row per customer per month
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

cohort_month AS
(
    SELECT
        customer_id,
        customer_name,
        segment,
        region,
        sales_month,
        monthly_revenue,

        MIN(sales_month) OVER
        (
            PARTITION BY customer_id
        ) AS first_purchase_month

    FROM customer_revenue
),

customer_age AS
(
    SELECT
        *,

        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_purchase_month,

        (
            EXTRACT(
                YEAR FROM AGE(
                    sales_month,
                    first_purchase_month
                )
            ) * 12
            +
            EXTRACT(
                MONTH FROM AGE(
                    sales_month,
                    first_purchase_month
                )
            )
        ) AS months_since_first_purchase

    FROM cohort_month
),

monthly_metrics AS
(
    SELECT
        *,

        -- Cumulative revenue since first purchase
        SUM(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS cumulative_revenue,

        -- 3-month rolling revenue
        ROUND(
            AVG(monthly_revenue) OVER
            (
                PARTITION BY customer_id
                ORDER BY sales_month
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_3_month_revenue

    FROM customer_age
),

highest_revenue_month AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY
                monthly_revenue DESC,
                sales_month
        ) AS revenue_month_rank

    FROM monthly_metrics
),

customer_lifetime AS
(
    -- Grain: one row per customer
    SELECT
        customer_id,
        customer_name,
        segment,
        region,
        first_purchase_month,

        SUM(monthly_revenue) AS lifetime_revenue

    FROM monthly_metrics

    GROUP BY
        customer_id,
        customer_name,
        segment,
        region,
        first_purchase_month
),

cohort_distribution AS
(
    SELECT
        *,

        SUM(lifetime_revenue) OVER
        (
            PARTITION BY first_purchase_month
        ) AS cohort_total_revenue

    FROM customer_lifetime
),

cohort_percentage AS
(
    SELECT
        *,

        ROUND(
            lifetime_revenue * 100.0
            / NULLIF(cohort_total_revenue, 0),
            2
        ) AS cohort_revenue_percentage

    FROM cohort_distribution
),

streak_flags AS
(
    SELECT
        *,

        CASE
            WHEN previous_purchase_month =
                 sales_month - INTERVAL '1 month'
            THEN 0
            ELSE 1
        END AS new_island_flag

    FROM monthly_metrics
),

activity_islands AS
(
    SELECT
        *,

        SUM(new_island_flag) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS island_id

    FROM streak_flags
),

streak_lengths AS
(
    SELECT
        customer_id,
        island_id,
        COUNT(*) AS streak_length

    FROM activity_islands

    GROUP BY
        customer_id,
        island_id
),

longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_purchase_streak

    FROM streak_lengths

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
        ) AS latest_month_rank

    FROM monthly_metrics
)

SELECT
    l.customer_id,
    l.customer_name,
    l.segment,
    l.region,

    l.first_purchase_month AS cohort_month,

    c.lifetime_revenue,

    l.sales_month AS latest_month,
    l.monthly_revenue AS latest_month_revenue,

    l.months_since_first_purchase,

    l.cumulative_revenue,

    l.rolling_3_month_revenue,

    h.monthly_revenue AS highest_monthly_revenue,
    h.sales_month AS highest_revenue_month,

    c.cohort_revenue_percentage,

    s.longest_purchase_streak

FROM latest_month l

JOIN customer_lifetime c
    ON l.customer_id = c.customer_id

JOIN cohort_percentage c
    ON l.customer_id = c.customer_id

JOIN longest_streak s
    ON l.customer_id = s.customer_id

JOIN highest_revenue_month h
    ON l.customer_id = h.customer_id
   AND h.revenue_month_rank = 1

WHERE l.latest_month_rank = 1

ORDER BY
    l.customer_id;


/*Question 2/4 — Customer Retention & Reactivation
Requirement

Identify customers who:

Made purchases in at least 4 different months
Had an inactivity gap of 60+ days
Returned after that inactivity
Have a 3+ month consecutive purchase streak
Have lifetime revenue above the average customer lifetime revenue
Rank in the top 5 per region*/


WITH customer_months AS
(
    SELECT DISTINCT
        f.customer_id,
        DATE_TRUNC('month', f.order_date) AS sales_month
    FROM fact_sales f
),

monthly_activity AS
(
    SELECT
        customer_id,
        sales_month,

        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month

    FROM customer_months
),

purchase_gaps AS
(
    SELECT
        customer_id,
        sales_month,
        previous_month,

        sales_month - previous_month AS month_gap,

        CASE
            WHEN previous_month IS NOT NULL
                 AND sales_month >= previous_month + INTERVAL '3 months'
            THEN 1
            ELSE 0
        END AS reactivation_flag

    FROM monthly_activity
),

customer_activity AS
(
    SELECT
        customer_id,
        COUNT(*) AS active_months,
        SUM(reactivation_flag) AS reactivation_count

    FROM purchase_gaps

    GROUP BY customer_id
),

daily_purchase_gaps AS
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

inactivity AS
(
    SELECT
        customer_id,

        MAX(
            order_date - previous_order_date
        ) AS max_inactive_days

    FROM daily_purchase_gaps

    WHERE previous_order_date IS NOT NULL

    GROUP BY customer_id
),

streak_flags AS
(
    SELECT
        customer_id,
        sales_month,
        previous_month,

        CASE
            WHEN previous_month =
                 sales_month - INTERVAL '1 month'
            THEN 0
            ELSE 1
        END AS new_island_flag

    FROM monthly_activity
),

islands AS
(
    SELECT
        *,

        SUM(new_island_flag) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS island_id

    FROM streak_flags
),

streak_lengths AS
(
    SELECT
        customer_id,
        island_id,
        COUNT(*) AS streak_length

    FROM islands

    GROUP BY
        customer_id,
        island_id
),

longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_purchase_streak

    FROM streak_lengths

    GROUP BY customer_id
),

lifetime_revenue AS
(
    SELECT
        customer_id,
        SUM(sales_amount) AS lifetime_revenue

    FROM fact_sales

    GROUP BY customer_id
),

average_revenue AS
(
    SELECT
        AVG(lifetime_revenue) AS avg_customer_revenue

    FROM lifetime_revenue
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        l.lifetime_revenue,

        a.active_months,

        i.max_inactive_days,

        a.reactivation_count,

        s.longest_purchase_streak

    FROM dim_customers c

    JOIN lifetime_revenue l
        ON c.customer_id = l.customer_id

    JOIN customer_activity a
        ON c.customer_id = a.customer_id

    JOIN inactivity i
        ON c.customer_id = i.customer_id

    JOIN longest_streak s
        ON c.customer_id = s.customer_id

    CROSS JOIN average_revenue ar

    WHERE l.lifetime_revenue > ar.avg_customer_revenue
      AND a.active_months >= 4
      AND i.max_inactive_days >= 60
      AND a.reactivation_count >= 1
      AND s.longest_purchase_streak >= 3
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
    max_inactive_days,
    reactivation_count,
    longest_purchase_streak,
    regional_rank

FROM ranked_customers

WHERE regional_rank <= 5

ORDER BY
    region,
    regional_rank;


 /*Question 3/4 — Product Category Performance

Identify products that are dominant within their category.

A product qualifies if:

Lifetime revenue is above its category's average product revenue.
It contributes at least 15% of category revenue.
It has a 3-month consecutive revenue-growth streak.
Its latest month's revenue is higher than the previous month.
Return the top 3 products per category.*/

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

growth_islands AS
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

        AVG(lifetime_revenue) OVER
        (
            PARTITION BY category
        ) AS category_average_revenue,

        SUM(lifetime_revenue) OVER
        (
            PARTITION BY category
        ) AS category_total_revenue

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
        c.category_average_revenue,

        ROUND(
            c.lifetime_revenue * 100.0
            / NULLIF(c.category_total_revenue, 0),
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

    WHERE lifetime_revenue > category_average_revenue
      AND category_contribution_pct >= 15
      AND longest_growth_streak >= 3
      AND latest_mom_growth > 0
)

SELECT
    product_id,
    product_name,
    category,
    lifetime_revenue,
    category_average_revenue,
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

/*Question 4/4 — Regional Salesperson Performance
Requirement

For each salesperson:

Calculate monthly revenue.
Calculate MoM growth.
Calculate yearly revenue.
Calculate YoY growth.
Calculate their 3-month rolling revenue.
Calculate their longest consecutive monthly growth streak.
Calculate their contribution to regional revenue.
Find their highest-revenue quarter.
Rank salespeople within each region.*/

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
        ) AS previous_month_revenue,

        LAG(sales_month) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_month
        ) AS previous_month

    FROM monthly_sales
),

monthly_metrics AS
(
    SELECT
        *,

        ROUND(
            (monthly_revenue - previous_month_revenue)
            * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        AVG(monthly_revenue) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_month_revenue,

        CASE
            WHEN previous_month =
                 sales_month - INTERVAL '1 month'
                 AND monthly_revenue > previous_month_revenue
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
            CASE
                WHEN growth_flag = 0 THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_month
        ) AS island_id

    FROM monthly_metrics
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

latest_month AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY salesperson_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM monthly_metrics
),

salesperson_profile AS
(
    SELECT DISTINCT
        m.salesperson_id,
        m.salesperson_name,
        m.region,

        g.longest_growth_streak,

        y.sales_year,
        y.yearly_revenue,
        y.yoy_growth,

        m.rolling_3_month_revenue,

        q.sales_quarter,
        q.quarterly_revenue AS highest_quarterly_revenue,

        r.regional_contribution_pct

    FROM latest_month m

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

    WHERE m.rn = 1
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
    salesperson_id,
    salesperson_name,
    region,
    longest_growth_streak,
    sales_year,
    yearly_revenue,
    yoy_growth,
    rolling_3_month_revenue,
    sales_quarter,
    highest_quarterly_revenue,
    regional_contribution_pct,
    regional_rank

FROM ranked_salespeople

WHERE regional_rank <= 3

ORDER BY
    region,
    regional_rank;

