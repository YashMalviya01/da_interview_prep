## SQL — 20 Questions

### Q151. What is Index Fragmentation?
Index fragmentation occurs when index pages become inefficiently ordered or sparsely populated. It can increase I/O. In SQL Server, inspect fragmentation and use appropriate REORGANIZE or REBUILD maintenance.

### Q152. What is Table Partitioning?
Partitioning divides a large table into smaller logical partitions, commonly by date or range. It can improve manageability and allow partition elimination for suitable queries.

### Q153. What is Case Sensitivity in SQL?
Case sensitivity determines whether text comparisons distinguish uppercase and lowercase characters. It depends on the database and collation/settings.

### Q154. What is OLTP?
OLTP (Online Transaction Processing) supports frequent, short operational transactions such as INSERT, UPDATE, and DELETE. It prioritizes consistency and fast transaction processing.

### Q155. What is OLAP?
OLAP (Online Analytical Processing) supports complex analytical queries, aggregations, reporting, and historical analysis over large datasets.

### Q156. What is the difference between OLTP and OLAP?
OLTP is optimized for operational transactions; OLAP is optimized for analysis and reporting. OLTP commonly uses normalized operational schemas, while analytical systems often use dimensional models.

### Q157. What is the difference between IN and EXISTS?
`IN` compares a value against a set returned by a subquery. `EXISTS` checks whether a subquery returns at least one row.

```sql
SELECT *
FROM Customers
WHERE CustomerID IN (
    SELECT CustomerID FROM Orders
);

SELECT *
FROM Customers c
WHERE EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.CustomerID = c.CustomerID
);
```

### Q158. What is the use of EXISTS?
`EXISTS` tests whether at least one related row exists.

```sql
SELECT *
FROM Customers c
WHERE EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.CustomerID = c.CustomerID
);
```

### Q159. How do you avoid Deadlocks in SQL?
Keep transactions short, access resources in a consistent order, avoid unnecessary locks, use appropriate indexes, and choose suitable isolation settings. Deadlocks occur when transactions wait on resources held by each other.

### Q160. What is a Query Execution Plan?
An execution plan describes how the database engine intends to execute a query, including scans, seeks, joins, sorts, and aggregations. It is used to identify performance bottlenecks.

### Q161. How do you analyze a Query Execution Plan?
Look for expensive scans, inefficient joins, large sorts, poor cardinality estimates, excessive lookups, and missing or unsuitable indexes. Compare execution metrics before and after changes.

### Q162. What is Query Optimization?
Query optimization is finding a more efficient execution strategy while preserving the query's result. It can involve query rewrites, indexes, statistics, and join strategies.

### Q163. How do you optimize a SQL query?
Inspect the execution plan, reduce unnecessary rows and columns, optimize joins, add appropriate indexes, avoid unnecessary calculations, and validate that the optimized query returns the same results.

```sql
SELECT CustomerID, SUM(Amount) AS TotalAmount
FROM Orders
WHERE OrderDate >= '2026-01-01'
GROUP BY CustomerID;
```

### Q164. How do you improve SQL query performance?
Use appropriate indexes, selective filtering, efficient joins, maintained statistics, fewer unnecessary columns, and execution-plan analysis. Optimize the actual bottleneck rather than blindly adding indexes.

### Q165. What indexing strategies improve query performance?
Index columns frequently used in `WHERE`, `JOIN`, and `ORDER BY`. Consider composite indexes for common multi-column predicates, while avoiding excessive indexes because they add storage and write overhead.

```sql
CREATE INDEX idx_orders_customer_date
ON Orders(CustomerID, OrderDate);
```

### Q166. When should you use partitioning?
Use partitioning for very large tables when data naturally divides by a key such as date and queries frequently filter on that key. It can improve manageability and partition elimination, but it is not automatically a performance fix.

### Q167. What is the difference between a Clustered and Non-Clustered Index?
A clustered index determines the logical order of the table's data around its key. A non-clustered index is a separate structure pointing to the underlying rows. A table can have one clustered index but multiple non-clustered indexes.

### Q168. What are Magic Tables in SQL Server?
Magic tables are logical tables available inside SQL Server DML triggers. The important ones are `INSERTED` and `DELETED`, which expose new and old row versions.

```sql
CREATE TRIGGER trg_AuditEmployee
ON Employees
AFTER UPDATE
AS
BEGIN
    SELECT * FROM inserted;
    SELECT * FROM deleted;
END;
```

### Q169. What are INSERTED and DELETED Magic Tables?
`INSERTED` contains new row versions for INSERT/UPDATE operations, while `DELETED` contains old row versions for DELETE/UPDATE operations. They are available within trigger execution.

### Q170. What is JSON in SQL?
JSON is a text-based format for semi-structured data. Modern databases provide functions to store, extract, query, and sometimes index JSON. Syntax varies by database.

```sql
SELECT JSON_EXTRACT(Profile, '$.city') AS City
FROM Customers;
```


### Q171. What is XML in SQL?
XML is a markup-based format for structured or semi-structured data. Some relational databases provide native XML types and functions for storing and querying XML.

```sql
SELECT XML_DATA
FROM CustomerProfiles
WHERE CustomerID = 101;
```

### Q172. What is a Dual-Axis Chart in Tableau?
A dual-axis chart displays two measures in one view using separate axes. It is useful for comparing related metrics with different scales, such as Sales and Profit. It should be used carefully because different scales can mislead viewers.

### Q173. How do you create Calculated Fields in Tableau?
Create a formula using existing fields, constants, and functions. For example:

```text
SUM([Sales]) - SUM([Cost])
```

This can create a Profit metric that does not directly exist in the source data.

### Q174. What are the different types of Joins available in Tableau?
Common Tableau joins include Inner, Left, Right, and Full Outer joins. The appropriate join depends on which unmatched records need to be retained.

### Q175. How does Tableau handle NULL values?
First investigate why NULLs exist. Depending on the business meaning, NULLs can be filtered, replaced, grouped as `Unknown`, or handled with a calculated field. The treatment should preserve the meaning of the data.

---

