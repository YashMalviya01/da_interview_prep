/*PHASE 2 — SQL INTERVIEW QUERIES
Question 1 — SQL Ranking

Write a SQL query to find the 3rd highest salary from an Employee table without using TOP or LIMIT.*/

/*Type 1 */
SELECT MAX(Salary)
FROM Employee
WHERE Salary < (
    SELECT MAX(Salary)
    FROM Employee
    WHERE Salary < (
        SELECT MAX(Salary)
        FROM Employee
    )
);

/*Type 2*/
SELECT Salary
FROM (
    SELECT Salary,
           DENSE_RANK() OVER (ORDER BY Salary DESC) AS rnk
    FROM Employee
) t
WHERE rnk = 3;

/*Question 2 — Duplicate Records

You have:

Employee
---------
EmpID
EmpName
Dept
Salary
JoinDate

Write a query to remove duplicate employee records while keeping the latest record based on JoinDate.*/

/*Q3 — INNER JOIN, LEFT JOIN & CROSS JOIN*/

SELECT
    e.EmployeeName,
    d.DepartmentName
FROM Employees e
INNER JOIN Departments d
    ON e.DepartmentID = d.DepartmentID;

SELECT
    e.EmployeeName,
    d.DepartmentName
FROM Employees e
LEFT JOIN Departments d
    ON e.DepartmentID = d.DepartmentID;


SELECT
    e.EmployeeName,
    d.DepartmentName
FROM Employees e
CROSS JOIN Departments d;


/*Q4 — Department-wise Running Total*/

SELECT
    Dept,
    EmpID,
    Salary,
    SUM(Salary) OVER (
        PARTITION BY Dept
        ORDER BY EmpID
    ) AS RunningTotal
FROM Employee;


/*Q5 — Top 2 Products by Revenue per Region WITH TIES*/

WITH ProductRevenue AS (
    SELECT
        Region,
        Product,
        SUM(SalesAmount) AS Revenue
    FROM Sales
    GROUP BY Region, Product
),
RankedProducts AS (
    SELECT
        Region,
        Product,
        Revenue,
        DENSE_RANK() OVER (
            PARTITION BY Region
            ORDER BY Revenue DESC
        ) AS rnk
    FROM ProductRevenue
)
SELECT
    Region,
    Product,
    Revenue
FROM RankedProducts
WHERE rnk <= 2;

/*Q6 — Find Duplicate Records*/

SELECT
    EmpName,
    Dept,
    Salary,
    COUNT(*) AS DuplicateCount
FROM Employee
GROUP BY
    EmpName,
    Dept,
    Salary
HAVING COUNT(*) > 1;

/*Q7 — Second-Highest Salary*/

SELECT MAX(Salary) AS SecondHighestSalary
FROM Employee
WHERE Salary < (
    SELECT MAX(Salary)
    FROM Employee
);

/*Q8 — WHERE vs HAVING*/

SELECT
    Dept,
    AVG(Salary) AS AvgSalary
FROM Employee
WHERE Salary IS NOT NULL
GROUP BY Dept
HAVING AVG(Salary) > 50000;

/*Q9 — UNION vs UNION ALL*/

SELECT EmployeeName
FROM Employees_2024

UNION

SELECT EmployeeName
FROM Employees_2025;

SELECT EmployeeName
FROM Employees_2024

UNION ALL

SELECT EmployeeName
FROM Employees_2025;

/*Q10 — Find Employees Above Their Department Average*/

SELECT
    e.EmpID,
    e.EmpName,
    e.Dept,
    e.Salary
FROM Employee e
WHERE e.Salary > (
    SELECT AVG(e2.Salary)
    FROM Employee e2
    WHERE e2.Dept = e.Dept
);


/*Q11 — CTE*/

WITH AvgSalary AS (
    SELECT AVG(Salary) AS AverageSalary
    FROM Employee
)
SELECT
    e.EmpID,
    e.EmpName,
    e.Salary
FROM Employee e
CROSS JOIN AvgSalary a
WHERE e.Salary > a.AverageSalary;

/*Q12 — Handle NULL Values*/

SELECT
    EmpID,
    EmpName,
    COALESCE(Salary, 0) AS Salary
FROM Employee;


/*Q13 — Clustered vs Non-Clustered Index*/

/*Clustered*/

CREATE CLUSTERED INDEX IX_Employee_EmpID
ON Employee(EmpID);

/*Non-clustered*/

CREATE NONCLUSTERED INDEX IX_Employee_Dept
ON Employee(Dept);

/*Q14 — Optimize a Slow SQL Query*/

-- Instead of
SELECT *
FROM Orders
WHERE YEAR(OrderDate) = 2025;

-- Prefer
SELECT
    OrderID,
    CustomerID,
    OrderDate,
    Amount
FROM Orders
WHERE OrderDate >= '2025-01-01'
  AND OrderDate < '2026-01-01';


CREATE INDEX IX_Orders_OrderDate
ON Orders(OrderDate);


/*Q15 — Find Customers Who Never Placed an Order*/

SELECT
    c.CustomerID,
    c.CustomerName
FROM Customers c
LEFT JOIN Orders o
    ON c.CustomerID = o.CustomerID
WHERE o.CustomerID IS NULL;

/*Q16 — Running Total / Cumulative Revenue*/

SELECT
    SaleDate,
    Revenue,
    SUM(Revenue) OVER (
        ORDER BY SaleDate
    ) AS CumulativeRevenue
FROM Sales
ORDER BY SaleDate;


SELECT
    CustomerID,
    SaleDate,
    Revenue,
    SUM(Revenue) OVER (
        PARTITION BY CustomerID
        ORDER BY SaleDate
    ) AS CustomerCumulativeRevenue
FROM Sales;

/*Q17 — Employees in the Same Department as the Highest-Paid Employee*/

WITH HighestPaid AS (
    SELECT Dept
    FROM Employee
    WHERE Salary = (
        SELECT MAX(Salary)
        FROM Employee
    )
)
SELECT
    e.EmpID,
    e.EmpName,
    e.Dept
FROM Employee e
JOIN HighestPaid h
    ON e.Dept = h.Dept;
