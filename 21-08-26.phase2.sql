/*SQL Phase 2 — Today's 15 NEW Questions*/

/*1. FULL JOIN

Question: Find all employees and departments, including records that don't have a match on either side.*/

SELECT
    e.EmpName,
    d.DeptName
FROM Employees e
FULL JOIN Departments d
    ON e.DeptID = d.DeptID;

/*2. SELF JOIN

Question: Display each employee along with their manager's name.*/

SELECT
    e.EmpName AS Employee,
    m.EmpName AS Manager
FROM Employees e
LEFT JOIN Employees m
    ON e.ManagerID = m.EmpID;

/*3. Find Employees Without Managers

Using the same employee table, find employees who don't have a manager.*/

SELECT
    EmpID,
    EmpName
FROM Employees
WHERE ManagerID IS NULL;

/*4. EXISTS

Question: Find customers who have placed at least one order using EXISTS.*/

SELECT
    c.CustomerID,
    c.CustomerName
FROM Customers c
WHERE EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.CustomerID = c.CustomerID
);

/*5. NOT EXISTS

Question: Find customers who have not placed any orders.*/

SELECT
    c.CustomerID,
    c.CustomerName
FROM Customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.CustomerID = c.CustomerID
);

/*6. Calculate Percentage

Question: Calculate each department's percentage contribution to the total number of employees.*/

SELECT
    Dept,
    COUNT(*) AS EmployeeCount,
    COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM Employees) AS EmployeePercentage
FROM Employees
GROUP BY Dept;


/*. Indexing

Question: Create an index on Email to speed up searches.*/

CREATE INDEX idx_employee_email
ON Employees(Email);


/*8. Composite Index

Question: Create an index for queries that frequently filter by both DepartmentID and Salary.*/

CREATE INDEX idx_dept_salary
ON Employees(DepartmentID, Salary);

/*9. Table Partitioning

Question: What is table partitioning, and how can it improve performance for very large tables?*/

CREATE TABLE Sales (
    SaleID INT,
    SaleDate DATE,
    Revenue DECIMAL(12,2)
)
PARTITION BY RANGE (SaleDate);

/*10. Avoid Deadlocks

Question: What is a SQL deadlock, and how can you reduce the likelihood of deadlocks?*/

BEGIN;

UPDATE Accounts
SET Balance = Balance - 500
WHERE AccountID = 1;

UPDATE Accounts
SET Balance = Balance + 500
WHERE AccountID = 2;

COMMIT;

/*11. Stored Procedure vs Function

Question: What is the difference between a stored procedure and a function?

Stored*/

CREATE PROCEDURE GetEmployeesByDept
    @DeptID INT
AS
BEGIN
    SELECT *
    FROM Employees
    WHERE DeptID = @DeptID;
END;

CREATE FUNCTION GetAnnualSalary
(
    @MonthlySalary DECIMAL(10,2)
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN @MonthlySalary * 12;
END;

/*2. OLTP vs OLAP

Question: What is the difference between OLTP and OLAP? Give a practical example of each.

OLTP
→ Transaction processing
→ Frequent INSERT/UPDATE/DELETE
→ Highly normalized operational data
→ Example: banking transactions / order processing


OLAP
→ Analytical processing
→ Large read-heavy queries
→ Aggregations and historical analysis
→ Example: sales analytics / BI reporting*/

/*13. Dynamic SQL

Question: What is Dynamic SQL and when would you use it?*/

DECLARE @SQL NVARCHAR(MAX);

SET @SQL = '
    SELECT *
    FROM Employees
    WHERE DepartmentID = @DeptID
';

EXEC sp_executesql
    @SQL,
    N'@DeptID INT',
    @DeptID = 10;


14. Query Execution Plan

Question: What is a query execution plan, and why would you use it when troubleshooting a slow query?

EXPLAIN
SELECT
    *
FROM Orders
WHERE CustomerID = 1001;
Depending on the RDBMS, the command may be EXPLAIN, EXPLAIN ANALYZE, or an execution-plan tool.

Look for:

→ Table scans
→ Index usage
→ Join strategy
→ Sort operations
→ Estimated vs actual rows
→ Expensive operators
