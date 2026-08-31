# Part A — SQL (15 Questions)

## Q136. How do you calculate age from Date of Birth?

```sql
SELECT
    EmployeeID,
    TIMESTAMPDIFF(YEAR, DateOfBirth, CURDATE()) AS Age
FROM Employees;
```

**Explanation:** In MySQL, `TIMESTAMPDIFF` calculates completed years between the date of birth and today. Date functions vary by SQL dialect.

## Q137. How do you calculate percentages in SQL?

```sql
SELECT
    Category,
    SUM(Sales) AS CategorySales,
    ROUND(100.0 * SUM(Sales) / SUM(SUM(Sales)) OVER (), 2) AS SalesPercentage
FROM Orders
GROUP BY Category;
```

**Explanation:** Divide each category total by the overall total and multiply by 100.

## Q138. How do you find the department with the highest employee count?

```sql
SELECT DepartmentID, COUNT(*) AS EmployeeCount
FROM Employees
GROUP BY DepartmentID
ORDER BY EmployeeCount DESC
LIMIT 1;
```

**Explanation:** Group by department, count employees, sort descending, and return the largest count.

## Q139. How do you find the number of employees in each department?

```sql
SELECT DepartmentID, COUNT(*) AS EmployeeCount
FROM Employees
GROUP BY DepartmentID;
```

**Explanation:** `GROUP BY` creates one group per department and `COUNT(*)` counts its employees.

## Q140. How do you find the highest-paid employee in each department?

```sql
WITH RankedEmployees AS (
    SELECT *,
           RANK() OVER (
               PARTITION BY DepartmentID
               ORDER BY Salary DESC
           ) AS rnk
    FROM Employees
)
SELECT *
FROM RankedEmployees
WHERE rnk = 1;
```

**Explanation:** `RANK()` ranks salaries within each department. `rnk = 1` includes ties.

## Q141. How do you find customers who have never placed an order?

```sql
SELECT c.CustomerID, c.CustomerName
FROM Customers c
LEFT JOIN Orders o
    ON c.CustomerID = o.CustomerID
WHERE o.CustomerID IS NULL;
```

**Explanation:** A `LEFT JOIN` keeps every customer; NULL on the order side identifies customers with no matching order.

## Q142. Given Orders, Customers and Products tables, how would you find customers who never placed an order?

```sql
SELECT c.CustomerID, c.CustomerName
FROM Customers c
LEFT JOIN Orders o
    ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;
```

**Explanation:** The Products table is unnecessary because the requirement only concerns whether a customer has an order.

## Q143. How do you identify customers who have made transactions above $5,000 multiple times?

```sql
SELECT CustomerID, COUNT(*) AS TransactionCount
FROM Transactions
WHERE Amount > 5000
GROUP BY CustomerID
HAVING COUNT(*) > 1;
```

**Explanation:** Filter transactions above $5,000, group by customer, and use `HAVING` to keep customers with more than one qualifying transaction.

## Q144. How do you fetch the first five characters of a string?

```sql
SELECT LEFT(CustomerName, 5) AS FirstFiveCharacters
FROM Customers;
```

**Explanation:** In MySQL, `LEFT()` returns the requested number of characters from the beginning of a string.

## Q145. What are different ways to extract the first five characters from a string?

```sql
SELECT LEFT(CustomerName, 5)
FROM Customers;

SELECT SUBSTRING(CustomerName, 1, 5)
FROM Customers;
```

**Explanation:** `LEFT()` and `SUBSTRING()` can both extract the first five characters in MySQL.

## Q146. What are ACID properties?

**Solution:** ACID means **Atomicity, Consistency, Isolation, and Durability**.

```sql
START TRANSACTION;

UPDATE Accounts
SET Balance = Balance - 100
WHERE AccountID = 1;

UPDATE Accounts
SET Balance = Balance + 100
WHERE AccountID = 2;

COMMIT;
```

**Explanation:** ACID properties provide key guarantees for reliable database transactions.

## Q147. What is a Transaction?

```sql
START TRANSACTION;

UPDATE Accounts
SET Balance = Balance - 500
WHERE AccountID = 1;

UPDATE Accounts
SET Balance = Balance + 500
WHERE AccountID = 2;

COMMIT;
```

**Explanation:** A transaction is a logical unit of work containing one or more operations that should be committed together or rolled back when appropriate.

## Q148. What is the difference between COMMIT and ROLLBACK?

```sql
START TRANSACTION;

UPDATE Employees
SET Salary = Salary * 1.10
WHERE DepartmentID = 10;

COMMIT;

-- ROLLBACK;  -- would undo uncommitted changes instead
```

**Explanation:** `COMMIT` saves the transactions changes, while `ROLLBACK` undoes uncommitted changes.

## Q149. What is a Savepoint?

```sql
START TRANSACTION;

UPDATE Accounts
SET Balance = Balance - 100
WHERE AccountID = 1;

SAVEPOINT before_second_update;

UPDATE Accounts
SET Balance = Balance + 100
WHERE AccountID = 2;

ROLLBACK TO SAVEPOINT before_second_update;

COMMIT;
```

**Explanation:** A savepoint marks a point inside a transaction so later changes can be rolled back to that point without rolling back the entire transaction.

## Q150. What is the difference between IN and EXISTS?

```sql
-- IN
SELECT *
FROM Customers
WHERE CustomerID IN (
    SELECT CustomerID
    FROM Orders
);

-- EXISTS
SELECT *
FROM Customers c
WHERE EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.CustomerID = c.CustomerID
);
```
