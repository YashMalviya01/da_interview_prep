/*Q1 — Employee Performance
Grain
One row per employee

Task

Find employees whose performance score is above their department's average, while their salary is below their department's average salary.

Calculate:

Department average performance score
Department average salary
Employee salary difference from department average
Employee performance difference from department average
Rank employees by performance within department

Return the top 3 qualifying employees per department.*/


WITH department_avg AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        d.department_id,
        d.department_name,
        e.salary,
        e.performance_score,

        AVG(e.salary) OVER (
            PARTITION BY d.department_id
        ) AS department_avg_salary,

        AVG(e.performance_score) OVER (
            PARTITION BY d.department_id
        ) AS department_avg_performance

    FROM dim_employees e

    INNER JOIN dim_department d
        ON e.department_id = d.department_id
),

qualifying_employees AS
(
    SELECT
        employee_id,
        employee_name,
        department_id,
        department_name,
        salary,
        performance_score,

        department_avg_salary,
        department_avg_performance,

        salary - department_avg_salary
            AS salary_diff_from_avg,

        performance_score - department_avg_performance
            AS performance_diff_from_avg,

        ROW_NUMBER() OVER (
            PARTITION BY department_id
            ORDER BY
                performance_score DESC,
                salary ASC
        ) AS perf_rank

    FROM department_avg

    WHERE performance_score > department_avg_performance
      AND salary < department_avg_salary
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
    salary_diff_from_avg,
    performance_diff_from_avg,
    perf_rank

FROM qualifying_employees

WHERE perf_rank <= 3

ORDER BY
    department_id,
    perf_rank;


/*Q2 — Customer Repeat Purchase Analysis
Grain
One row per customer
Task

For every customer calculate:

First purchase date
Latest purchase date
Total orders
Lifetime revenue
Average order value
Number of distinct purchase months
Previous purchase date
Average days between purchases
Days since latest purchase
Finally rank customers by lifetime revenue within region and return the top 5 in each region.*/


WITH customer_orders AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        f.order_id,
        f.order_date,
        f.sales_amount,

        LAG(f.order_date) OVER
        (
            PARTITION BY f.customer_id
            ORDER BY f.order_date
        ) AS previous_purchase_date

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id
),

purchase_gaps AS
(
    SELECT
        *,
        
        order_date - previous_purchase_date
            AS days_between_purchases

    FROM customer_orders

    WHERE previous_purchase_date IS NOT NULL
),

customer_metrics AS
(
    SELECT
        customer_id,
        MAX(customer_name) AS customer_name,
        MAX(segment) AS segment,
        MAX(region) AS region,

        MIN(order_date) AS first_purchase_date,
        MAX(order_date) AS latest_purchase_date,

        COUNT(DISTINCT order_id) AS total_orders,

        SUM(sales_amount) AS lifetime_revenue,

        COUNT(
            DISTINCT DATE_TRUNC('month', order_date)
        ) AS distinct_purchase_months,

        AVG(days_between_purchases)
            AS avg_days_between_purchases

    FROM purchase_gaps

    GROUP BY customer_id
),

customer_analysis AS
(
    SELECT
        *,

        lifetime_revenue
            / NULLIF(total_orders, 0)
            AS average_order_value,

        CURRENT_DATE - latest_purchase_date
            AS days_since_latest_purchase,

        CASE
            WHEN total_orders >= 10
                THEN 'LOYAL'

            WHEN total_orders BETWEEN 5 AND 9
                THEN 'REPEAT'

            WHEN total_orders = 1
                THEN 'ONE-TIME'

            ELSE 'OCCASIONAL'
        END AS customer_type

    FROM customer_metrics
),

regional_ranking AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY region
            ORDER BY lifetime_revenue DESC
        ) AS regional_rank

    FROM customer_analysis
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,

    first_purchase_date,
    latest_purchase_date,

    total_orders,
    lifetime_revenue,
    average_order_value,

    distinct_purchase_months,
    avg_days_between_purchases,
    days_since_latest_purchase,

    customer_type,
    regional_rank

FROM regional_ranking

WHERE regional_rank <= 5

ORDER BY
    region,
    regional_rank;


/*Q3 — Product Monthly Performance
Task

Calculate:

Monthly revenue
Monthly orders
Previous-month revenue
MoM revenue growth %
3-month rolling revenue
Category monthly revenue
Product's % contribution to category revenue
Product rank within category for each month

Then identify products that:

Have positive MoM growth
Have at least 10% category revenue contribution
Are ranked top 3 within their category

Return the latest available month for those products.*/

WITH product_monthly_sales AS
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

        LAG(monthly_revenue) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_month_revenue,

        AVG(monthly_revenue) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3m_revenue,

        SUM(monthly_revenue) OVER
        (
            PARTITION BY category, sales_month
        ) AS category_monthly_revenue

    FROM product_monthly_sales
),

product_metrics AS
(
    SELECT
        *,

        ROUND(
            (
                monthly_revenue - previous_month_revenue
            ) * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        ROUND(
            monthly_revenue * 100.0
            / NULLIF(category_monthly_revenue, 0),
            2
        ) AS category_contribution_pct,

        ROW_NUMBER() OVER
        (
            PARTITION BY category, sales_month
            ORDER BY monthly_revenue DESC
        ) AS product_rank

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

    p.product_rank

FROM product_metrics p

CROSS JOIN latest_month l

WHERE p.sales_month = l.latest_sales_month

  AND p.mom_growth > 0

  AND p.category_contribution_pct >= 10

  AND p.product_rank <= 3

ORDER BY
    p.category,
    p.product_rank;

/*Q4 — Customer Retention Cohort

Task

Build a cohort retention analysis.

Calculate:

Customer's first purchase month
Cohort month
Months since acquisition
Number of customers in each cohort
Number of active customers in each subsequent month
Retention %
Bonus: calculate cumulative cohort revenue as well.*/

WITH customer_months AS
(
    SELECT DISTINCT
        customer_id,

        DATE_TRUNC('month', order_date)
            AS sales_month

    FROM fact_sales
),

customer_cohorts AS
(
    SELECT
        customer_id,
        sales_month,

        MIN(sales_month) OVER
        (
            PARTITION BY customer_id
        ) AS cohort_month

    FROM customer_months
),

customer_age AS
(
    SELECT
        customer_id,
        cohort_month,
        sales_month,

        (
            EXTRACT(
                YEAR FROM AGE(
                    sales_month,
                    cohort_month
                )
            ) * 12

            +

            EXTRACT(
                MONTH FROM AGE(
                    sales_month,
                    cohort_month
                )
            )
        ) AS months_since_acquisition

    FROM customer_cohorts
),

cohort_activity AS
(
    SELECT
        cohort_month,
        months_since_acquisition,

        COUNT(DISTINCT customer_id)
            AS active_customers

    FROM customer_age

    GROUP BY
        cohort_month,
        months_since_acquisition
),

cohort_size AS
(
    SELECT
        cohort_month,

        active_customers
            AS original_cohort_size

    FROM cohort_activity

    WHERE months_since_acquisition = 0
)

SELECT
    a.cohort_month,

    a.months_since_acquisition,

    a.active_customers,

    c.original_cohort_size,

    ROUND(
        a.active_customers * 100.0
        / NULLIF(c.original_cohort_size, 0),
        2
    ) AS retention_rate

FROM cohort_activity a

JOIN cohort_size c
    ON a.cohort_month = c.cohort_month

ORDER BY
    a.cohort_month,
    a.months_since_acquisition;

/*Build a Customer Intelligence Profile

For every customer calculate:

1. Revenue metrics
Lifetime revenue
Lifetime orders
Average order value
First purchase date
Latest purchase date
2. Monthly metrics

Build monthly customer revenue and calculate:

Previous month revenue
MoM growth %
3-month rolling revenue
Cumulative revenue
3. Acquisition

Calculate:

Cohort month
Months since acquisition
Number of active months
4. Purchase behavior

Calculate:

Previous purchase date
Average days between purchases
Days since latest purchase
5. Growth streak

Identify consecutive months where:

monthly_revenue > previous_month_revenue

Calculate:

Growth flag
Island ID
Growth streak length
Longest growth streak
6. Customer value

Using lifetime revenue, classify:

VIP       >= 90th percentile
HIGH      >= 75th percentile
MEDIUM    >= 50th percentile
LOW       otherwise
7. Favorite category

Find the customer's highest-revenue product category.

Calculate:

Favorite category
Category revenue
Category % of lifetime revenue

Use ROW_NUMBER().

8. Customer health

Classify:

GROWING
    latest MoM > 0
    AND longest growth streak >= 3

AT RISK
    latest MoM <= 0

LOYAL
    active months >= 6
    AND lifetime revenue > overall average

NEW
    months since acquisition <= 2

STABLE
    otherwise

Use the correct priority order so a customer doesn't accidentally receive multiple classifications.

9. Regional ranking

Rank customers within their region by:

lifetime_revenue DESC
10. Final filter

Return only customers who:

lifetime revenue > overall customer average

AND

latest month revenue > previous month revenue

AND

longest growth streak >= 3

AND

regional rank <= 5
Final output
customer_id
customer_name
segment
region

cohort_month
months_since_acquisition
active_months

first_purchase_date
latest_purchase_date
days_since_latest_purchase
average_days_between_purchases

lifetime_revenue
lifetime_orders
average_order_value

previous_month_revenue
latest_month_revenue
latest_mom_growth
rolling_3m_revenue
cumulative_revenue

longest_growth_streak

customer_value_segment
customer_health

favorite_category
favorite_category_revenue
favorite_category_pct

regional_rank*/

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
            AS monthly_revenue

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

        MIN(sales_month) OVER
        (
            PARTITION BY customer_id
        ) AS cohort_month,

        AVG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3m_revenue,

        SUM(monthly_revenue) OVER
        (
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
        ) OVER
        (
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

        MIN(order_date)
            AS first_purchase_date,

        MAX(order_date)
            AS latest_purchase_date,

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

category_revenue AS
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

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY category_revenue DESC
        ) AS rn

    FROM category_revenue
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

    JOIN lifetime_metrics l
        ON f.customer_id = l.customer_id

    WHERE f.rn = 1
),

overall_metrics AS
(
    SELECT
        AVG(lifetime_revenue)
            AS avg_lifetime_revenue,

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

    FROM lifetime_metrics
),

latest_customer_month AS
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

        COALESCE(
            s.longest_growth_streak,
            0
        ) AS longest_growth_streak,

        fc.favorite_category,
        fc.favorite_category_revenue,
        fc.favorite_category_pct,

        CASE
            WHEN l.lifetime_revenue >= o.p90_revenue
                THEN 'VIP'

            WHEN l.lifetime_revenue >= o.p75_revenue
                THEN 'HIGH'

            ELSE 'STANDARD'
        END AS customer_value_segment

    FROM dim_customers c

    JOIN lifetime_metrics l
        ON c.customer_id = l.customer_id

    JOIN customer_activity a
        ON c.customer_id = a.customer_id

    JOIN latest_customer_month lm
        ON c.customer_id = lm.customer_id
       AND lm.rn = 1

    LEFT JOIN longest_streak s
        ON c.customer_id = s.customer_id

    LEFT JOIN favorite_category fc
        ON c.customer_id = fc.customer_id

    CROSS JOIN overall_metrics o
),

regional_ranking AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
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
                 AND longest_growth_streak >= 3
            THEN 'GROWING'

            WHEN mom_growth <= 0
            THEN 'AT RISK'

            WHEN active_months >= 6
                 AND lifetime_revenue >
                     (
                         SELECT avg_lifetime_revenue
                         FROM overall_metrics
                     )
            THEN 'LOYAL'

            WHEN cohort_month >=
                 DATE_TRUNC(
                     'month',
                     CURRENT_DATE - INTERVAL '2 months'
                 )
            THEN 'NEW'

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

    active_months,

    latest_month,
    latest_month_revenue,
    previous_month_revenue,
    mom_growth,

    rolling_3m_revenue,
    cumulative_revenue,

    lifetime_orders,
    lifetime_revenue,

    longest_growth_streak,

    favorite_category,
    favorite_category_revenue,
    favorite_category_pct,

    customer_value_segment,
    customer_health,

    regional_rank

FROM final_classification

WHERE lifetime_revenue >
      (
          SELECT avg_lifetime_revenue
          FROM overall_metrics
      )

  AND latest_month_revenue >
      previous_month_revenue

  AND longest_growth_streak >= 3

  AND regional_rank <= 5

ORDER BY
    region,
    regional_rank;
