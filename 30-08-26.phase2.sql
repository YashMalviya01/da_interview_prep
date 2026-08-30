
# Part A — SQL: 15 Questions with Solutions

## Q1. Remove duplicates using a CTE

```sql
WITH RankedRecords AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY EmpID, Email
               ORDER BY UpdatedAt DESC
           ) AS rn
    FROM Employees
)
SELECT *
FROM RankedRecords
WHERE rn = 1;
```

**Interview answer:** Use a CTE with ROW_NUMBER() to rank each duplicate group and retain rn = 1.

## Q2. Remove duplicates using a SELF JOIN

```sql
DELETE e1
FROM Employees e1
JOIN Employees e2
  ON e1.Email = e2.Email
 AND e1.UpdatedAt < e2.UpdatedAt;
```

**Interview answer:** Self-join the table on the duplicate key and identify the older record for removal.

## Q3. Identify duplicate rows without deleting

```sql
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY EmpID, Email
               ORDER BY UpdatedAt DESC
           ) AS rn
    FROM Employees
) x
WHERE rn > 1;
```

**Interview answer:** Rows with rn > 1 are duplicate copies; no data is modified.

## Q4. Return distinct records without DISTINCT

```sql
SELECT CustomerID, Email
FROM Customers
GROUP BY CustomerID, Email;
```

**Interview answer:** GROUP BY on the required columns returns unique combinations.

## Q5. Employees who joined in the last 3 months

```sql
SELECT *
FROM Employees
WHERE JoinDate >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH);
```

**Interview answer:** Compare JoinDate with the date three months before today. Date syntax varies by SQL dialect.

## Q6. Employees without managers

```sql
SELECT *
FROM Employees
WHERE ManagerID IS NULL;
```

**Interview answer:** Filter rows where ManagerID is NULL.

## Q7. First name starts with A

```sql
SELECT *
FROM Employees
WHERE FirstName LIKE 'A%';
```

**Interview answer:** LIKE 'A%' matches strings beginning with A.

## Q8. Fetch alternate rows

```sql
WITH NumberedRows AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY EmpID) AS rn
    FROM Employees
)
SELECT *
FROM NumberedRows
WHERE rn % 2 = 1;
```

**Interview answer:** Assign row numbers and select alternating positions.

## Q9. Find odd-numbered records

```sql
WITH NumberedRows AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY EmpID) AS rn
    FROM Employees
)
SELECT *
FROM NumberedRows
WHERE rn % 2 = 1;
```

**Interview answer:** Filter row numbers whose remainder after division by 2 is 1.

## Q10. Find even-numbered records

```sql
WITH NumberedRows AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY EmpID) AS rn
    FROM Employees
)
SELECT *
FROM NumberedRows
WHERE rn % 2 = 0;
```

**Interview answer:** Filter row numbers divisible by 2.

## Q11. Display first 5 records

```sql
SELECT *
FROM Employees
ORDER BY EmpID
LIMIT 5;
```

**Interview answer:** LIMIT 5 returns five rows; SQL Server commonly uses TOP 5.

## Q12. Display last 3 records

```sql
SELECT *
FROM Employees
ORDER BY EmpID DESC
LIMIT 3;
```

**Interview answer:** Sort descending and take three rows; use the appropriate dialect-specific row limiter.

## Q13. Retrieve the Nth record

```sql
WITH NumberedEmployees AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY EmpID) AS rn
    FROM Employees
)
SELECT *
FROM NumberedEmployees
WHERE rn = 5;
```

**Interview answer:** Assign sequential row numbers and filter for N.

## Q14. Find the last ID

```sql
SELECT MAX(EmpID) AS LastID
FROM Employees;
```

**Interview answer:** MAX() gives the largest numeric ID. If 'last' means most recently created, use CreatedAt instead.

## Q15. Swap two columns

```sql
UPDATE Employees
SET FirstName = LastName,
    LastName = FirstName;
```

**Interview answer:** Swap the two column values in an UPDATE; validate behavior for the target database before production use.

