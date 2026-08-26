# SQL Interview Preparation — Next 15 Questions

> Questions 81–95 from the SQL interview bank. No Monster Queries, no repeats.

## 1. What is a Subquery?

A subquery is a query nested inside another SQL query.

```sql
SELECT EmpName, Salary
FROM Employees
WHERE Salary > (
    SELECT AVG(Salary)
    FROM Employees
);
```

**Interview answer:** A subquery is a query embedded inside another SQL statement and can be used in clauses such as `WHERE`, `FROM`, `SELECT`, or `HAVING`.

---

## 2. What is a Nested Query?

A nested query is a query placed inside another query.

```sql
SELECT *
FROM Employees
WHERE DeptID IN (
    SELECT DeptID
    FROM Departments
    WHERE Location = 'New York'
);
```

**Interview answer:** A nested query is an inner query whose result is used by an outer query.

---

## 3. What is a Correlated Subquery?

A correlated subquery references a value from the outer query.

```sql
SELECT e.EmpName, e.Salary
FROM Employees e
WHERE e.Salary > (
    SELECT AVG(e2.Salary)
    FROM Employees e2
    WHERE e2.DeptID = e.DeptID
);
```

**Interview answer:** A correlated subquery depends on the current row of the outer query and is useful for row-level comparisons.

---

## 4. What is the difference between a Subquery and a Correlated Subquery?

Regular subquery:

```sql
SELECT *
FROM Employees
WHERE Salary > (
    SELECT AVG(Salary)
    FROM Employees
);
```

Correlated subquery:

```sql
SELECT e.*
FROM Employees e
WHERE Salary > (
    SELECT AVG(e2.Salary)
    FROM Employees e2
    WHERE e2.DeptID = e.DeptID
);
```

**Interview answer:** A regular subquery can execute independently, while a correlated subquery references the outer query and depends on its current row.

---

## 5. What are the different types of Subqueries?

Common types include scalar, single-row, multi-row, and correlated subqueries.

```sql
-- Scalar
SELECT *
FROM Employees
WHERE Salary > (SELECT AVG(Salary) FROM Employees);

-- Multi-row
SELECT *
FROM Employees
WHERE DeptID IN (
    SELECT DeptID
    FROM Departments
    WHERE Location = 'New York'
);

-- Correlated
SELECT e.*
FROM Employees e
WHERE e.Salary > (
    SELECT AVG(e2.Salary)
    FROM Employees e2
    WHERE e2.DeptID = e.DeptID
);
```

**Interview answer:** Subqueries are commonly classified according to the number of values they return and whether they depend on the outer query.

---

## 6. What is a CTE?

A Common Table Expression (CTE) is a named temporary result set defined using `WITH` and available to the statement that follows it.

```sql
WITH HighEarners AS (
    SELECT EmpID, EmpName, Salary
    FROM Employees
    WHERE Salary > 80000
)
SELECT *
FROM HighEarners;
```

**Interview answer:** A CTE creates a named query result that improves readability and helps structure complex SQL.

---

## 7. Why would you use a CTE?

CTEs are useful for:

- Breaking complex queries into logical steps
- Improving readability
- Intermediate calculations
- Recursive queries
- Ranking and window-function logic

```sql
WITH DepartmentSalary AS (
    SELECT DeptID, AVG(Salary) AS AvgSalary
    FROM Employees
    GROUP BY DeptID
)
SELECT e.EmpName, e.Salary, d.AvgSalary
FROM Employees e
JOIN DepartmentSalary d
    ON e.DeptID = d.DeptID
WHERE e.Salary > d.AvgSalary;
```

**Interview answer:** I use CTEs to make complex queries easier to read, debug, maintain, and structure into logical stages.

---

## 8. What is the difference between a Temporary Table and a CTE?

| CTE | Temporary Table |
|---|---|
| Query-scoped logical result | Stores intermediate data |
| Defined using `WITH` | Created as a table |
| Usually used within one statement | Can generally be reused across statements |
| Good for readable query logic | Useful for larger intermediate datasets |
| Not normally indexed independently | Can often have indexes |

```sql
WITH SalesSummary AS (
    SELECT CustomerID, SUM(Revenue) AS Revenue
    FROM Sales
    GROUP BY CustomerID
)
SELECT *
FROM SalesSummary;
```

**Interview answer:** A CTE is primarily a query-scoped logical result, while a temporary table stores intermediate data and can generally be reused during its lifetime.

---

## 9. What is a Recursive Query?

A recursive query repeatedly processes related data until a termination condition is reached.

Typical use:

```text
CEO
 ├── Manager A
 │    ├── Employee 1
 │    └── Employee 2
 └── Manager B
```

**Interview answer:** Recursive queries are useful for hierarchical data such as employee-manager structures, category trees, and folder hierarchies.

---

## 10. What is a Recursive CTE?

A Recursive CTE references itself and normally contains an anchor member and a recursive member.

```sql
WITH EmployeeHierarchy AS (

    SELECT EmpID, EmpName, ManagerID, 0 AS Level
    FROM Employees
    WHERE ManagerID IS NULL

    UNION ALL

    SELECT e.EmpID, e.EmpName, e.ManagerID, h.Level + 1
    FROM Employees e
    JOIN EmployeeHierarchy h
        ON e.ManagerID = h.EmpID
)
SELECT *
FROM EmployeeHierarchy;
```

**Interview answer:** A Recursive CTE starts with an anchor query and repeatedly executes the recursive member to traverse hierarchical relationships.

---

## 11. Give an example of a Recursive CTE.

For an employee-manager hierarchy:

```sql
WITH OrgChart AS (

    SELECT EmpID, EmpName, ManagerID, 0 AS Level
    FROM Employees
    WHERE ManagerID IS NULL

    UNION ALL

    SELECT e.EmpID, e.EmpName, e.ManagerID, o.Level + 1
    FROM Employees e
    INNER JOIN OrgChart o
        ON e.ManagerID = o.EmpID
)
SELECT *
FROM OrgChart;
```

**Interview answer:** The anchor selects top-level employees, and the recursive member repeatedly finds their direct reports.

---

## 12. When would you use a Recursive CTE?

Use it for hierarchical or parent-child relationships such as:

- Employee-manager hierarchies
- Product categories
- Organizational structures
- Folder trees
- Bill of materials

```sql
WITH CategoryTree AS (
    SELECT CategoryID, CategoryName, ParentID, 0 AS Level
    FROM Categories
    WHERE ParentID IS NULL

    UNION ALL

    SELECT c.CategoryID, c.CategoryName, c.ParentID, ct.Level + 1
    FROM Categories c
    JOIN CategoryTree ct
        ON c.ParentID = ct.CategoryID
)
SELECT *
FROM CategoryTree;
```

**Interview answer:** I would use a Recursive CTE whenever I need to traverse a parent-child hierarchy through multiple levels.

---

## 13. What is Dynamic SQL?

Dynamic SQL is SQL constructed and executed at runtime.

Example in SQL Server:

```sql
DECLARE @TableName NVARCHAR(100) = 'Employees';
DECLARE @SQL NVARCHAR(MAX);

SET @SQL =
    'SELECT * FROM ' + QUOTENAME(@TableName);

EXEC sp_executesql @SQL;
```

**Interview answer:** Dynamic SQL generates SQL statements at runtime and is useful when identifiers or query structure need to be dynamic.

---

## 14. What are the risks associated with Dynamic SQL?

The major risk is SQL injection when untrusted input is concatenated directly into SQL.

Unsafe:

```sql
SET @SQL =
    'SELECT * FROM Employees WHERE EmpName = ''' +
    @UserInput + '''';
```

Safer parameterized approach:

```sql
SET @SQL =
    N'SELECT * FROM Employees
      WHERE EmpName = @Name';

EXEC sp_executesql
    @SQL,
    N'@Name NVARCHAR(100)',
    @Name = @UserInput;
```

Other risks include difficult debugging, maintenance complexity, security issues, unexpected behavior, and potential performance problems.

**Interview answer:** The biggest risk is SQL injection. I would use parameterized dynamic SQL and carefully validate dynamic identifiers.

---

## 15. What is a Window Function?

A window function performs a calculation across related rows without collapsing them into one row per group.

```sql
SELECT
    EmpID,
    EmpName,
    DepartmentID,
    Salary,
    AVG(Salary) OVER (
        PARTITION BY DepartmentID
    ) AS DepartmentAvgSalary
FROM Employees;
```

Ranking example:

```sql
SELECT
    EmpName,
    Salary,
    ROW_NUMBER() OVER (
        ORDER BY Salary DESC
    ) AS SalaryRank
FROM Employees;
```

Common window functions:

```text
ROW_NUMBER()
RANK()
DENSE_RANK()
SUM()
AVG()
MIN()
MAX()
LAG()
LEAD()
```

**Interview answer:** A window function performs calculations across related rows while preserving individual rows. It is commonly used for ranking, running totals, moving averages, and row-to-row comparisons.

---

# Today's Checklist

- [x] Subquery
- [x] Nested Query
- [x] Correlated Subquery
- [x] Subquery vs Correlated Subquery
- [x] Types of Subqueries
- [x] CTE
- [x] Why use a CTE?
- [x] Temporary Table vs CTE
- [x] Recursive Query
- [x] Recursive CTE
- [x] Example of Recursive CTE
- [x] When to use Recursive CTE
- [x] Dynamic SQL
- [x] Risks of Dynamic SQL
- [x] Window Function

## SQL Progress

```text
Previous SQL completed: 90
Today's SQL questions:  +15
----------------------------
SQL completed:         105
SQL remaining:          62
```

> Monster Queries remain excluded from the interview-bank count.
