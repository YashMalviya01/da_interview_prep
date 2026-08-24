# SQL Interview Preparation — Next 15 Questions

> **Source:** Remaining SQL interview-question bank  
> **Rules:** No Monster Queries, no previously completed questions, and no recycled questions.

---

## 1. What is Normalization?

### Answer

Normalization is the process of organizing data in a relational database to reduce data redundancy and improve data integrity.

Common normal forms include:

- **1NF:** Atomic values and no repeating groups.
- **2NF:** 1NF + no partial dependency on part of a composite key.
- **3NF:** 2NF + no transitive dependency on a non-key attribute.

### Example

Instead of storing:

```text
OrderID | CustomerName | CustomerCity | Product
------------------------------------------------
101     | John         | New York     | Laptop
102     | John         | New York     | Mouse
```

We can separate customer information:

```text
Customers
---------
CustomerID
CustomerName
CustomerCity

Orders
------
OrderID
CustomerID
Product
```

**Interview answer:**

> Normalization organizes data into related tables to reduce redundancy and prevent update, insert, and delete anomalies while maintaining data integrity.

---

## 2. What is Denormalization?

### Answer

Denormalization is the intentional introduction of redundancy into a database to improve read performance or simplify queries.

For example, a reporting table might store:

```text
OrderID
CustomerName
CustomerCity
Product
Revenue
```

This duplicates customer information but can reduce the number of joins required for analytical queries.

**Interview answer:**

> Denormalization intentionally introduces some data redundancy to improve read performance or simplify analytical queries. The trade-off is increased storage and a greater risk of inconsistent duplicated data.

---

## 3. What is the difference between Normalization and Denormalization?

| Normalization | Denormalization |
|---|---|
| Reduces redundancy | Intentionally introduces redundancy |
| Improves data integrity | Can improve read performance |
| Uses more related tables | May combine information |
| Requires more joins | Can reduce joins |
| Common in OLTP systems | Common in analytical/reporting workloads |

**Interview answer:**

> Normalization focuses on reducing redundancy and maintaining data integrity, while denormalization accepts some redundancy to improve read performance and simplify queries.

---

## 4. What is a View?

### Answer

A **View** is a virtual table based on the result of a SQL query.

```sql
CREATE VIEW SalesSummary AS
SELECT
    CustomerID,
    SUM(Revenue) AS TotalRevenue
FROM Sales
GROUP BY CustomerID;
```

We can then query it like a table:

```sql
SELECT *
FROM SalesSummary;
```

A standard view generally stores the query definition rather than a separate copy of the underlying data.

**Interview answer:**

> A view is a virtual table created from a SQL query. It can simplify complex queries, provide a reusable interface to data, and help restrict access to selected columns or rows.

---

## 5. What is the difference between a View and a Table?

| View | Table |
|---|---|
| Virtual/query-based object | Stores data |
| Usually stores a query definition | Stores rows directly |
| Data comes from underlying tables | Data is stored directly |
| Useful for abstraction and security | Primary storage structure |

Example:

```sql
CREATE VIEW ActiveEmployees AS
SELECT *
FROM Employees
WHERE Status = 'Active';
```

**Interview answer:**

> A table physically stores data, while a view presents the result of a query over one or more underlying tables.

---

## 6. What is a Trigger?

### Answer

A **Trigger** is database logic that automatically executes when a specified event occurs on a table or other database object, depending on the DBMS.

Example in SQL Server:

```sql
CREATE TRIGGER trg_AuditEmployee
ON Employees
AFTER INSERT
AS
BEGIN
    INSERT INTO EmployeeAudit(EmployeeID, ActionType)
    SELECT EmpID, 'INSERT'
    FROM inserted;
END;
```

Common uses include:

- Auditing
- Logging changes
- Enforcing business rules
- Maintaining derived information

**Interview answer:**

> A trigger is database logic that automatically executes in response to events such as INSERT, UPDATE, or DELETE. It is commonly used for auditing and enforcing certain database rules.

---

## 7. What is a Cursor?

### Answer

A **Cursor** allows a database application or stored program to process query results row by row.

Conceptually:

```text
Query Result
     ↓
Open Cursor
     ↓
Fetch Row
     ↓
Process Row
     ↓
Fetch Next Row
     ↓
Close Cursor
```

Example in SQL Server:

```sql
DECLARE employee_cursor CURSOR FOR
SELECT EmpID, EmpName
FROM Employees;

OPEN employee_cursor;

FETCH NEXT FROM employee_cursor
INTO @EmpID, @EmpName;

-- Process rows...

CLOSE employee_cursor;
DEALLOCATE employee_cursor;
```

**Interview answer:**

> A cursor processes a result set row by row. It can be useful when procedural row-level processing is required, but set-based SQL operations are generally preferred when possible because they are usually more efficient.

---

## 8. What is Case Sensitivity in SQL?

### Answer

Case sensitivity determines whether a database treats uppercase and lowercase characters as different when comparing text.

For example:

```text
'John'
'john'
```

may be treated as either equal or different depending on the DBMS and collation.

In SQL Server, this behavior is commonly controlled by the database or column **collation**.

**Interview answer:**

> SQL case sensitivity is database-system and collation dependent. Some configurations treat uppercase and lowercase text as equal, while case-sensitive configurations treat them as different.

---

## 9. What is `GROUP BY`?

### Answer

`GROUP BY` groups rows with the same values so aggregate functions can be applied to each group.

```sql
SELECT
    DepartmentID,
    COUNT(*) AS EmployeeCount,
    AVG(Salary) AS AverageSalary
FROM Employees
GROUP BY DepartmentID;
```

This returns one row per department.

**Interview answer:**

> `GROUP BY` groups rows based on one or more columns and allows aggregate functions such as `COUNT`, `SUM`, `AVG`, `MIN`, and `MAX` to be calculated for each group.

---

## 10. What is the difference between `GROUP BY` and `ORDER BY`?

### `GROUP BY`

Creates groups for aggregation.

```sql
SELECT
    DepartmentID,
    AVG(Salary) AS AvgSalary
FROM Employees
GROUP BY DepartmentID;
```

### `ORDER BY`

Sorts the resulting rows.

```sql
SELECT
    EmpName,
    Salary
FROM Employees
ORDER BY Salary DESC;
```

### Key distinction

```text
GROUP BY → Groups rows
ORDER BY → Sorts rows
```

They can also be used together:

```sql
SELECT
    DepartmentID,
    AVG(Salary) AS AvgSalary
FROM Employees
GROUP BY DepartmentID
ORDER BY AvgSalary DESC;
```

---

## 11. What is `LIMIT` and when is it used?

### Answer

`LIMIT` restricts the number of rows returned by SQL dialects that support it, such as MySQL and PostgreSQL.

```sql
SELECT *
FROM Employees
ORDER BY Salary DESC
LIMIT 5;
```

This returns the five highest-paid employees.

It can also be used with an offset:

```sql
SELECT *
FROM Employees
ORDER BY EmpID
LIMIT 10 OFFSET 20;
```

This skips the first 20 rows and returns the next 10.

**Interview point:**

`LIMIT` is DBMS-specific. SQL Server commonly uses `TOP` or `OFFSET ... FETCH`.

---

## 12. What is conditional aggregation in SQL?

### Answer

Conditional aggregation combines aggregate functions with conditional logic, usually `CASE`, to calculate multiple business metrics in one query.

```sql
SELECT
    DepartmentID,
    COUNT(*) AS TotalEmployees,
    SUM(
        CASE
            WHEN Salary >= 70000 THEN 1
            ELSE 0
        END
    ) AS HighSalaryEmployees
FROM Employees
GROUP BY DepartmentID;
```

Another example:

```sql
SELECT
    SUM(
        CASE
            WHEN Status = 'Completed'
            THEN Revenue
            ELSE 0
        END
    ) AS CompletedRevenue
FROM Orders;
```

**Interview answer:**

> Conditional aggregation uses aggregate functions together with conditional logic to calculate metrics for specific subsets of data within the same query.

---

## 13. How do you calculate a percentage in SQL?

### Answer

A common pattern is:

```text
Part / Total × 100
```

Example:

```sql
SELECT
    100.0 *
    SUM(
        CASE
            WHEN Status = 'Completed'
            THEN 1
            ELSE 0
        END
    ) / COUNT(*) AS CompletionRate
FROM Orders;
```

Using `100.0` rather than `100` helps avoid integer-division issues in some database systems.

### Percentage by department

```sql
SELECT
    DepartmentID,
    100.0 * COUNT(*) /
    SUM(COUNT(*)) OVER () AS DepartmentPercentage
FROM Employees
GROUP BY DepartmentID;
```

**Interview answer:**

> I calculate a percentage by dividing the relevant subset by the appropriate total and multiplying by 100. I also make sure the calculation uses an appropriate numeric type so integer division does not truncate the result.

---

## 14. What is `NVL()`?

### Answer

`NVL()` is an Oracle function used to replace a `NULL` value with another value.

```sql
SELECT
    EmpName,
    NVL(Commission, 0) AS Commission
FROM Employees;
```

If `Commission` is `NULL`, the query returns `0`.

Conceptually:

```text
NVL(value, replacement)
```

For example:

```text
NVL(NULL, 0) → 0
NVL(500, 0)  → 500
```

Other database systems commonly use:

```sql
COALESCE(Commission, 0)
```

**Interview answer:**

> `NVL()` is an Oracle function used to replace NULL with a specified replacement value. In many other SQL systems, `COALESCE()` is commonly used for the same purpose.

---

## 15. What is a `CASE` statement?

### Answer

`CASE` provides conditional logic inside SQL.

```sql
SELECT
    EmpName,
    Salary,
    CASE
        WHEN Salary >= 100000 THEN 'High'
        WHEN Salary >= 60000 THEN 'Medium'
        ELSE 'Low'
    END AS SalaryCategory
FROM Employees;
```

Example result:

```text
EmpName | Salary | SalaryCategory
---------------------------------
John    | 120000 | High
Sarah   | 75000  | Medium
Alex    | 45000  | Low
```

It can also be used in aggregation:

```sql
SELECT
    SUM(
        CASE
            WHEN Status = 'Completed'
            THEN Revenue
            ELSE 0
        END
    ) AS CompletedRevenue
FROM Orders;
```

**Interview answer:**

> `CASE` provides conditional logic in SQL. It can be used to create categories, transform values, and perform conditional aggregation.

---

# Today's 15-Question Checklist

- [x] Normalization
- [x] Denormalization
- [x] Normalization vs Denormalization
- [x] Views
- [x] Views vs Tables
- [x] Triggers
- [x] Cursors
- [x] Case Sensitivity
- [x] `GROUP BY`
- [x] `GROUP BY` vs `ORDER BY`
- [x] `LIMIT`
- [x] Conditional Aggregation
- [x] Percentage Calculations
- [x] `NVL()`
- [x] `CASE`

## SQL Progress

```text
Previous SQL completed: 60
Today's SQL questions:  +15
--------------------------------
SQL completed:          75
SQL remaining:          92
```

> **Monster Queries remain excluded from the interview-bank count.**

