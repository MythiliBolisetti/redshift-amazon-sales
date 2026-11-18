-- Amazon Sales Analysis on Redshift Serverless
-- Database: dev | Table: amazon_orders

-- 1. Create the table
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

-- 2. Load the CSV from S3 (run only once, or TRUNCATE first)
COPY amazon_orders
FROM 's3://amazon-rs-practice/Amazon.csv'
IAM_ROLE default
FORMAT AS CSV
IGNOREHEADER 1
DATEFORMAT 'YYYY-MM-DD';

-- 3. Check the load (expected: 200000)
SELECT COUNT(*) FROM amazon_orders;
SELECT * FROM amazon_orders LIMIT 5;

-- 4. Revenue by category (delivered orders only)
SELECT category, SUM(total_amount) AS revenue
FROM amazon_orders
WHERE order_status = 'Delivered'
GROUP BY category
ORDER BY revenue DESC;

-- 5. Monthly revenue trend
SELECT DATE_TRUNC('month', order_date)::DATE AS month,
       SUM(total_amount) AS revenue
FROM amazon_orders
GROUP BY 1
ORDER BY 1;

-- 6. Cancellation rate by payment method
SELECT payment_method,
       ROUND(100.0 * SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancel_pct
FROM amazon_orders
GROUP BY 1
ORDER BY 2 DESC;

-- 7. Tuning experiment: copy of the table with a distribution key and sort key
CREATE TABLE amazon_orders_tuned
DISTKEY(customer_id)
SORTKEY(order_date)
AS SELECT * FROM amazon_orders;

-- Compare run times on both tables
SELECT SUM(total_amount) FROM amazon_orders WHERE order_date >= '2023-01-01';
SELECT SUM(total_amount) FROM amazon_orders_tuned WHERE order_date >= '2023-01-01';
