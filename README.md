# redshift-amazon-sales
AWS data pipeline: S3 → Redshift Serverless → SQL analysis on 200K sales orders
# Amazon Sales Analysis on AWS Redshift Serverless

A small cloud data project: load a 200,000-row sales CSV from S3 into Amazon Redshift Serverless, then analyze it with SQL.

## What I built
- Uploaded the dataset (`Amazon.csv`) to an **S3 bucket**
- Created an **IAM role** so Redshift can read from S3 and set it as the default role
- Set up **Redshift Serverless** (base capacity 8 RPUs to keep cost low)
- Created the table and bulk-loaded the data with the **COPY** command
- Ran analysis queries in **Query Editor v2**
- Deleted the workgroup and namespace afterwards to avoid charges

## Dataset
- 200,000 orders, Jan 2020 to Dec 2024 (60 months)
- 20 columns: order ID, date, customer, product, category, brand, quantity, price, discount, tax, shipping, total amount, payment method, order status, city, state, country, seller
- The data looks synthetic (for example, cities and countries don't match, and product names don't match categories), so the results below are for practicing the pipeline, not real business insights.

## Steps and SQL

### 1. Create the table
```sql
CREATE TABLE amazon_orders (
  order_id        VARCHAR(20),
  order_date      DATE,
  customer_id     VARCHAR(20),
  customer_name   VARCHAR(100),
  product_id      VARCHAR(20),
  product_name    VARCHAR(150),
  category        VARCHAR(50),
  brand           VARCHAR(50),
  quantity        INT,
  unit_price      DECIMAL(12,2),
  discount        DECIMAL(4,2),
  tax             DECIMAL(12,2),
  shipping_cost   DECIMAL(10,2),
  total_amount    DECIMAL(12,2),
  payment_method  VARCHAR(30),
  order_status    VARCHAR(20),
  city            VARCHAR(50),
  state           VARCHAR(10),
  country         VARCHAR(50),
  seller_id       VARCHAR(20)
);
```

### 2. Load from S3
```sql
COPY amazon_orders
FROM 's3://amazon-rs-practice/Amazon.csv'
IAM_ROLE default
FORMAT AS CSV
IGNOREHEADER 1
DATEFORMAT 'YYYY-MM-DD';
```

### 3. Check the load
```sql
SELECT COUNT(*) FROM amazon_orders;   -- 200000
```

### 4. Analysis queries
```sql
-- Revenue by category (delivered orders only)
SELECT category, SUM(total_amount) AS revenue
FROM amazon_orders
WHERE order_status = 'Delivered'
GROUP BY category
ORDER BY revenue DESC;

-- Monthly revenue trend
SELECT DATE_TRUNC('month', order_date)::DATE AS month,
       SUM(total_amount) AS revenue
FROM amazon_orders
GROUP BY 1
ORDER BY 1;

-- Cancellation rate by payment method
SELECT payment_method,
       ROUND(100.0 * SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancel_pct
FROM amazon_orders
GROUP BY 1
ORDER BY 2 DESC;
```

### 5. Tuning experiment
Made a second copy of the table with a distribution key and sort key to compare against the default table:
```sql
CREATE TABLE amazon_orders_tuned
DISTKEY(customer_id)
SORTKEY(order_date)
AS SELECT * FROM amazon_orders;
```
- **SORTKEY(order_date):** rows are stored in date order, so queries that filter by date can skip data they don't need.
- **DISTKEY(customer_id):** rows for the same customer go to the same node, which helps joins on that column.

## Findings
| Query | Result |
|---|---|
| Rows loaded | 200,000 |
| Revenue by category | Electronics highest (about 23.3M); the other five categories are between about 22.5M and 23.0M, so very evenly spread |
| Monthly trend | 60 months, fairly stable at roughly 3M per month |
| Cancellation rate | About 3% for every payment method, from 2.93% (Net Banking) to 3.17% (Cash on Delivery) |

## What I learned
- How S3, IAM roles and Redshift work together (the role must be attached to the namespace before COPY works)
- Bulk loading with `COPY` instead of row-by-row inserts
- Using `DATE_TRUNC` to roll daily data up into monthly trends
- What RPUs are and how Redshift Serverless billing works
- The basics of DISTKEY and SORTKEY
- Cleaning up cloud resources after a project to avoid charges

## Screenshots
See the `screenshots/` folder: table columns, COPY success, row count, and the three query results.

## Tools
AWS S3, AWS IAM, Amazon Redshift Serverless, Query Editor v2, SQL
