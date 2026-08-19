
/* Q1 — Find Duplicate Records */
Question: /* How do you find duplicate records in a table? Assume duplicates are defined by EmpName, Dept, and
Salary. */
SELECT EmpName, Dept, Salary, COUNT(*) AS DuplicateCount
FROM Employee
GROUP BY EmpName, Dept, Salary
HAVING COUNT(*) > 1;
Pattern: GROUP BY identifies duplicate groups; COUNT(*) counts occurrences; HAVING > 1 keeps duplicates.

  
/* Q2 — WHERE vs HAVING */
Question: /* What is the difference between WHERE and HAVING? Example: find departments whose average
salary is greater than 50,000. */
SELECT Dept, AVG(Salary) AS AvgSalary
FROM Employee
WHERE Salary IS NOT NULL
GROUP BY Dept
HAVING AVG(Salary) > 50000;
WHERE filters rows. GROUP BY creates groups. HAVING filters groups.

  
/* Q3 — Common Table Expression (CTE) */
Question: /* What is a CTE and when would you use one? Example: find employees earning more than the
company-wide average salary. */
WITH AvgSalary AS (
SELECT AVG(Salary) AS AverageSalary
FROM Employee
)
SELECT e.EmpID, e.EmpName, e.Salary
FROM Employee e
CROSS JOIN AvgSalary a
WHERE e.Salary > a.AverageSalary;
Pattern: WITH CTE_Name AS (...) creates a named result set used by the following statement.

  
/* Q4 — Correlated Subquery */
Question: /* What is a correlated subquery? Example: find employees earning more than their department's average
salary. */
SELECT e.EmpID, e.EmpName, e.Dept, e.Salary
FROM Employee e
WHERE e.Salary > (
SELECT AVG(e2.Salary)
FROM Employee e2
WHERE e2.Dept = e.Dept
);
Key pattern: the inner query references the outer query, making it correlated.

  
/* Q5 — RANK vs DENSE_RANK */
Question: /* What is the difference between RANK() and DENSE_RANK()? */
SELECT EmpName, Salary,
RANK() OVER (ORDER BY Salary DESC) AS SalaryRank,
DENSE_RANK() OVER (ORDER BY Salary DESC) AS SalaryDenseRank
FROM Employee;
RANK creates gaps after ties. DENSE_RANK does not create gaps after ties.

  
/* Q6 — ROW_NUMBER */
Question: /* What is ROW_NUMBER() and how does it differ from RANK()? */
SELECT EmpName, Salary,
ROW_NUMBER() OVER (ORDER BY Salary DESC) AS RowNum
FROM Employee;
ROW_NUMBER gives every row a unique number. RANK gives tied rows the same rank and creates gaps.

  
/* Q7 — Second-Highest Salary */
Question: /* Find the second-highest distinct salary. */
SELECT MAX(Salary) AS SecondHighestSalary
FROM Employee
WHERE Salary < (
SELECT MAX(Salary)
FROM Employee
);
Alternative: use DENSE_RANK() and filter rnk = 2. This handles duplicate salaries cleanly.

  
/* Q8 — Employees Above Department Average */
Question: /* Find employees whose salary is greater than the average salary of their own department. */
SELECT e.EmpID, e.EmpName, e.Dept, e.Salary
FROM Employee e
WHERE e.Salary > (
SELECT AVG(e2.Salary)
FROM Employee e2
WHERE e2.Dept = e.Dept
);
/*Outer query = employee. Inner query = that employee's department average.*/


/* Q9 — Customers Who Never Ordered */
Question: /* Given Customers(CustomerID, CustomerName) and Orders(OrderID, CustomerID), find customers who
never placed an order. */
SELECT c.CustomerID, c.CustomerName
FROM Customers c
LEFT JOIN Orders o
ON c.CustomerID = o.CustomerID
WHERE o.CustomerID IS NULL;
Alternative: NOT EXISTS. This is a classic anti-join pattern.

  
/* Q10 — UNION vs UNION ALL */
Question: /* What is the difference between UNION and UNION ALL? */
-- UNION removes duplicates
SELECT EmployeeName FROM Employees_2024
UNION
SELECT EmployeeName FROM Employees_2025;
-- UNION ALL keeps duplicates
SELECT EmployeeName FROM Employees_2024
UNION ALL
SELECT EmployeeName FROM Employees_2025;
UNION removes duplicates. UNION ALL retains duplicates.

  
/* Q11 — NULL Handling / COALESCE */
Question: /* How do you handle NULL values in SQL? Explain COALESCE(). */
SELECT EmpID, EmpName,
COALESCE(Salary, 0) AS Salary
FROM Employee;
COALESCE(value, replacement) returns the first non-NULL value.

  
/* Q12 — Running / Cumulative Total */
Question: /* Given Sales(SaleDate, Revenue), calculate cumulative revenue ordered by SaleDate. */
SELECT SaleDate, Revenue,
SUM(Revenue) OVER (ORDER BY SaleDate) AS CumulativeRevenue
FROM Sales
ORDER BY SaleDate;
For a per-customer cumulative total, add PARTITION BY CustomerID inside the window.

  
/* Q13 — Top 2 Products per Region WITH Ties */
Question: /* Given Sales(Region, Product, SalesAmount), find the top 2 products by total revenue in each region,
including ties. */
WITH ProductRevenue AS (
SELECT Region, Product, SUM(SalesAmount) AS Revenue
FROM Sales
GROUP BY Region, Product
),
RankedProducts AS (
SELECT Region, Product, Revenue,
DENSE_RANK() OVER (
PARTITION BY Region
ORDER BY Revenue DESC
) AS rnk
FROM ProductRevenue
)
SELECT Region, Product, Revenue
FROM RankedProducts
WHERE rnk <= 2;
Pattern: aggregate → rank within each region → keep ranks 1–2. WITH TIES points to RANK/DENSE_RANK rather
than ROW_NUMBER.

  
/* Q14 — Optimize a Slow SQL Query */
Question: /* A query goes from 2 seconds to 30 seconds. How do you investigate and optimize it? */
-- Less efficient
SELECT *
FROM Orders
WHERE YEAR(OrderDate) = 2025;
-- More index-friendly
SELECT OrderID, CustomerID, OrderDate, Amount
FROM Orders
WHERE OrderDate >= '2025-01-01'
AND OrderDate < '2026-01-01';
-- Potential index
CREATE INDEX IX_Orders_OrderDate
ON Orders(OrderDate);
Investigate the execution plan first. Check expensive operations, indexes, joins, filters, table scans, data volume, and
whether partitioning is appropriate. Do not blindly add indexes.

  
/* Q15 — Same Department as Highest-Paid Employee */
Question: /* Given Employee(EmpID, EmpName, Dept, Salary), find all employees who work in the same department
as the highest-paid employee. */
SELECT e.EmpID, e.EmpName, e.Dept
FROM Employee e
WHERE e.Dept = (
SELECT Dept
FROM Employee
WHERE Salary = (
SELECT MAX(Salary)
FROM Employee
)
);
Pattern: find MAX salary → find that employee's department → return all employees in that department.
