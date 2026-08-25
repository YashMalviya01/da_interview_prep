# SQL Interview Preparation — Today's Next 15

> Remaining SQL bank only. No Monster Queries, no previously completed questions, no recycled questions.

## 1. What are SQL Set Operators?

Set operators combine the results of compatible `SELECT` statements.

Common operators:
- `UNION`
- `UNION ALL`
- `INTERSECT`
- `EXCEPT` / `MINUS` depending on the DBMS

```sql
SELECT CustomerID FROM Customers_2025
UNION
SELECT CustomerID FROM Customers_2026;
```

**Interview answer:** Set operators combine result sets from compatible queries. The most common are `UNION`, `UNION ALL`, `INTERSECT`, and `EXCEPT`, with exact support depending on the database.

---

## 2. What is the difference between `UNION` and `UNION ALL`?

`UNION` removes duplicate rows; `UNION ALL` preserves them.

```sql
SELECT CustomerID FROM Customers_2025
UNION
SELECT CustomerID FROM Customers_2026;
```

```sql
SELECT CustomerID FROM Customers_2025
UNION ALL
SELECT CustomerID FROM Customers_2026;
```

**Interview answer:** `UNION` removes duplicates, while `UNION ALL` preserves duplicates and is generally preferable when deduplication is unnecessary.

---

## 3. What is the difference between `UNION` and `JOIN`?

`UNION` combines rows vertically; `JOIN` combines columns horizontally using a relationship.

```sql
SELECT CustomerID FROM OnlineCustomers
UNION
SELECT CustomerID FROM StoreCustomers;
```

```sql
SELECT c.CustomerID, c.CustomerName, o.OrderID
FROM Customers c
JOIN Orders o
  ON c.CustomerID = o.CustomerID;
```

**Interview answer:** `UNION` combines compatible result sets vertically, while `JOIN` combines related tables horizontally.

---

## 4. How do you fetch common records from two tables?

Using `INNER JOIN`:

```sql
SELECT DISTINCT a.CustomerID
FROM TableA a
INNER JOIN TableB b
  ON a.CustomerID = b.CustomerID;
```

Or, where supported:

```sql
SELECT CustomerID FROM TableA
INTERSECT
SELECT CustomerID FROM TableB;
```

**Interview answer:** Use `INNER JOIN` or `INTERSECT` to return values present in both tables.

---

## 5. How do you fetch common records from two tables without using `JOIN`?

Use `EXISTS`:

```sql
SELECT DISTINCT a.CustomerID
FROM TableA a
WHERE EXISTS (
    SELECT 1
    FROM TableB b
    WHERE b.CustomerID = a.CustomerID
);
```

Or, where supported:

```sql
SELECT CustomerID FROM TableA
INTERSECT
SELECT CustomerID FROM TableB;
```

**Interview answer:** `EXISTS` can test whether a matching record exists without explicitly joining the tables.

---

## 6. How do you get unique records without using `DISTINCT`?

Use `GROUP BY`:

```sql
SELECT CustomerID
FROM Customers
GROUP BY CustomerID;
```

For multiple columns:

```sql
SELECT CustomerID, Region
FROM Customers
GROUP BY CustomerID, Region;
```

**Interview answer:** `GROUP BY` can return unique combinations of selected columns without using `DISTINCT`.

---

# SQL Joins

## 7. What are Joins in SQL?

A JOIN combines rows from two or more tables using a related column or condition.

```sql
SELECT e.EmpName, d.DeptName
FROM Employees e
INNER JOIN Departments d
  ON e.DeptID = d.DeptID;
```

Common joins:
- `INNER JOIN`
- `LEFT JOIN`
- `RIGHT JOIN`
- `FULL OUTER JOIN`
- `CROSS JOIN`
- `SELF JOIN`

**Interview answer:** Joins combine related data stored in different tables. The appropriate join type depends on whether matching and/or unmatched records are required.

---

## 8. What is an `INNER JOIN`?

An `INNER JOIN` returns only rows where the join condition matches in both tables.

```sql
SELECT e.EmpID, e.EmpName, d.DeptName
FROM Employees e
INNER JOIN Departments d
  ON e.DeptID = d.DeptID;
```

**Interview answer:** An INNER JOIN returns only records that have matching values in both tables.

---

## 9. What is a `LEFT JOIN`?

A `LEFT JOIN` returns every row from the left table and matching rows from the right table. Unmatched right-side values become `NULL`.

```sql
SELECT c.CustomerID, c.CustomerName, o.OrderID
FROM Customers c
LEFT JOIN Orders o
  ON c.CustomerID = o.CustomerID;
```

Find customers with no orders:

```sql
SELECT c.CustomerID, c.CustomerName
FROM Customers c
LEFT JOIN Orders o
  ON c.CustomerID = o.CustomerID
WHERE o.CustomerID IS NULL;
```

**Interview answer:** A LEFT JOIN keeps all left-table rows and adds matching right-table data; unmatched right-side columns are `NULL`.

---

## 10. What is a `RIGHT JOIN`?

A `RIGHT JOIN` returns every row from the right table and matching rows from the left table.

```sql
SELECT e.EmpName, d.DeptName
FROM Employees e
RIGHT JOIN Departments d
  ON e.DeptID = d.DeptID;
```

**Interview answer:** A RIGHT JOIN preserves every row from the right table and returns matching rows from the left. It can often be rewritten as a LEFT JOIN by reversing table order.

---

## 11. What is a `FULL OUTER JOIN`?

A `FULL OUTER JOIN` returns matching rows plus unmatched rows from both tables.

```sql
SELECT e.EmpID, e.EmpName, d.DeptID, d.DeptName
FROM Employees e
FULL OUTER JOIN Departments d
  ON e.DeptID = d.DeptID;
```

Unmatched columns are `NULL`.

**Interview answer:** A FULL OUTER JOIN returns all matching and non-matching records from both tables.

---

## 12. What is a `SELF JOIN`?

A SELF JOIN joins a table to itself using different aliases.

Example: employees and their managers.

```sql
SELECT
    e.EmpName AS Employee,
    m.EmpName AS Manager
FROM Employees e
LEFT JOIN Employees m
  ON e.ManagerID = m.EmpID;
```

**Interview answer:** A SELF JOIN is useful when records within the same table have relationships with each other, such as employee-manager hierarchies.

---

## 13. What is a `CROSS JOIN`?

A CROSS JOIN produces the Cartesian product of two tables.

If Table A has 3 rows and Table B has 4 rows:

```text
3 × 4 = 12 rows
```

```sql
SELECT p.ProductName, r.RegionName
FROM Products p
CROSS JOIN Regions r;
```

**Interview answer:** A CROSS JOIN returns every possible combination of rows from both tables, so it should be used intentionally because the result can become very large.

---

## 14. What is the difference between `INNER JOIN` and `OUTER JOIN`?

`INNER JOIN` returns matching records only.

```sql
SELECT *
FROM Employees e
INNER JOIN Departments d
  ON e.DeptID = d.DeptID;
```

Outer joins can preserve unmatched records:

```text
LEFT OUTER JOIN
RIGHT OUTER JOIN
FULL OUTER JOIN
```

**Interview answer:** INNER JOIN returns only matches, while OUTER JOIN variants preserve unmatched records from one or both tables.

---

## 15. What is the difference between `INNER JOIN`, `LEFT JOIN`, and `CROSS JOIN`?

| Join | Result |
|---|---|
| INNER JOIN | Matching rows only |
| LEFT JOIN | All left rows + matching right rows |
| CROSS JOIN | Every possible row combination |

```sql
-- INNER JOIN
SELECT *
FROM Employees e
INNER JOIN Departments d
  ON e.DeptID = d.DeptID;
```

```sql
-- LEFT JOIN
SELECT *
FROM Employees e
LEFT JOIN Departments d
  ON e.DeptID = d.DeptID;
```

```sql
-- CROSS JOIN
SELECT *
FROM Employees e
CROSS JOIN Departments d;
```

**Interview answer:** INNER JOIN returns matches, LEFT JOIN preserves every left-table row, and CROSS JOIN creates every possible combination.

---

# Today's Checklist

- [x] SQL Set Operators
- [x] `UNION` vs `UNION ALL`
- [x] `UNION` vs `JOIN`
- [x] Common records from two tables
- [x] Common records without JOIN
- [x] Unique records without DISTINCT
- [x] SQL Joins
- [x] `INNER JOIN`
- [x] `LEFT JOIN`
- [x] `RIGHT JOIN`
- [x] `FULL OUTER JOIN`
- [x] `SELF JOIN`
- [x] `CROSS JOIN`
- [x] `INNER JOIN` vs `OUTER JOIN`
- [x] `INNER JOIN` vs `LEFT JOIN` vs `CROSS JOIN`

## SQL Progress

```text
Previous SQL completed: 75
Today's SQL questions:  +15
----------------------------
SQL completed:          90
SQL remaining:          77
```

> Monster Queries remain excluded from the interview-bank count.
