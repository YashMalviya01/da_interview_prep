/*Q1 — Department Headcount & Salary

Grain: one row per department

Tables: dim_employees, dim_departments

Find departments with:

Total employees
Average salary
Maximum salary
Minimum salary
Total salary expense
Percentage of company's total salary expense

Return only departments with above-company-average employee count, ranked by total salary expense.*/


WITH department_metrics AS
(
    SELECT
        d.department_id,
        d.department_name,

        COUNT(e.employee_id) AS employee_count,

        AVG(e.salary) AS avg_salary,

        MAX(e.salary) AS max_salary,

        MIN(e.salary) AS min_salary,

        SUM(e.salary) AS total_salary

    FROM dim_departments d

    LEFT JOIN dim_employees e
        ON d.department_id = e.department_id

    GROUP BY
        d.department_id,
        d.department_name
),

company_metrics AS
(
    SELECT
        AVG(employee_count) AS avg_employee_count,
        SUM(total_salary) AS company_total_salary

    FROM department_metrics
),

ranked_departments AS
(
    SELECT
        d.*,

        ROUND(
            d.total_salary * 100.0
            / NULLIF(c.company_total_salary, 0),
            2
        ) AS salary_contribution_pct,

        ROW_NUMBER() OVER (
            ORDER BY d.total_salary DESC
        ) AS salary_rank

    FROM department_metrics d

    CROSS JOIN company_metrics c

    WHERE d.employee_count > c.avg_employee_count
)

SELECT
    department_id,
    department_name,
    employee_count,
    ROUND(avg_salary, 2) AS avg_salary,
    max_salary,
    min_salary,
    total_salary,
    salary_contribution_pct,
    salary_rank

FROM ranked_departments

ORDER BY salary_rank;



/*Q2 — Monthly Product Revenue Growth

Grain: one row per product per month

Find products whose revenue increased for at least 2 consecutive months.

Return the latest month, latest revenue, previous revenue, MoM growth and longest growth streak.*/

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

growth_metrics AS
(
    SELECT
        *,

        LAG(monthly_revenue) OVER (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_revenue

    FROM monthly_product_sales
),

growth_flags AS
(
    SELECT
        *,

        CASE
            WHEN previous_revenue IS NOT NULL
                 AND monthly_revenue > previous_revenue
            THEN 1
            ELSE 0
        END AS growth_flag

    FROM growth_metrics
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

    FROM growth_islands

    WHERE growth_flag = 1

    GROUP BY
        product_id,
        island_id
),

max_streak AS
(
    SELECT
        product_id,
        MAX(streak_length) AS longest_growth_streak

    FROM streaks

    GROUP BY product_id
),

latest_product_month AS
(
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM growth_metrics
)

SELECT
    l.product_id,
    l.product_name,
    l.category,
    l.sales_month AS latest_month,
    l.monthly_revenue,
    l.previous_revenue,

    ROUND(
        (l.monthly_revenue - l.previous_revenue)
        * 100.0
        / NULLIF(l.previous_revenue, 0),
        2
    ) AS mom_growth,

    COALESCE(
        s.longest_growth_streak,
        0
    ) AS longest_growth_streak

FROM latest_product_month l

LEFT JOIN max_streak s
    ON l.product_id = s.product_id

WHERE l.rn = 1
  AND COALESCE(s.longest_growth_streak, 0) >= 2

ORDER BY
    longest_growth_streak DESC,
    monthly_revenue DESC;


/*Q3 — Customer Retention by Cohort

Grain: one row per cohort month × month number

Calculate the number of customers retained in each month after acquisition.*/

WITH customer_months AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', order_date) AS sales_month

    FROM fact_sales
),

customer_cohorts AS
(
    SELECT
        customer_id,

        MIN(sales_month) OVER (
            PARTITION BY customer_id
        ) AS cohort_month,

        sales_month

    FROM customer_months
),

cohort_activity AS
(
    SELECT
        cohort_month,
        sales_month,

        (
            EXTRACT(YEAR FROM AGE(
                sales_month,
                cohort_month
            )) * 12
            +
            EXTRACT(MONTH FROM AGE(
                sales_month,
                cohort_month
            ))
        ) AS months_since_acquisition,

        COUNT(DISTINCT customer_id)
            AS active_customers

    FROM customer_cohorts

    GROUP BY
        cohort_month,
        sales_month
),

cohort_size AS
(
    SELECT
        cohort_month,
        active_customers AS cohort_customers

    FROM cohort_activity

    WHERE months_since_acquisition = 0
)

SELECT
    a.cohort_month,
    a.months_since_acquisition,
    a.active_customers,
    c.cohort_customers,

    ROUND(
        a.active_customers * 100.0
        / NULLIF(c.cohort_customers, 0),
        2
    ) AS retention_rate

FROM cohort_activity a

JOIN cohort_size c
    ON a.cohort_month = c.cohort_month

ORDER BY
    a.cohort_month,
    a.months_since_acquisition;


/*Q4 — Salesperson Performance
Find salespeople who:

Generated revenue above their regional average
Have at least 50 orders
Rank in the top 3 within their region*/


WITH salesperson_metrics AS
(
    SELECT
        s.salesperson_id,
        s.salesperson_name,
        s.region,

        COUNT(DISTINCT f.order_id)
            AS total_orders,

        SUM(f.sales_amount)
            AS total_revenue

    FROM fact_sales f

    JOIN dim_salespersons s
        ON f.salesperson_id = s.salesperson_id

    GROUP BY
        s.salesperson_id,
        s.salesperson_name,
        s.region
),

regional_metrics AS
(
    SELECT
        *,

        AVG(total_revenue) OVER (
            PARTITION BY region
        ) AS regional_avg_revenue

    FROM salesperson_metrics
),

ranked_salespeople AS
(
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY region
            ORDER BY total_revenue DESC
        ) AS regional_rank

    FROM regional_metrics

    WHERE total_orders >= 50
      AND total_revenue > regional_avg_revenue
)

SELECT
    salesperson_id,
    salesperson_name,
    region,
    total_orders,
    total_revenue,
    regional_avg_revenue,
    regional_rank

FROM ranked_salespeople

WHERE regional_rank <= 3

ORDER BY
    region,
    regional_rank;


/*Q5 — MEGA QUERY: Customer Revenue + Retention + Product Intelligence

This one is the hardest of today's five.

Final grain: one row per customer.

Calculate:

Lifetime revenue
Lifetime orders
First purchase
Latest purchase
Cohort
Months since acquisition
Previous-month revenue
MoM growth
3-month rolling revenue
Revenue rank within region
Favorite product category
Category revenue contribution
Number of active months
Retention rate
Customer value segment
Customer health

Then return the top 5 qualified customers in each region.*/

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
        ) AS mom_growth

    FROM monthly_metrics
),

customer_lifetime AS
(
    SELECT
        customer_id,

        MIN(order_date) AS first_purchase_date,
        MAX(order_date) AS latest_purchase_date,

        COUNT(DISTINCT order_id)
            AS lifetime_orders,

        SUM(sales_amount)
            AS lifetime_revenue

    FROM fact_sales

    GROUP BY customer_id
),

customer_activity AS
(
    SELECT
        customer_id,

        COUNT(DISTINCT sales_month)
            AS active_months

    FROM customer_monthly

    GROUP BY customer_id
),

favorite_category_base AS
(
    SELECT
        f.customer_id,
        p.category,

        SUM(f.sales_amount)
            AS category_revenue

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        f.customer_id,
        p.category
),

favorite_category_ranked AS
(
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY category_revenue DESC
        ) AS rn

    FROM favorite_category_base
),

favorite_category AS
(
    SELECT
        f.customer_id,
        f.category AS favorite_category,
        f.category_revenue AS favorite_category_revenue,

        ROUND(
            f.category_revenue * 100.0
            / NULLIF(l.lifetime_revenue, 0),
            2
        ) AS favorite_category_pct

    FROM favorite_category_ranked f

    JOIN customer_lifetime l
        ON f.customer_id = l.customer_id

    WHERE f.rn = 1
),

overall_metrics AS
(
    SELECT
        AVG(lifetime_revenue)
            AS avg_customer_revenue,

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (
            ORDER BY lifetime_revenue
        ) AS p75_revenue,

        PERCENTILE_CONT(0.90)
        WITHIN GROUP (
            ORDER BY lifetime_revenue
        ) AS p90_revenue

    FROM customer_lifetime
),

latest_customer_month AS
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

        l.first_purchase_date,
        l.latest_purchase_date,

        l.lifetime_orders,
        l.lifetime_revenue,

        a.active_months,

        lm.sales_month AS latest_month,

        lm.monthly_revenue
            AS latest_month_revenue,

        lm.previous_month_revenue,

        lm.mom_growth,

        lm.rolling_3m_revenue,

        lm.cumulative_revenue,

        fc.favorite_category,
        fc.favorite_category_revenue,
        fc.favorite_category_pct,

        CASE
            WHEN l.lifetime_revenue >= o.p90_revenue
                THEN 'VIP'

            WHEN l.lifetime_revenue >= o.p75_revenue
                THEN 'HIGH VALUE'

            ELSE 'STANDARD'
        END AS customer_value_segment

    FROM dim_customers c

    JOIN customer_lifetime l
        ON c.customer_id = l.customer_id

    JOIN customer_activity a
        ON c.customer_id = a.customer_id

    JOIN latest_customer_month lm
        ON c.customer_id = lm.customer_id
       AND lm.rn = 1

    LEFT JOIN favorite_category fc
        ON c.customer_id = fc.customer_id

    CROSS JOIN overall_metrics o
),

regional_ranking AS
(
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY region
            ORDER BY lifetime_revenue DESC
        ) AS regional_rank

    FROM customer_profile
),

final_classification AS
(
    SELECT
        *,

        CASE
            WHEN mom_growth > 0
                 AND active_months >= 3
            THEN 'HEALTHY'

            WHEN mom_growth <= 0
            THEN 'AT RISK'

            ELSE 'STABLE'
        END AS customer_health

    FROM regional_ranking
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,

    cohort_month,

    first_purchase_date,
    latest_purchase_date,

    lifetime_orders,
    lifetime_revenue,

    active_months,

    latest_month,
    latest_month_revenue,
    previous_month_revenue,
    mom_growth,

    rolling_3m_revenue,
    cumulative_revenue,

    favorite_category,
    favorite_category_revenue,
    favorite_category_pct,

    customer_value_segment,
    customer_health,

    regional_rank

FROM final_classification

WHERE regional_rank <= 5

  AND lifetime_revenue >
      (
          SELECT AVG(lifetime_revenue)
          FROM customer_lifetime
      )

ORDER BY
    region,
    regional_rank;
