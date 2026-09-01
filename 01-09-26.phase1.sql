/*Q1 — Customer Revenue & Churn Risk

Grain: one row per customer

Tables: fact_sales, dim_customers

Calculate:

Lifetime revenue
Total orders
First/latest purchase
Average order value
Active purchase months
Previous purchase date
Average days between purchases
Days since latest purchase
Latest-month revenue
Previous-month revenue
MoM growth
3-month rolling revenue
Growth streak
Customer status

Return the top 5 customers per region where:

Lifetime revenue > overall average
Latest MoM growth > 0
Growth streak >= 3
Days since latest purchase < 60*/


WITH customer_monthly AS
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

monthly_metrics AS
(
    SELECT
        *,
        LAG(monthly_revenue) OVER (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month_revenue,

        AVG(monthly_revenue) OVER (
            PARTITION BY customer_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3m_revenue
    FROM customer_monthly
),

growth_flags AS
(
    SELECT
        *,
        ROUND(
            (monthly_revenue - previous_month_revenue) * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        CASE
            WHEN monthly_revenue > previous_month_revenue
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
        ) OVER (
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
    GROUP BY customer_id, island_id
),

max_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_growth_streak
    FROM streaks
    GROUP BY customer_id
),

order_metrics AS
(
    SELECT
        customer_id,
        MIN(order_date) AS first_purchase_date,
        MAX(order_date) AS latest_purchase_date,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(sales_amount) AS lifetime_revenue,

        COUNT(
            DISTINCT DATE_TRUNC('month', order_date)
        ) AS active_months
    FROM fact_sales
    GROUP BY customer_id
),

purchase_gaps AS
(
    SELECT
        customer_id,
        order_date,

        LAG(order_date) OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS previous_purchase_date
    FROM fact_sales
),

average_gaps AS
(
    SELECT
        customer_id,
        AVG(
            order_date - previous_purchase_date
        ) AS avg_days_between_purchases
    FROM purchase_gaps
    WHERE previous_purchase_date IS NOT NULL
    GROUP BY customer_id
),

latest_month AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY sales_month DESC
        ) AS rn
    FROM growth_flags
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        o.first_purchase_date,
        o.latest_purchase_date,
        o.total_orders,
        o.lifetime_revenue,
        o.active_months,

        o.lifetime_revenue
            / NULLIF(o.total_orders, 0)
            AS average_order_value,

        g.avg_days_between_purchases,

        CURRENT_DATE - o.latest_purchase_date
            AS days_since_latest_purchase,

        l.sales_month AS latest_month,
        l.monthly_revenue AS latest_month_revenue,
        l.previous_month_revenue,
        l.mom_growth,
        l.rolling_3m_revenue,

        COALESCE(s.longest_growth_streak, 0)
            AS longest_growth_streak

    FROM dim_customers c

    JOIN order_metrics o
        ON c.customer_id = o.customer_id

    LEFT JOIN average_gaps g
        ON c.customer_id = g.customer_id

    JOIN latest_month l
        ON c.customer_id = l.customer_id
       AND l.rn = 1

    LEFT JOIN max_streak s
        ON c.customer_id = s.customer_id
),

ranked AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY region
            ORDER BY lifetime_revenue DESC
        ) AS regional_rank
    FROM customer_profile
),

final AS
(
    SELECT
        *,
        CASE
            WHEN mom_growth > 0
                 AND longest_growth_streak >= 3
            THEN 'GROWING'

            WHEN days_since_latest_purchase >= 60
            THEN 'AT RISK'

            WHEN active_months >= 6
            THEN 'LOYAL'

            ELSE 'STABLE'
        END AS customer_status
    FROM ranked
)

SELECT *
FROM final
WHERE regional_rank <= 5
  AND lifetime_revenue >
      (
          SELECT AVG(lifetime_revenue)
          FROM order_metrics
      )
  AND mom_growth > 0
  AND longest_growth_streak >= 3
  AND days_since_latest_purchase < 60
ORDER BY region, regional_rank;


/*Q2 — Product Performance & Category Leaders

Grain: one row per product per month.

Calculate:

Monthly revenue
Monthly orders
Previous-month revenue
MoM growth
3-month rolling revenue
Category monthly revenue
Category revenue contribution
Product rank within category
Product's best revenue month
Number of months with positive growth

Return products from the latest month where:

MoM growth > 0
Category contribution >= 10%
Rank <= 3
Positive-growth months >= 3*/

WITH product_monthly AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,

        DATE_TRUNC('month', f.order_date) AS sales_month,

        SUM(f.sales_amount) AS monthly_revenue,

        COUNT(DISTINCT f.order_id) AS monthly_orders

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

        LAG(monthly_revenue) OVER (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_month_revenue,

        AVG(monthly_revenue) OVER (
            PARTITION BY product_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3m_revenue,

        SUM(monthly_revenue) OVER (
            PARTITION BY category, sales_month
        ) AS category_monthly_revenue

    FROM product_monthly
),

product_metrics AS
(
    SELECT
        *,

        ROUND(
            (monthly_revenue - previous_month_revenue) * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        ROUND(
            monthly_revenue * 100.0
            / NULLIF(category_monthly_revenue, 0),
            2
        ) AS category_contribution_pct,

        ROW_NUMBER() OVER (
            PARTITION BY category, sales_month
            ORDER BY monthly_revenue DESC
        ) AS product_rank,

        MAX(monthly_revenue) OVER (
            PARTITION BY product_id
        ) AS highest_monthly_revenue,

        SUM(
            CASE
                WHEN monthly_revenue > previous_month_revenue
                THEN 1
                ELSE 0
            END
        ) OVER (
            PARTITION BY product_id
        ) AS positive_growth_months

    FROM monthly_metrics
),

latest_month AS
(
    SELECT
        MAX(sales_month) AS latest_sales_month
    FROM product_metrics
)

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.sales_month,
    p.monthly_revenue,
    p.monthly_orders,
    p.previous_month_revenue,
    p.mom_growth,
    p.rolling_3m_revenue,
    p.category_monthly_revenue,
    p.category_contribution_pct,
    p.product_rank,
    p.highest_monthly_revenue,
    p.positive_growth_months

FROM product_metrics p

CROSS JOIN latest_month l

WHERE p.sales_month = l.latest_sales_month
  AND p.mom_growth > 0
  AND p.category_contribution_pct >= 10
  AND p.product_rank <= 3
  AND p.positive_growth_months >= 3

ORDER BY
    p.category,
    p.product_rank;

/*Q3 — Employee Compensation Intelligence

Grain: one row per employee.

Tables: dim_employees, dim_department

Find employees who:

Earn below their department average salary
Have performance above department average
Have performance above company average
Are in the top 3 performers of their department

Calculate:

Department average salary
Department average performance
Company average salary
Company average performance
Salary difference from department
Performance difference from department
Performance percentile
Department rank
Salary position
Compensation classification

Then return the top 5 employees across the company based on performance score, breaking ties with lower salary.*/ 


WITH employee_metrics AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        e.department_id,
        d.department_name,
        e.salary,
        e.performance_score,

        AVG(e.salary) OVER (
            PARTITION BY e.department_id
        ) AS department_avg_salary,

        AVG(e.performance_score) OVER (
            PARTITION BY e.department_id
        ) AS department_avg_performance,

        AVG(e.salary) OVER ()
            AS company_avg_salary,

        AVG(e.performance_score) OVER ()
            AS company_avg_performance,

        PERCENT_RANK() OVER (
            ORDER BY e.performance_score
        ) AS performance_percentile

    FROM dim_employees e

    JOIN dim_department d
        ON e.department_id = d.department_id
),

qualified_employees AS
(
    SELECT
        *,

        salary - department_avg_salary
            AS salary_difference,

        performance_score - department_avg_performance
            AS performance_difference,

        ROW_NUMBER() OVER (
            PARTITION BY department_id
            ORDER BY
                performance_score DESC,
                salary ASC
        ) AS department_rank,

        CASE
            WHEN salary < department_avg_salary
                 AND performance_score > department_avg_performance
            THEN 'UNDERPAID_HIGH_PERFORMER'

            WHEN salary >= department_avg_salary
                 AND performance_score > department_avg_performance
            THEN 'HIGH_PERFORMER'

            WHEN salary < department_avg_salary
            THEN 'LOW_COST'

            ELSE 'STANDARD'
        END AS compensation_classification

    FROM employee_metrics

    WHERE performance_score > department_avg_performance
      AND performance_score > company_avg_performance
      AND salary < department_avg_salary
),

company_ranking AS
(
    SELECT
        *,

        ROW_NUMBER() OVER (
            ORDER BY
                performance_score DESC,
                salary ASC
        ) AS company_rank

    FROM qualified_employees

    WHERE department_rank <= 3
)

SELECT
    employee_id,
    employee_name,
    department_id,
    department_name,
    salary,
    performance_score,

    department_avg_salary,
    department_avg_performance,

    company_avg_salary,
    company_avg_performance,

    salary_difference,
    performance_difference,

    ROUND(
        performance_percentile * 100,
        2
    ) AS performance_percentile,

    department_rank,
    company_rank,

    compensation_classification

FROM company_ranking

WHERE company_rank <= 5

ORDER BY company_rank;
