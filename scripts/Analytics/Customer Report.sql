-- Customer Report

/*
===========================================================================
 Customer Report
===========================================================================

Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        - lifespan (in months)
    4. calculates Valuable KPIs:
        - recency (months since last order)
        - average order value
        - average monthly spend
=========================================================================
*/

-- Base query: Retrieve core columns from tables

CREATE OR REPLACE VIEW gold.report_customers AS 

WITH base_query AS (
SELECT 
    f.order_number,
    f.product_key,
    f.order_date,
    f.sales_amount,
    f.quantity,
    c.customer_key,
    c.customer_number,
    CONCAT(c.first_name, ' ',c.last_name) AS customer_name,
    extract(year from age(CURRENT_TIMESTAMP, c.birthdate)) age
FROM gold.fact_sales f 
LEFT JOIN gold.dim_customers c 
ON f.customer_key = c.customer_key
WHERE order_date IS NOT NULL
),

customer_aggregation AS(
SELECT 
    customer_key,
    customer_number,
    customer_name, 
    age,
    count(DISTINCT order_number) as total_orders,
    sum(sales_amount) as total_sales,
    sum(quantity) as total_quantity,
    count(distinct product_key) as total_products,
    max(order_date) as last_order_date,
    (EXTRACT (YEAR FROM age(max(order_date), min(order_date))) * 12 
    + 
    EXTRACT (MONTH FROM age(max(order_date), min(order_date)))) as lifespan
FROM base_query
GROUP BY 
    customer_key,
    customer_number,
    customer_name,
    age
)

SELECT
    customer_key,
    customer_number,
    customer_name, 
    age,
    CASE WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 and 29 THEN '20-29'
        WHEN age BETWEEN 30 and 39 THEN '30-39'
        WHEN age BETWEEN 40 and 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END customer_segment,
    last_order_date,
    (EXTRACT( YEAR FROM age(CURRENT_TIMESTAMP, last_order_date))
    + EXTRACT(MONTH FROM age(CURRENT_TIMESTAMP, last_order_date))) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products, 
    lifespan,
    -- average order value
    CASE WHEN total_orders = 0 then 0
         ELSE total_sales/total_orders
    END AS avg_order_value,
    -- average monthly spend
    CASE WHEN lifespan = 0 THEN total_sales
         ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;
