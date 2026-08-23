/*1. What are the different types of SQL commands?

SQL commands are generally divided into:

DDL → Data Definition Language
DML → Data Manipulation Language
DQL → Data Query Language
DCL → Data Control Language
TCL → Transaction Control Language*/

-- DDL
CREATE TABLE Employees (...);
ALTER TABLE Employees ADD Email VARCHAR(100);
DROP TABLE Employees;

-- DML
INSERT INTO Employees VALUES (...);
UPDATE Employees SET Salary = 60000;
DELETE FROM Employees WHERE EmpID = 10;

-- DQL
SELECT *
FROM Employees;

-- DCL
GRANT SELECT ON Employees TO analyst;
REVOKE SELECT ON Employees FROM analyst;

-- TCL
COMMIT;
ROLLBACK;

/*Interview point: DDL defines database objects, DML modifies data, DQL retrieves data, DCL manages permissions, and TCL manages transactions.*/


/*2. What is a Primary Key?

A Primary Key uniquely identifies every record in a table.*/

CREATE TABLE Employees (
    EmpID INT PRIMARY KEY,
    EmpName VARCHAR(100),
    Salary DECIMAL(10,2)
);

/*Properties:

Must be unique
Cannot contain NULL
A table normally has one primary key constraint
Can consist of multiple columns as a composite primary key*/

/*3. What is a Foreign Key?

A Foreign Key creates a relationship between two tables by referencing a key in another table.*/

CREATE TABLE Departments (
    DeptID INT PRIMARY KEY,
    DeptName VARCHAR(100)
);

CREATE TABLE Employees (
    EmpID INT PRIMARY KEY,
    EmpName VARCHAR(100),
    DeptID INT,
    FOREIGN KEY (DeptID)
        REFERENCES Departments(DeptID)
);

The foreign key helps maintain referential integrity.


/*4. What is a UNIQUE Key?

A UNIQUE constraint ensures that values in a column or combination of columns are not duplicated.*/

CREATE TABLE Employees (
    EmpID INT PRIMARY KEY,
    Email VARCHAR(150) UNIQUE
);

Unlike a primary key, a table can have multiple UNIQUE constraints.


/*5. What is the difference between a Primary Key and a UNIQUE Key?
| Primary Key                            | UNIQUE Key                                 |
| -------------------------------------- | ------------------------------------------ |
| Uniquely identifies records            | Enforces uniqueness                        |
| Cannot be `NULL`                       | NULL handling depends on DBMS              |
| One primary-key constraint per table   | Multiple UNIQUE constraints possible       |
| Usually represents the main identifier | Often used for alternate unique attributes |
*/


CREATE TABLE Employees (
    EmpID INT PRIMARY KEY,
    Email VARCHAR(150) UNIQUE
);

/*6. What is a NOT NULL constraint?

NOT NULL prevents a column from containing NULL.*/

INSERT INTO Employees (EmpID, EmpName)
VALUES (1, NULL);


/*7. What is a DEFAULT constraint?

A DEFAULT constraint automatically supplies a value when no value is explicitly provided.*/

CREATE TABLE Employees (
    EmpID INT PRIMARY KEY,
    EmpName VARCHAR(100),
    Status VARCHAR(20) DEFAULT 'Active'
);

INSERT INTO Employees (EmpID, EmpName)
VALUES (1, 'John');


/*8. What is Auto Increment in SQL?

Auto Increment automatically generates a new numeric value when a record is inserted.*/

CREATE TABLE Employees (
    EmpID INT AUTO_INCREMENT PRIMARY KEY,
    EmpName VARCHAR(100)
);

then 

INSERT INTO Employees (EmpName)
VALUES ('John');

INSERT INTO Employees (EmpName)
VALUES ('Sarah');


/*9. What is the difference between SQL and MySQL?

SQL is a standardized language used to interact with relational databases.

MySQL is a relational database management system (RDBMS) that implements SQL.

Think of it as:

SQL
 ↓
Language

MySQL
 ↓
Database Management System

Other SQL-based systems include PostgreSQL, SQL Server, Oracle Database, etc.*/


/*10. What is the difference between CHAR and VARCHAR?

Both store character strings, but they behave differently.*/

CHAR

Fixed-length string.

CHAR(10)
VARCHAR

Variable-length string.

VARCHAR(10)

For example:

'John'

With CHAR(10), the database allocates fixed-length storage according to the DBMS.

With VARCHAR(10), the storage is variable according to the stored string, subject to DBMS-specific overhead and limits.

Interview answer:

"CHAR is intended for fixed-length character data, while VARCHAR is intended for variable-length character data."


/*11. How do you calculate a moving average?*/

SELECT
    SaleDate,
    Revenue,
    AVG(Revenue) OVER (
        ORDER BY SaleDate
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS MovingAverage
FROM Sales
ORDER BY SaleDate;


/*12. How do you rank employees within each department?*/

SELECT
    EmpID,
    EmpName,
    DeptID,
    Salary,
    RANK() OVER (
        PARTITION BY DeptID
        ORDER BY Salary DESC
    ) AS SalaryRank
FROM Employees;


/*13. How do you find the third-highest salary?

Using DENSE_RANK():*/

SELECT
    EmpID,
    EmpName,
    Salary
FROM (
    SELECT
        EmpID,
        EmpName,
        Salary,
        DENSE_RANK() OVER (
            ORDER BY Salary DESC
        ) AS SalaryRank
    FROM Employees
) t
WHERE SalaryRank = 3;


/*14. How do you find odd-numbered records?

One approach is to assign row numbers and filter odd rows:*/

WITH NumberedEmployees AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY EmpID
        ) AS RowNum
    FROM Employees
)
SELECT *
FROM NumberedEmployees
WHERE RowNum % 2 = 1;


/*15. How do you calculate age from Date of Birth?*/

SELECT
    EmpID,
    EmpName,
    DATE_PART(
        'year',
        AGE(CURRENT_DATE, DateOfBirth)
    ) AS Age
FROM Employees;
