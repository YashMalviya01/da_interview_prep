/*Q1 — Employee Salary Analysis

Task

Return employees whose salary is:

Above their department's average salary
But below the company's overall average salary*/

WITH employee_salary AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        e.department_id,
        d.department_name,
        e.salary,

        AVG(e.salary) OVER (PARTITION BY e.department_id) AS department_avg_salary

    FROM dim_employees e
    JOIN dim_departments d ON e.department_id = d.department_id     
)

SELECT 
    employee_id,
    employee_name,
    department_name,
    salary,
    department_avg_salary,
    company_avg_salary

FROM employee_salary

WHERE salary > department_avg_salary
  AND salary < company_avg_salary

ORDER BY
    department_name,
    salary DESC;


/*Q2 — Duplicate Transactions
Requirement

Find customers who made multiple transactions on the same date for the exact same amount.*/

WITH duplicate_transactions AS
(
    SELECT
        customer_id,
        transaction_date,
        amount,
        COUNT(*) AS duplicate_count

    FROM transactions

    GROUP BY
        customer_id,
        transaction_date,
        amount

    HAVING COUNT(*) > 1
)

SELECT
    customer_id,
    transaction_date,
    amount,
    duplicate_count

FROM duplicate_transactions

ORDER BY
    customer_id,
    transaction_date;

/*Q3 — Customers Who Never Purchased*/

SELECT
    c.customer_id,
    c.customer_name

FROM customers c

LEFT JOIN sales s
    ON c.customer_id = s.customer_id

WHERE s.customer_id IS NULL;

/*method 2 */

SELECT
    c.customer_id,
    c.customer_name

FROM customers c

WHERE NOT EXISTS
(
    SELECT 1
    FROM sales s
    WHERE s.customer_id = c.customer_id
);


/*Q4 — Second-Highest Salary Per Department*/

WITH ranked_employees AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        e.department_id,
        d.department_name,
        e.salary,

        DENSE_RANK() OVER
        (
            PARTITION BY e.department_id
            ORDER BY e.salary DESC
        ) AS salary_rank

    FROM dim_employees e

    JOIN dim_departments d
        ON e.department_id = d.department_id
)

SELECT
    employee_id,
    employee_name,
    department_name,
    salary

FROM ranked_employees

WHERE salary_rank = 2

ORDER BY
    department_name;

/*Q5 — E-Commerce Conversion Funnel
Requirement

Calculate monthly:

Unique viewers
Unique users who added to cart
Unique buyers
View → Cart conversion
Cart → Purchase conversion
Overall View → Purchase conversion*/


WITH monthly_funnel AS
(
    SELECT
        DATE_TRUNC('month', event_date) AS event_month,

        COUNT(
            DISTINCT CASE
                WHEN event_type = 'view_product'
                THEN user_id
            END
        ) AS unique_viewers,

        COUNT(
            DISTINCT CASE
                WHEN event_type = 'add_to_cart'
                THEN user_id
            END
        ) AS unique_cart_users,

        COUNT(
            DISTINCT CASE
                WHEN event_type = 'purchase'
                THEN user_id
            END
        ) AS unique_buyers

    FROM events

    GROUP BY
        DATE_TRUNC('month', event_date)
),

conversion_metrics AS
(
    SELECT
        *,

        ROUND(
            unique_cart_users * 100.0
            / NULLIF(unique_viewers, 0),
            2
        ) AS view_to_cart_rate,

        ROUND(
            unique_buyers * 100.0
            / NULLIF(unique_cart_users, 0),
            2
        ) AS cart_to_purchase_rate,

        ROUND(
            unique_buyers * 100.0
            / NULLIF(unique_viewers, 0),
            2
        ) AS overall_conversion_rate

    FROM monthly_funnel
)

SELECT
    event_month,
    unique_viewers,
    unique_cart_users,
    unique_buyers,
    view_to_cart_rate,
    cart_to_purchase_rate,
    overall_conversion_rate

FROM conversion_metrics

ORDER BY
    event_month;
