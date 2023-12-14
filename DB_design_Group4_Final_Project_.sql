CREATE DATABASE IF NOT EXISTS tpch;
USE tpch;

CREATE TABLE orders (
    O_ORDERKEY       INTEGER NOT NULL,
    O_CUSTKEY        INTEGER NOT NULL,
    O_ORDERSTATUS    CHAR(1) NOT NULL,
    O_TOTALPRICE     DECIMAL(15,2) NOT NULL,
    O_ORDERDATE      DATE NOT NULL,
    O_ORDERPRIORITY  CHAR(15) NOT NULL,  
    O_CLERK          CHAR(15) NOT NULL, 
    O_SHIPPRIORITY   INTEGER NOT NULL,
    O_COMMENT        VARCHAR(79) NOT NULL
);

CREATE TABLE lineitem (
    L_ORDERKEY    INTEGER NOT NULL,
    L_PARTKEY     INTEGER NOT NULL,
    L_SUPPKEY     INTEGER NOT NULL,
    L_LINENUMBER  INTEGER NOT NULL,
    L_QUANTITY    DECIMAL(15,2) NOT NULL,
    L_EXTENDEDPRICE  DECIMAL(15,2) NOT NULL,
    L_DISCOUNT    DECIMAL(15,2) NOT NULL,
    L_TAX         DECIMAL(15,2) NOT NULL,
    L_RETURNFLAG  CHAR(1) NOT NULL,
    L_LINESTATUS  CHAR(1) NOT NULL,
    L_SHIPDATE    DATE NOT NULL,
    L_COMMITDATE  DATE NOT NULL,
    L_RECEIPTDATE DATE NOT NULL,
    L_SHIPINSTRUCT CHAR(25) NOT NULL,
    L_SHIPMODE     CHAR(10) NOT NULL,
    L_COMMENT      VARCHAR(44) NOT NULL
);

-- Add primary keys
ALTER TABLE orders ADD PRIMARY KEY (O_ORDERKEY);
ALTER TABLE lineitem ADD PRIMARY KEY (L_ORDERKEY, L_LINENUMBER);

-- Add foreign keys
ALTER TABLE lineitem ADD FOREIGN KEY (L_ORDERKEY) REFERENCES orders (O_ORDERKEY);
SELECT * FROM orders;
SELECT * FROM lineitem;
CREATE INDEX idx_orders_orderkey ON orders (O_ORDERKEY);
CREATE INDEX idx_lineitem_orderkey ON lineitem (L_ORDERKEY);
SELECT *
FROM orders
JOIN lineitem ON orders.O_ORDERKEY = lineitem.L_ORDERKEY;

-- Optimize the SELECT clause to fetch only necessary columns
SELECT orders.O_ORDERKEY, lineitem.L_ORDERKEY, orders.O_TOTALPRICE, lineitem.L_QUANTITY, lineitem.L_SHIPDATE
FROM orders
JOIN lineitem ON orders.O_ORDERKEY = lineitem.L_ORDERKEY
WHERE lineitem.L_SHIPDATE >= '1995-04-25' AND lineitem.L_SHIPDATE < '1996-02-01'
AND orders.O_TOTALPRICE > 50000;

-- Testing with TPC-H benchmark queries
-- Query1: The lineitem table is left joined with the orders table on their order key.
SELECT l_count, COUNT(*) AS lineitemcount
FROM (
    SELECT
        l.L_ORDERKEY,
        COUNT(o.O_ORDERKEY)
    FROM
        lineitem AS l
        LEFT OUTER JOIN orders AS o ON l.L_ORDERKEY = o.O_ORDERKEY
        AND o.O_COMMENT NOT LIKE '%[WORD1]%[WORD2]%'
    GROUP BY
        l.L_ORDERKEY
) AS l_orders (L_ORDERKEY, l_count)
GROUP BY
    l_count
ORDER BY
    lineitemcount DESC,
    l_count DESC;
    
-- Refined Query1:
-- Creating indexes on join keys for efficient join operation
-- CREATE INDEX idx_lineitem_orderkey ON lineitem (L_ORDERKEY); (Index already created)
-- CREATE INDEX idx_orders_orderkey ON orders (O_ORDERKEY); (Index already created)
CREATE INDEX idx_orders_comment ON orders (O_COMMENT);

-- Optimized Query
SELECT l_count, COUNT(*) AS lineitemcount
FROM (
    SELECT
        l.L_ORDERKEY,
        COUNT(o.O_ORDERKEY)  -- Counting orders for each line item
    FROM
        lineitem AS l
        LEFT OUTER JOIN orders AS o ON l.L_ORDERKEY = o.O_ORDERKEY
        AND o.O_COMMENT NOT LIKE '%ns integrate fluffily. ironic asymptotes after the regular excuses nag around %usly final asymptotes %'  -- Filtering based on comment
    GROUP BY
        l.L_ORDERKEY  -- Grouping by line item order key
) AS l_orders (L_ORDERKEY, l_count)
GROUP BY
    l_count  -- Grouping results by the count of orders
ORDER BY
    lineitemcount DESC, l_count DESC;  -- Ordering the final result set

-- Query2: 
SELECT
    l_shipmode,
    SUM(CASE WHEN o_orderpriority IN ('1-URGENT', '2-HIGH') THEN 1 ELSE 0 END) AS high_line_count,
    SUM(CASE WHEN o_orderpriority NOT IN ('1-URGENT', '2-HIGH') THEN 1 ELSE 0 END) AS low_line_count
FROM
    orders
JOIN
    lineitem ON o_orderkey = l_orderkey
WHERE
    l_shipmode IN ('TRUCK', 'RAIL')
    AND l_commitdate < l_receiptdate
    AND l_shipdate < l_commitdate
    AND l_receiptdate >= '1996-02-03'
    AND l_receiptdate < DATE_ADD('1996-02-03', INTERVAL 1 YEAR)
GROUP BY
    l_shipmode
ORDER BY
    l_shipmode;

-- Refined Query2:

-- Creating indexes on join keys for efficient join operation
CREATE INDEX idx_orders_orderkey ON orders (O_ORDERKEY);
CREATE INDEX idx_lineitem_orderkey ON lineitem (L_ORDERKEY);

-- Creating indexes on columns used in WHERE clause for faster filtering
CREATE INDEX idx_lineitem_shipmode ON lineitem (L_SHIPMODE);
CREATE INDEX idx_lineitem_receiptdate ON lineitem (L_RECEIPTDATE);

-- Analyzing the execution plan of the query
EXPLAIN 
SELECT
    l.L_SHIPMODE,
    -- Using SUM with CASE to count based on order priority conditions
    SUM(CASE WHEN o.O_ORDERPRIORITY IN ('1-URGENT', '2-HIGH') THEN 1 ELSE 0 END) AS high_line_count,
    SUM(CASE WHEN o.O_ORDERPRIORITY NOT IN ('1-URGENT', '2-HIGH') THEN 1 ELSE 0 END) AS low_line_count
FROM
    orders AS o
JOIN
    lineitem AS l ON o.O_ORDERKEY = l.L_ORDERKEY
WHERE
    -- Filtering conditions to narrow down the result set
    l.L_SHIPMODE IN ('TRUCK', 'RAIL')
    AND l.L_COMMITDATE < l.L_RECEIPTDATE
    AND l.L_SHIPDATE < l.L_COMMITDATE
    AND l.L_RECEIPTDATE >= '1996-02-03'
    AND l.L_RECEIPTDATE < DATE_ADD('1996-02-03', INTERVAL 1 YEAR)
GROUP BY
    -- Grouping results by ship mode
    l.L_SHIPMODE
ORDER BY
    -- Ordering the final result set by ship mode
    l.L_SHIPMODE;

-- Query3: 
CREATE VIEW orders_analysis AS
SELECT
    o.O_ORDERKEY,
    COUNT(l.L_ORDERKEY) AS lineitemcount
FROM
    orders AS o
    LEFT OUTER JOIN lineitem AS l ON o.O_ORDERKEY = l.L_ORDERKEY
    AND l.L_COMMENT NOT LIKE '%sleep quickly. req%lithely regular deposits. fluffily %'
GROUP BY
    o.O_ORDERKEY;

SELECT
    lineitemcount,
    COUNT(*) AS ordercount
FROM
    orders_analysis
GROUP BY
    lineitemcount
ORDER BY
    ordercount DESC,
    lineitemcount DESC;

DROP VIEW orders_analysis;

-- Refined Query3:
-- Ensure indexing is done for efficient join operations
-- CREATE INDEX IF NOT EXISTS idx_orders_orderkey ON orders (O_ORDERKEY);(Index created already)
-- CREATE INDEX IF NOT EXISTS idx_lineitem_orderkey ON lineitem (L_ORDERKEY);(Index created already)

-- Creating a view to analyze order characteristics
CREATE OR REPLACE VIEW orders_analysis AS
SELECT
    o.O_ORDERKEY,
    COUNT(l.L_ORDERKEY) AS lineitemcount  -- Counting line items per order
FROM
    orders AS o
    LEFT OUTER JOIN lineitem AS l ON o.O_ORDERKEY = l.L_ORDERKEY
    AND l.L_COMMENT NOT LIKE '%sleep quickly. req%lithely regular deposits. fluffily %'  -- Filtering based on line item comment
GROUP BY
    o.O_ORDERKEY;

-- Query to get distribution of orders based on line item count
SELECT
    lineitemcount,
    COUNT(*) AS ordercount  -- Counting orders for each line item count
FROM
    orders_analysis
GROUP BY
    lineitemcount
ORDER BY
    ordercount DESC,
    lineitemcount DESC;

-- Dropping the view after analysis
DROP VIEW IF EXISTS orders_analysis;

-- Query4:
SELECT
    100.00 * SUM(CASE 
                    WHEN o.O_ORDERSTATUS = 'O' THEN l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT) 
                    ELSE 0 
                 END) /
    SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue_O,
    100.00 * SUM(CASE 
                    WHEN o.O_ORDERSTATUS = 'F' THEN l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT) 
                    ELSE 0 
                 END) /
    SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue_F
FROM
    lineitem AS l
JOIN
    orders AS o ON l.L_ORDERKEY = o.O_ORDERKEY
WHERE
    l.L_SHIPDATE >= '1995-04-25'  -- Replace with your start date
    AND l.L_SHIPDATE < DATE_ADD('1995-04-25', INTERVAL 1 MONTH)  -- Replace with your start date

-- Refined Query4:
-- Simplified Query for Optimized Performance
SELECT
    100.00 * SUM(CASE 
                    WHEN o.O_ORDERSTATUS = 'O' THEN l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT) 
                    ELSE 0 
                 END) /
    SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue_percentage_O
FROM
    lineitem AS l
JOIN
    orders AS o ON l.L_ORDERKEY = o.O_ORDERKEY
WHERE
    l.L_SHIPDATE >= '1995-04-25'  -- Replace with your actual start date
    AND l.L_SHIPDATE < DATE_ADD('1995-04-25', INTERVAL 1 MONTH)  -- Replace with your actual start date
