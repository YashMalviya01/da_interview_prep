/*Q1 — Employee Department Analysis
Task

Find employees whose salary is:

Greater than their department's average salary
But less than the company's overall average salary

Also calculate:

Salary difference from department average
Employee's salary rank within department*/

WITH employee_metrics AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        e.department_id,
        d.department_name,
        e.salary,

        AVG(e.salary) OVER
        (
            PARTITION BY e.department_id
        ) AS department_avg_salary,

        AVG(e.salary) OVER () AS company_avg_salary

    FROM dim_employees e

    JOIN dim_departments d
        ON e.department_id = d.department_id
),

salary_difference AS
(
    SELECT
        *,
        salary - department_avg_salary AS salary_difference

    FROM employee_metrics
),

filtered_employees AS
(
    SELECT
        *

    FROM salary_difference

    WHERE salary > department_avg_salary
      AND salary < company_avg_salary
),

ranked_employees AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY department_id
            ORDER BY salary DESC
        ) AS rn

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
    rn AS department_rank

FROM ranked_employees

WHERE rn <= 5

ORDER BY
    department_name,
    department_rank;

/*Q2 — Monthly Customer Order Behavior*/ 


WITH customer_first_purchase AS
(
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) AS first_purchase_month
    FROM fact_sales
    GROUP BY customer_id
),

monthly_customer_sales AS
(
    SELECT
        DATE_TRUNC('month', f.order_date) AS sales_month,
        f.customer_id,
        SUM(f.sales_amount) AS customer_revenue,
        COUNT(DISTINCT f.order_id) AS customer_orders
    FROM fact_sales f
    GROUP BY
        DATE_TRUNC('month', f.order_date),
        f.customer_id
),

monthly_summary AS
(
    SELECT
        m.sales_month,

        COUNT(DISTINCT m.customer_id) AS unique_customers,

        SUM(m.customer_orders) AS total_orders,

        SUM(m.customer_revenue) AS total_revenue,

        SUM(m.customer_revenue)
            / NULLIF(SUM(m.customer_orders), 0)
            AS average_order_value,

        COUNT(
            CASE
                WHEN m.sales_month = c.first_purchase_month
                THEN m.customer_id
            END
        ) AS new_customers,

        COUNT(
            CASE
                WHEN m.sales_month > c.first_purchase_month
                THEN m.customer_id
            END
        ) AS returning_customers,

        SUM(
            CASE
                WHEN m.sales_month = c.first_purchase_month
                THEN m.customer_revenue
                ELSE 0
            END
        ) AS new_customer_revenue,

        SUM(
            CASE
                WHEN m.sales_month > c.first_purchase_month
                THEN m.customer_revenue
                ELSE 0
            END
        ) AS returning_customer_revenue

    FROM monthly_customer_sales m

    JOIN customer_first_purchase c
        ON m.customer_id = c.customer_id

    GROUP BY m.sales_month
)

SELECT
    sales_month,
    unique_customers,
    total_orders,
    total_revenue,
    average_order_value,
    new_customers,
    returning_customers,
    new_customer_revenue,
    returning_customer_revenue
FROM monthly_summary
ORDER BY sales_month;


/*Q3 — Product Performance vs Category*/

WITH product_revenue AS
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

    FROM product_revenue
),

product_metrics AS
(
    SELECT
        *,

        ROUND(
            lifetime_revenue * 100.0
            / NULLIF(category_revenue, 0),
            2
        ) AS category_contribution_pct,

        ROUND(
            (lifetime_revenue - category_avg_revenue)
            * 100.0
            / NULLIF(category_avg_revenue, 0),
            2
        ) AS revenue_vs_category_avg_pct

    FROM category_metrics
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

    FROM product_metrics

    WHERE lifetime_revenue > category_avg_revenue

      AND category_contribution_pct >= 5
)

SELECT
    product_id,
    product_name,
    category,
    lifetime_revenue,
    category_avg_revenue,
    category_revenue,
    category_contribution_pct,
    revenue_vs_category_avg_pct,
    category_rank

FROM ranked_products

ORDER BY
    category,
    category_rank;


/*Q4 — Customer Churn Detection*/

WITH customer_orders AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        sales_amount,

        LAG(order_date) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS previous_order_date

    FROM fact_sales
),

customer_intervals AS
(
    SELECT
        *,

        order_date - previous_order_date
            AS days_between_orders

    FROM customer_orders

    WHERE previous_order_date IS NOT NULL
),

customer_metrics AS
(
    SELECT
        customer_id,

        MIN(order_date) AS first_purchase_date,

        MAX(order_date) AS latest_purchase_date,

        COUNT(DISTINCT order_id) AS total_orders,

        SUM(sales_amount) AS lifetime_revenue,

        AVG(days_between_orders)
            AS avg_purchase_interval

    FROM customer_intervals ci

    JOIN fact_sales f
        ON ci.customer_id = f.customer_id

    GROUP BY customer_id
),

customer_days AS
(
    SELECT
        *,

        CURRENT_DATE - latest_purchase_date
            AS days_since_latest_purchase,

        latest_purchase_date - first_purchase_date
            AS customer_lifetime_days

    FROM customer_metrics
),

overall_average AS
(
    SELECT
        AVG(lifetime_revenue) AS overall_avg_lifetime_revenue

    FROM customer_days
),

churned_customers AS
(
    SELECT
        c.*,

        CASE
            WHEN days_since_latest_purchase >
                 avg_purchase_interval * 2
            THEN 1
            ELSE 0
        END AS churn_flag

    FROM customer_days c

    CROSS JOIN overall_average a

    WHERE c.lifetime_revenue >
          a.overall_avg_lifetime_revenue
),

ranked_customers AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        ch.first_purchase_date,
        ch.latest_purchase_date,
        ch.lifetime_revenue,
        ch.total_orders,
        ch.avg_purchase_interval,
        ch.days_since_latest_purchase,
        ch.customer_lifetime_days,

        ROW_NUMBER() OVER
        (
            PARTITION BY c.region
            ORDER BY ch.lifetime_revenue DESC
        ) AS regional_rank

    FROM churned_customers ch

    JOIN dim_customers c
        ON ch.customer_id = c.customer_id

    WHERE ch.churn_flag = 1
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,
    first_purchase_date,
    latest_purchase_date,
    lifetime_revenue,
    total_orders,
    avg_purchase_interval,
    days_since_latest_purchase,
    customer_lifetime_days,
    regional_rank

FROM ranked_customers

ORDER BY
    region,
    regional_rank;


/*Q5 — Customer 360 Mega Query*/

WITH customer_monthly_sales AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        DATE_TRUNC('month', f.order_date) AS sales_month,

        SUM(f.sales_amount) AS monthly_revenue,

        COUNT(DISTINCT f.order_id) AS monthly_orders

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

        LAG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month_revenue,

        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month,

        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_purchase_month,

        AVG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_month_revenue,

        SUM(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS cumulative_revenue

    FROM customer_monthly_sales
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
            WHEN previous_month =
                 sales_month - INTERVAL '1 month'
                 AND monthly_revenue > previous_month_revenue
            THEN 1
            ELSE 0
        END AS growth_flag,

        CASE
            WHEN previous_month =
                 sales_month - INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS active_month_flag

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
        ) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS growth_island_id

    FROM growth_metrics
),

growth_streaks AS
(
    SELECT
        customer_id,
        growth_island_id,
        COUNT(*) AS growth_streak_length

    FROM growth_islands

    WHERE growth_flag = 1

    GROUP BY
        customer_id,
        growth_island_id
),

longest_growth_streak AS
(
    SELECT
        customer_id,
        MAX(growth_streak_length)
            AS longest_growth_streak

    FROM growth_streaks

    GROUP BY customer_id
),

activity_islands AS
(
    SELECT
        *,

        SUM(
            CASE
                WHEN monthly_orders = 0 THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS activity_island_id

    FROM customer_monthly_sales
),

activity_streaks AS
(
    SELECT
        customer_id,
        activity_island_id,
        COUNT(*) AS active_streak_length

    FROM activity_islands

    WHERE monthly_orders > 0

    GROUP BY
        customer_id,
        activity_island_id
),

longest_activity_streak AS
(
    SELECT
        customer_id,
        MAX(active_streak_length)
            AS longest_active_streak

    FROM activity_streaks

    GROUP BY customer_id
),

customer_lifecycle AS
(
    SELECT
        customer_id,

        MIN(sales_month) AS cohort_month,

        MAX(sales_month) AS latest_purchase_month,

        COUNT(*) AS active_months,

        MAX(sales_month) - MIN(sales_month)
            AS customer_lifetime_interval

    FROM customer_monthly_sales

    GROUP BY customer_id
),

customer_lifetime AS
(
    SELECT
        customer_id,

        SUM(sales_amount) AS lifetime_revenue,

        COUNT(DISTINCT order_id) AS lifetime_orders

    FROM fact_sales

    GROUP BY customer_id
),

overall_customer_metrics AS
(
    SELECT
        AVG(lifetime_revenue)
            AS overall_avg_revenue,

        PERCENTILE_CONT(0.50)
            WITHIN GROUP
            (
                ORDER BY lifetime_revenue
            ) AS p50_revenue,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP
            (
                ORDER BY lifetime_revenue
            ) AS p75_revenue,

        PERCENTILE_CONT(0.90)
            WITHIN GROUP
            (
                ORDER BY lifetime_revenue
            ) AS p90_revenue

    FROM customer_lifetime
),

customer_value_segment AS
(
    SELECT
        l.customer_id,
        l.lifetime_revenue,
        l.lifetime_orders,

        CASE
            WHEN l.lifetime_revenue >= o.p90_revenue
                THEN 'VIP'

            WHEN l.lifetime_revenue >= o.p75_revenue
                THEN 'High Value'

            WHEN l.lifetime_revenue >= o.p50_revenue
                THEN 'Medium Value'

            ELSE 'Low Value'
        END AS customer_value_segment

    FROM customer_lifetime l

    CROSS JOIN overall_customer_metrics o
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

    FROM growth_metrics
),

cohort_metrics AS
(
    SELECT
        c.cohort_month,

        COUNT(DISTINCT c.customer_id)
            AS cohort_customer_count,

        SUM(l.lifetime_revenue)
            AS cohort_total_revenue

    FROM customer_lifecycle c

    JOIN customer_lifetime l
        ON c.customer_id = l.customer_id

    GROUP BY c.cohort_month
),

customer_cohort_contribution AS
(
    SELECT
        c.customer_id,
        c.cohort_month,

        cm.cohort_customer_count,
        cm.cohort_total_revenue,

        ROUND(
            l.lifetime_revenue * 100.0
            / NULLIF(cm.cohort_total_revenue, 0),
            2
        ) AS cohort_revenue_contribution_pct

    FROM customer_lifecycle c

    JOIN cohort_metrics cm
        ON c.cohort_month = cm.cohort_month

    JOIN customer_lifetime l
        ON c.customer_id = l.customer_id
),

customer_category_revenue AS
(
    SELECT
        f.customer_id,
        p.category,

        SUM(f.sales_amount) AS category_revenue

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        f.customer_id,
        p.category
),

favorite_category AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY category_revenue DESC
        ) AS rn

    FROM customer_category_revenue
),

favorite_category_final AS
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

    FROM favorite_category f

    JOIN customer_lifetime l
        ON f.customer_id = l.customer_id

    WHERE f.rn = 1
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        cc.cohort_month,

        l.lifetime_revenue,
        l.lifetime_orders,

        cl.latest_purchase_month,

        EXTRACT(
            YEAR FROM AGE(
                cl.latest_purchase_month,
                cl.cohort_month
            )
        ) * 12

        +

        EXTRACT(
            MONTH FROM AGE(
                cl.latest_purchase_month,
                cl.cohort_month
            )
        ) AS months_since_acquisition,

        lm.sales_month AS latest_month,

        lm.monthly_revenue AS latest_month_revenue,

        lm.previous_month_revenue,

        lm.mom_growth AS latest_mom_growth,

        lm.rolling_3_month_revenue,

        lgs.longest_growth_streak,

        las.longest_active_streak,

        cc.cohort_customer_count,

        cc.cohort_total_revenue,

        cc.cohort_revenue_contribution_pct,

        cvs.customer_value_segment,

        fc.favorite_category,

        fc.favorite_category_revenue,

        fc.favorite_category_pct

    FROM dim_customers c

    JOIN customer_lifetime l
        ON c.customer_id = l.customer_id

    JOIN customer_lifecycle cl
        ON c.customer_id = cl.customer_id

    JOIN customer_cohort_contribution cc
        ON c.customer_id = cc.customer_id

    JOIN customer_value_segment cvs
        ON c.customer_id = cvs.customer_id

    JOIN latest_month lm
        ON c.customer_id = lm.customer_id
       AND lm.rn = 1

    LEFT JOIN longest_growth_streak lgs
        ON c.customer_id = lgs.customer_id

    LEFT JOIN longest_activity_streak las
        ON c.customer_id = las.customer_id

    LEFT JOIN favorite_category_final fc
        ON c.customer_id = fc.customer_id
),

health_classification AS
(
    SELECT
        *,

        CASE

            WHEN latest_mom_growth > 0
                 AND longest_active_streak >= 3
            THEN 'HEALTHY'

            WHEN longest_growth_streak >= 3
                 AND latest_mom_growth > 0
            THEN 'GROWING'

            WHEN latest_mom_growth <= 0
            THEN 'AT RISK'

            ELSE 'CHURNED'

        END AS customer_health

    FROM customer_profile
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

    FROM health_classification
),

final_customers AS
(
    SELECT
        *

    FROM ranked_customers r

    CROSS JOIN overall_customer_metrics o

    WHERE r.lifetime_revenue >
          o.overall_avg_revenue

      AND r.longest_growth_streak >= 3

      AND r.regional_rank <= 5
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,

    cohort_month,

    lifetime_revenue,
    lifetime_orders,

    latest_purchase_month,

    months_since_acquisition,

    latest_month_revenue,
    previous_month_revenue,
    latest_mom_growth,

    rolling_3_month_revenue,

    longest_growth_streak,
    longest_active_streak,

    cohort_customer_count,
    cohort_total_revenue,
    cohort_revenue_contribution_pct,

    customer_value_segment,
    customer_health,

    favorite_category,
    favorite_category_revenue,
    favorite_category_pct,

    regional_rank

FROM final_customers

ORDER BY
    region,
    regional_rank;
