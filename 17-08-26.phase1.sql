/*Question 1/5 — Customer Monthly Performance

An e-commerce company wants to identify customers whose monthly spending is consistently increasing.
Requirement

For each customer:

Calculate monthly revenue.
Calculate previous month's revenue.
Calculate MoM revenue growth %.
Calculate a 3-month rolling average revenue.
Calculate the customer's longest consecutive streak of increasing monthly revenue.
Identify their latest active month.
Return only customers whose:
longest increasing streak is at least 3 months
latest month's revenue is higher than the previous month.*/

WITH customer_monthly_performance AS
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

previous_month_revenue AS
(
    SELECT
        customer_id,
        customer_name,
        segment,
        region,
        sales_month,
        monthly_revenue,

        LAG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month_revenue,

        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_sales_month

    FROM customer_monthly_performance
),

mom_growth AS
(
    SELECT
        *,

        ROUND(
            (monthly_revenue - previous_month_revenue) * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        CASE
            WHEN previous_month_revenue IS NOT NULL
                 AND previous_sales_month =
                     sales_month - INTERVAL '1 month'
                 AND monthly_revenue > previous_month_revenue
            THEN 1
            ELSE 0
        END AS increase_flag

    FROM previous_month_revenue
),

rolling_average AS
(
    SELECT
        *,

        ROUND(
            AVG(monthly_revenue) OVER
            (
                PARTITION BY customer_id
                ORDER BY sales_month
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_avg_3m,

        SUM(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS running_revenue

    FROM mom_growth
),

streak_flags AS
(
    SELECT
        *,

        CASE
            WHEN increase_flag = 1
            THEN 0
            ELSE 1
        END AS new_island_flag

    FROM rolling_average
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

    WHERE increase_flag = 1

    GROUP BY
        customer_id,
        island_id
),

longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_monthly_streak

    FROM streak_lengths

    GROUP BY customer_id
),

latest_month AS
(
    SELECT
        customer_id,
        sales_month,
        monthly_revenue,
        previous_month_revenue,
        mom_growth,
        rolling_avg_3m,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM rolling_average
)

SELECT
    l.customer_id,
    l.sales_month AS latest_month,
    l.monthly_revenue AS latest_month_revenue,
    l.previous_month_revenue,
    l.mom_growth,
    l.rolling_avg_3m,
    s.longest_monthly_streak

FROM latest_month l

JOIN longest_streak s
    ON l.customer_id = s.customer_id

WHERE l.rn = 1
  AND s.longest_monthly_streak >= 3
  AND l.monthly_revenue > l.previous_month_revenue

ORDER BY
    s.longest_monthly_streak DESC,
    l.monthly_revenue DESC;

/*Q2 — Top Products by Category
Requirement

For every category, identify the top 3 products by total revenue.

Also calculate each product's percentage contribution to its category's revenue.*/

WITH product_revenue AS
(
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        SUM(f.sales_amount) AS total_revenue

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        p.category,
        p.product_id,
        p.product_name
),

category_metrics AS
(
    SELECT
        *,
        
        SUM(total_revenue) OVER
        (
            PARTITION BY category
        ) AS category_revenue,

        ROW_NUMBER() OVER
        (
            PARTITION BY category
            ORDER BY total_revenue DESC
        ) AS rn

    FROM product_revenue
),

final AS
(
    SELECT
        category,
        product_id,
        product_name,
        total_revenue,

        ROUND(
            total_revenue * 100.0
            / NULLIF(category_revenue, 0),
            2
        ) AS category_revenue_percentage,

        rn

    FROM category_metrics
)

SELECT
    category,
    product_id,
    product_name,
    total_revenue,
    category_revenue_percentage,
    rn AS category_rank

FROM final

WHERE rn <= 3

ORDER BY
    category,
    category_rank;

/*Q3 — Employee Attendance Streak

Now let's bring back one of our favorite patterns.

A company wants to identify employees with the longest consecutive attendance streak.
Requirement

For every employee:

Calculate their longest consecutive present-day streak
Calculate total present days
Find their latest attendance date

Return the top 5 employees overall by longest streak*/

WITH present_days AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        e.department,
        a.attendance_date

    FROM fact_attendance a

    JOIN dim_employees e
        ON a.employee_id = e.employee_id

    WHERE a.attendance_status = 'Present'
),

previous_day AS
(
    SELECT
        *,
        
        LAG(attendance_date) OVER
        (
            PARTITION BY employee_id
            ORDER BY attendance_date
        ) AS previous_attendance_date

    FROM present_days
),

gap_flags AS
(
    SELECT
        *,
        
        CASE
            WHEN previous_attendance_date IS NULL
                 OR attendance_date <>
                    previous_attendance_date + INTERVAL '1 day'
            THEN 1
            ELSE 0
        END AS new_island_flag

    FROM previous_day
),

attendance_islands AS
(
    SELECT
        *,
        
        SUM(new_island_flag) OVER
        (
            PARTITION BY employee_id
            ORDER BY attendance_date
        ) AS island_id

    FROM gap_flags
),

streak_lengths AS
(
    SELECT
        employee_id,
        island_id,
        COUNT(*) AS streak_length

    FROM attendance_islands

    GROUP BY
        employee_id,
        island_id
),

employee_metrics AS
(
    SELECT
        p.employee_id,
        p.employee_name,
        p.department,

        COUNT(*) AS total_present_days,
        MAX(s.streak_length) AS longest_present_streak,
        MAX(p.attendance_date) AS latest_attendance_date

    FROM present_days p

    JOIN streak_lengths s
        ON p.employee_id = s.employee_id

    GROUP BY
        p.employee_id,
        p.employee_name,
        p.department
),

ranked_employees AS
(
    SELECT
        *,
        
        ROW_NUMBER() OVER
        (
            ORDER BY longest_present_streak DESC
        ) AS rn

    FROM employee_metrics
)

SELECT
    employee_id,
    employee_name,
    department,
    total_present_days,
    longest_present_streak,
    latest_attendance_date

FROM ranked_employees

WHERE rn <= 5

ORDER BY
    longest_present_streak DESC;

