# SQL Interview Preparation — Next 15 Distinct Questions

> **Batch:** Questions 111–125 from the SQL interview bank  
> **Focus:** Salary ranking, duplicate handling, and real-world SQL problems  
> **Rule:** Monster Queries are excluded. Questions are taken from the remaining SQL bank and do not recycle the previous batches.

---

## 1. How do you find the third-highest salary?

A reliable approach is `DENSE_RANK()` because it handles duplicate salaries correctly.

```sql
SELECT EmpID, EmpName, Salary
FROM (
    SELECT
        EmpID,
        EmpName,
        Salary,
        DENSE_RANK() OVER (
            ORDER BY Salary DESC
        ) AS SalaryRank
    FROM Employees
) x
WHERE SalaryRank = 3;
```

**Interview answer:**

> I would use `DENSE_RANK()` to rank distinct salary values in descending order and then filter for rank 3. This also handles ties correctly.

---

## 2. How do you find the Nth-highest salary?

Use `DENSE_RANK()` and filter for the required rank.

```sql
WITH RankedSalaries AS (
    SELECT
        EmpID,
        EmpName,
        Salary,
        DENSE_RANK() OVER (
            ORDER BY Salary DESC
        ) AS SalaryRank
    FROM Employees
)
SELECT *
FROM RankedSalaries
WHERE SalaryRank = 5;
```

Here, `5` represents the Nth position.

**Interview answer:**

> I would use `DENSE_RANK()` ordered by salary descending and filter where the rank equals N. This identifies the Nth distinct-highest salary and handles ties.

---

## 3. How do you find the first 3 maximum salaries?

If you need the three highest **distinct** salary values:

```sql
SELECT Salary
FROM (
    SELECT
        Salary,
        DENSE_RANK() OVER (
            ORDER BY Salary DESC
        ) AS SalaryRank
    FROM Employees
) x
WHERE SalaryRank <= 3;
```

If you need employee rows as well:

```sql
SELECT EmpID, EmpName, Salary
FROM (
    SELECT
        EmpID,
        EmpName,
        Salary,
        DENSE_RANK() OVER (
            ORDER BY Salary DESC
        ) AS SalaryRank
    FROM Employees
) x
WHERE SalaryRank <= 3;
```

**Interview answer:**

> I would use `DENSE_RANK()` when the requirement is the top three distinct salary levels. It ensures employees with equal salaries receive the same rank.

---

## 4. How do you find the top 3 salaries including ties?

Use `DENSE_RANK()`.

```sql
SELECT EmpID, EmpName, Salary
FROM (
    SELECT
        EmpID,
        EmpName,
        Salary,
        DENSE_RANK() OVER (
            ORDER BY Salary DESC
        ) AS SalaryRank
    FROM Employees
) x
WHERE SalaryRank <= 3;
```

Example:

```text
Salary
100000 → Rank 1
90000  → Rank 2
90000  → Rank 2
80000  → Rank 3
```

All employees earning one of the top three distinct salary levels are returned.

**Interview answer:**

> I would use `DENSE_RANK()` and filter for ranks 1 through 3. This includes all employees tied at those salary levels.

---

## 5. How do you find the top 3 products based on sales?

First aggregate sales by product and then rank the products.

```sql
WITH ProductSales AS (
    SELECT
        ProductID,
        SUM(SalesAmount) AS TotalSales
    FROM Sales
    GROUP BY ProductID
),
RankedProducts AS (
    SELECT
        ProductID,
        TotalSales,
        DENSE_RANK() OVER (
            ORDER BY TotalSales DESC
        ) AS SalesRank
    FROM ProductSales
)
SELECT
    ProductID,
    TotalSales
FROM RankedProducts
WHERE SalesRank <= 3;
```

**Interview answer:**

> I would first aggregate total sales for each product, then rank the products using `DENSE_RANK()` and return the top three.

---

## 6. How do you find the top 2 products by revenue per region including ties?

Aggregate revenue at the region-product level and then rank within each region.

```sql
WITH ProductRevenue AS (
    SELECT
        Region,
        ProductID,
        SUM(Revenue) AS TotalRevenue
    FROM Sales
    GROUP BY Region, ProductID
),
RankedProducts AS (
    SELECT
        Region,
        ProductID,
        TotalRevenue,
        DENSE_RANK() OVER (
            PARTITION BY Region
            ORDER BY TotalRevenue DESC
        ) AS RevenueRank
    FROM ProductRevenue
)
SELECT
    Region,
    ProductID,
    TotalRevenue
FROM RankedProducts
WHERE RevenueRank <= 2;
```

**Interview answer:**

> I would aggregate revenue by region and product, use `DENSE_RANK()` with `PARTITION BY Region`, and filter for ranks 1 and 2 so ties are included.

---

## 7. How do you find employees whose salary is greater than their manager's salary?

Use a SELF JOIN.

```sql
SELECT
    e.EmpID,
    e.EmpName,
    e.Salary,
    m.EmpName AS ManagerName,
    m.Salary AS ManagerSalary
FROM Employees e
JOIN Employees m
    ON e.ManagerID = m.EmpID
WHERE e.Salary > m.Salary;
```

**Interview answer:**

> I would self-join the Employees table so that one alias represents the employee and the other represents the manager, then compare their salaries.

---

## 8. How do you find employees earning above the average salary of their department?

First calculate the department average and compare each employee against it.

```sql
SELECT
    e.EmpID,
    e.EmpName,
    e.DepartmentID,
    e.Salary
FROM Employees e
WHERE e.Salary > (
    SELECT AVG(e2.Salary)
    FROM Employees e2
    WHERE e2.DepartmentID = e.DepartmentID
);
```

A window-function approach:

```sql
SELECT
    EmpID,
    EmpName,
    DepartmentID,
    Salary
FROM (
    SELECT
        *,
        AVG(Salary) OVER (
            PARTITION BY DepartmentID
        ) AS DeptAvgSalary
    FROM Employees
) x
WHERE Salary > DeptAvgSalary;
```

**Interview answer:**

> I can calculate the department average using a correlated subquery or a window function and then filter employees whose salary is above that departmental average.

---

## 9. How do you find employees in the same department as the employee with the highest salary?

Find the department of the highest-paid employee and then retrieve employees from that department.

```sql
SELECT *
FROM Employees
WHERE DepartmentID = (
    SELECT DepartmentID
    FROM Employees
    WHERE Salary = (
        SELECT MAX(Salary)
        FROM Employees
    )
);
```

If multiple employees share the highest salary, the subquery may return multiple rows. In that case, use `IN`:

```sql
SELECT *
FROM Employees
WHERE DepartmentID IN (
    SELECT DepartmentID
    FROM Employees
    WHERE Salary = (
        SELECT MAX(Salary)
        FROM Employees
    )
);
```

**Interview answer:**

> I would first identify the department or departments containing the highest-paid employee and then return all employees belonging to those departments.

---

# Duplicate Handling

## 10. How do you find duplicate records in a table?

Use `GROUP BY` with `HAVING`.

```sql
SELECT
    EmpID,
    EmpName,
    COUNT(*) AS RecordCount
FROM Employees
GROUP BY
    EmpID,
    EmpName
HAVING COUNT(*) > 1;
```

**Interview answer:**

> I identify duplicates by grouping on the columns that define a duplicate and using `HAVING COUNT(*) > 1`.

---

## 11. How do you find duplicate records along with their count?

Use `GROUP BY` and `COUNT()`.

```sql
SELECT
    Email,
    COUNT(*) AS DuplicateCount
FROM Employees
GROUP BY Email
HAVING COUNT(*) > 1;
```

**Interview answer:**

> I group by the column that should be unique and count the rows. Any group with a count greater than one represents a duplicate.

---

## 12. How do you find duplicate email addresses?

```sql
SELECT
    Email,
    COUNT(*) AS EmailCount
FROM Employees
GROUP BY Email
HAVING COUNT(*) > 1;
```

If you want the complete employee records associated with duplicate emails:

```sql
SELECT *
FROM Employees
WHERE Email IN (
    SELECT Email
    FROM Employees
    GROUP BY Email
    HAVING COUNT(*) > 1
);
```

**Interview answer:**

> I would group records by email and use `HAVING COUNT(*) > 1`. If I need the complete rows, I can use those duplicate emails in a subquery.

---

## 13. How do you remove duplicate records from a table?

A common approach is `ROW_NUMBER()` with a CTE.

```sql
WITH RankedEmployees AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY EmpID, EmpName, Email
            ORDER BY EmpID
        ) AS rn
    FROM Employees
)
DELETE FROM RankedEmployees
WHERE rn > 1;
```

The exact DELETE syntax for a CTE varies by database system.

**Interview answer:**

> I would identify duplicate groups with `ROW_NUMBER()`, keep the first record with `rn = 1`, and delete records where `rn > 1`. I would validate the duplicate definition before deleting anything.

---

## 14. How do you remove duplicates while keeping the latest record?

Use `ROW_NUMBER()` and order each duplicate group by the latest timestamp.

```sql
WITH RankedEmployees AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY EmpID
            ORDER BY UpdatedAt DESC
        ) AS rn
    FROM Employees
)
DELETE FROM RankedEmployees
WHERE rn > 1;
```

The latest record receives:

```text
rn = 1
```

and is retained.

**Interview answer:**

> I would partition by the business key, order by the update timestamp descending, keep `ROW_NUMBER() = 1`, and remove rows where the row number is greater than 1.

---

## 15. How do you remove duplicates using `ROW_NUMBER()`?

First identify the rows:

```sql
SELECT
    *,
    ROW_NUMBER() OVER (
        PARTITION BY EmpID, Email
        ORDER BY UpdatedAt DESC
    ) AS rn
FROM Employees;
```

Then keep only the first row:

```sql
WITH RankedEmployees AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY EmpID, Email
            ORDER BY UpdatedAt DESC
        ) AS rn
    FROM Employees
)
SELECT *
FROM RankedEmployees
WHERE rn = 1;
```

For deletion:

```sql
WITH RankedEmployees AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY EmpID, Email
            ORDER BY UpdatedAt DESC
        ) AS rn
    FROM Employees
)
DELETE FROM RankedEmployees
WHERE rn > 1;
```

**Interview answer:**

> `ROW_NUMBER()` lets me assign an order within each duplicate group. I retain `rn = 1` and treat rows with `rn > 1` as duplicates. By ordering on `UpdatedAt DESC`, I can retain the latest record.

---

# Today's Checklist

- [x] Third-highest salary
- [x] Nth-highest salary
- [x] First 3 maximum salaries
- [x] Top 3 salaries including ties
- [x] Top 3 products based on sales
- [x] Top 2 products by revenue per region including ties
- [x] Employees earning more than their managers
- [x] Employees above department average salary
- [x] Employees in the highest-salary employee's department
- [x] Find duplicate records
- [x] Find duplicate records with count
- [x] Find duplicate email addresses
- [x] Remove duplicate records
- [x] Remove duplicates while keeping latest record
- [x] Remove duplicates using `ROW_NUMBER()`

## SQL Progress

```text
Previous SQL completed: 105
Today's SQL questions:  +15
----------------------------
SQL completed:         120
SQL remaining:          47
```

> **Important:** The progress count follows the interview-bank tracking established earlier. Monster Queries are excluded.
