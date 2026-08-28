/*Q1 — Employee Salary Analysis

Grain: one row per employee

Tables: dim_employees, dim_departments

Find employees whose salary is above their department average but below the company average. Rank them within their department and return the top 5.*/

WITH employee_metrics AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        d.department_name,
        e.department_id,
        e.salary,

        AVG(e.salary) OVER (
            PARTITION BY e.department_id
        ) AS department_avg_salary,

        AVG(e.salary) OVER () AS company_avg_salary

    FROM dim_employees e

    JOIN dim_departments d
        ON e.department_id = d.department_id
),

filtered_employees AS
(
    SELECT
        *,
        salary - department_avg_salary
            AS salary_difference

    FROM employee_metrics

    WHERE salary > department_avg_salary
      AND salary < company_avg_salary
),

ranked_employees AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY department_id
            ORDER BY salary DESC
        ) AS department_rank

    FROM filtered_employees
)

SELECT
    employee_id,
    employee_name,
    department_name,
    salary,
    department_avg_salary,
    company_avg_salary,
    salary_difference,
    department_rank

FROM ranked_employees

WHERE department_rank <= 5

ORDER BY
    department_name,
    department_rank;


 /*Q2 — Monthly Revenue With New vs Returning Customers

Grain: one row per month

Calculate monthly revenue, orders, customers, new customers, returning customers and their revenue.*/

WITH first_purchase AS
(
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date))
            AS first_purchase_month

    FROM fact_sales

    GROUP BY customer_id
),

monthly_customer_sales AS
(
    SELECT
        DATE_TRUNC('month', f.order_date)
            AS sales_month,

        f.customer_id,

        COUNT(DISTINCT f.order_id)
            AS total_orders,

        SUM(f.sales_amount)
            AS customer_revenue

    FROM fact_sales f

    GROUP BY
        DATE_TRUNC('month', f.order_date),
        f.customer_id
),

monthly_metrics AS
(
    SELECT
        m.sales_month,

        COUNT(DISTINCT m.customer_id)
            AS unique_customers,

        SUM(m.total_orders)
            AS total_orders,

        SUM(m.customer_revenue)
            AS total_revenue,

        SUM(
            CASE
                WHEN m.sales_month = fp.first_purchase_month
                THEN 1
                ELSE 0
            END
        ) AS new_customers,

        SUM(
            CASE
                WHEN m.sales_month > fp.first_purchase_month
                THEN 1
                ELSE 0
            END
        ) AS returning_customers,

        SUM(
            CASE
                WHEN m.sales_month = fp.first_purchase_month
                THEN m.customer_revenue
                ELSE 0
            END
        ) AS new_customer_revenue,

        SUM(
            CASE
                WHEN m.sales_month > fp.first_purchase_month
                THEN m.customer_revenue
                ELSE 0
            END
        ) AS returning_customer_revenue

    FROM monthly_customer_sales m

    JOIN first_purchase fp
        ON m.customer_id = fp.customer_id

    GROUP BY m.sales_month
)

SELECT
    sales_month,
    unique_customers,
    total_orders,
    total_revenue,
    ROUND(
        total_revenue / NULLIF(total_orders, 0),
        2
    ) AS average_order_value,
    new_customers,
    returning_customers,
    new_customer_revenue,
    returning_customer_revenue

FROM monthly_metrics

ORDER BY sales_month;


/*Q3 — Top Products Within Each Category

Grain: one row per product

Return the top 3 products in each category based on revenue, while also showing each product's percentage contribution to category revenue.*/

WITH product_revenue AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,

        SUM(f.sales_amount)
            AS product_revenue

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

        SUM(product_revenue) OVER (
            PARTITION BY category
        ) AS category_revenue

    FROM product_revenue
),

ranked_products AS
(
    SELECT
        *,

        ROUND(
            product_revenue * 100.0
            / NULLIF(category_revenue, 0),
            2
        ) AS category_contribution_pct,

        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY product_revenue DESC
        ) AS product_rank

    FROM category_metrics
)

SELECT
    product_id,
    product_name,
    category,
    product_revenue,
    category_revenue,
    category_contribution_pct,
    product_rank

FROM ranked_products

WHERE product_rank <= 3

ORDER BY
    category,
    product_rank;


 /*Q4 — Customer Purchase Gap Analysis

Grain: one row per customer

Find customers whose latest purchase gap is larger than their historical average purchase interval.*/

WITH customer_orders AS
(
    SELECT
        customer_id,
        order_date,

        LAG(order_date) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS previous_order_date

    FROM fact_sales
),

purchase_intervals AS
(
    SELECT
        customer_id,
        order_date,
        previous_order_date,

        order_date - previous_order_date
            AS days_between_orders

    FROM customer_orders

    WHERE previous_order_date IS NOT NULL
),

customer_metrics AS
(
    SELECT
        customer_id,

        AVG(days_between_orders)
            AS avg_purchase_interval,

        MAX(order_date)
            AS latest_purchase_date

    FROM purchase_intervals

    GROUP BY customer_id
),

latest_gap AS
(
    SELECT
        c.customer_id,
        c.avg_purchase_interval,
        c.latest_purchase_date,

        CURRENT_DATE - c.latest_purchase_date
            AS days_since_latest_purchase

    FROM customer_metrics c
)

SELECT
    customer_id,
    latest_purchase_date,
    ROUND(avg_purchase_interval, 2)
        AS avg_purchase_interval,
    days_since_latest_purchase,

    CASE
        WHEN days_since_latest_purchase >
             avg_purchase_interval * 2
        THEN 'AT RISK'
        ELSE 'ACTIVE'
    END AS customer_status

FROM latest_gap

ORDER BY
    days_since_latest_purchase DESC;

/*Q5 — MEGA QUERY: Customer Revenue Intelligence

This one combines grain, joins, aggregation, LAG, MoM, rolling metrics, lifetime revenue, cohort, streaks, segmentation, latest-month analysis and ranking.*/


WITH customer_monthly AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        DATE_TRUNC('month', f.order_date)
            AS sales_month,

        SUM(f.sales_amount)
            AS monthly_revenue,

        COUNT(DISTINCT f.order_id)
            AS monthly_orders

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

monthly_metrics AS
(
    SELECT
        *,

        LAG(monthly_revenue) OVER (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month_revenue,

        MIN(sales_month) OVER (
            PARTITION BY customer_id
        ) AS cohort_month,

        AVG(monthly_revenue) OVER (
            PARTITION BY customer_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3m_revenue,

        SUM(monthly_revenue) OVER (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS cumulative_revenue

    FROM customer_monthly
),

growth_metrics AS
(
    SELECT
        *,

        ROUND(
            (monthly_revenue - previous_month_revenue)
            * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        CASE
            WHEN previous_month_revenue IS NOT NULL
                 AND monthly_revenue > previous_month_revenue
            THEN 1
            ELSE 0
        END AS growth_flag

    FROM monthly_metrics
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
        ) OVER (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS island_id

    FROM growth_metrics
),

growth_streaks AS
(
    SELECT
        customer_id,
        island_id,
        COUNT(*) AS streak_length

    FROM growth_islands

    WHERE growth_flag = 1

    GROUP BY
        customer_id,
        island_id
),

longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length)
            AS longest_growth_streak

    FROM growth_streaks

    GROUP BY customer_id
),

lifetime_metrics AS
(
    SELECT
        customer_id,

        SUM(sales_amount)
            AS lifetime_revenue,

        COUNT(DISTINCT order_id)
            AS lifetime_orders,

        MIN(order_date)
            AS first_purchase_date,

        MAX(order_date)
            AS latest_purchase_date

    FROM fact_sales

    GROUP BY customer_id
),

customer_averages AS
(
    SELECT
        AVG(lifetime_revenue)
            AS overall_avg_lifetime_revenue,

        PERCENTILE_CONT(0.50)
        WITHIN GROUP (
            ORDER BY lifetime_revenue
        ) AS p50_revenue,

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (
            ORDER BY lifetime_revenue
        ) AS p75_revenue,

        PERCENTILE_CONT(0.90)
        WITHIN GROUP (
            ORDER BY lifetime_revenue
        ) AS p90_revenue

    FROM lifetime_metrics
),

customer_segments AS
(
    SELECT
        l.customer_id,
        l.lifetime_revenue,
        l.lifetime_orders,
        l.first_purchase_date,
        l.latest_purchase_date,

        CASE
            WHEN l.lifetime_revenue >= a.p90_revenue
                THEN 'VIP'

            WHEN l.lifetime_revenue >= a.p75_revenue
                THEN 'HIGH VALUE'

            WHEN l.lifetime_revenue >= a.p50_revenue
                THEN 'MEDIUM VALUE'

            ELSE 'LOW VALUE'
        END AS customer_value_segment

    FROM lifetime_metrics l

    CROSS JOIN customer_averages a
),

latest_month AS
(
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM growth_metrics
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        lm.cohort_month,

        cs.lifetime_revenue,
        cs.lifetime_orders,

        cs.first_purchase_date,
        cs.latest_purchase_date,

        lm.sales_month AS latest_sales_month,

        lm.monthly_revenue
            AS latest_month_revenue,

        lm.previous_month_revenue,

        lm.mom_growth,

        lm.rolling_3m_revenue,

        lm.cumulative_revenue,

        COALESCE(
            ls.longest_growth_streak,
            0
        ) AS longest_growth_streak,

        cs.customer_value_segment

    FROM dim_customers c

    JOIN customer_segments cs
        ON c.customer_id = cs.customer_id

    JOIN latest_month lm
        ON c.customer_id = lm.customer_id
       AND lm.rn = 1

    LEFT JOIN longest_streak ls
        ON c.customer_id = ls.customer_id
),

ranked_customers AS
(
    SELECT
        *,

        CASE
            WHEN mom_growth > 0
                 AND longest_growth_streak >= 3
            THEN 'GROWING'

            WHEN mom_growth > 0
            THEN 'IMPROVING'

            WHEN mom_growth <= 0
            THEN 'DECLINING'

            ELSE 'NO DATA'
        END AS customer_status,

        ROW_NUMBER() OVER (
            PARTITION BY region
            ORDER BY lifetime_revenue DESC
        ) AS regional_rank

    FROM customer_profile
),

final_output AS
(
    SELECT
        r.*,

        CASE
            WHEN lifetime_revenue >
                 a.overall_avg_lifetime_revenue
                 AND longest_growth_streak >= 3
                 AND regional_rank <= 5
            THEN 'QUALIFIED'

            ELSE 'NOT QUALIFIED'
        END AS qualification_status

    FROM ranked_customers r

    CROSS JOIN customer_averages a
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,

    cohort_month,

    lifetime_revenue,
    lifetime_orders,

    first_purchase_date,
    latest_purchase_date,

    latest_sales_month,
    latest_month_revenue,
    previous_month_revenue,
    mom_growth,

    rolling_3m_revenue,
    cumulative_revenue,

    longest_growth_streak,

    customer_value_segment,
    customer_status,

    regional_rank,
    qualification_status

FROM final_output

WHERE qualification_status = 'QUALIFIED'

ORDER BY
    region,
    regional_rank;
