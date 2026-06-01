--  Product Report

/*
===========================================================================
 Product Report
===========================================================================

Purpose:
    - This report consolidates key product metrics and behaviors

Highlights:
    1. Gathers essential fields such as product name, category, subcategory and cost.
    2. segments products by revenue to identify High Performers, Mid Range or Low Performers.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity sold
        - total customers unique
        - lifespan (in months)
    4. calculates Valuable KPIs:
        - recency (months since last sale)
        - average order value
        - average monthly revenue
=========================================================================
*/
CREATE OR REPLACE VIEW gold.report_products AS
WITH base_query AS(
SELECT 
    p.product_name,
    p.category,
    p.subcategory,
    p.product_cost,
    f.order_number,
    p.product_key,
    f.order_date,
    f.sales_amount,
    f.quantity,
    f.customer_key,
    (extract(year from age(CURRENT_TIMESTAMP, f.order_date)) 
    + 
    extract(month from age(current_timestamp, f.order_date))) as product_age
FROM gold.fact_sales f 
LEFT JOIN gold.dim_products p 
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
),

product_aggregation AS(
SELECT 
    product_key,
    product_name, 
    category,
    subcategory,
    product_cost,
    count(DISTINCT order_number) as total_orders,
    sum(sales_amount) as total_sales,
    sum(quantity) as total_quantity,
    count(distinct customer_key) as total_customers,
    max(order_date) as last_sale_date,
    round(avg(sales_amount::numeric)/NULLIF(sum(quantity), 0), 1) AS avg_selling_price,
    (EXTRACT (YEAR FROM age(max(order_date), min(order_date))) * 12 
    + 
    EXTRACT (MONTH FROM age(max(order_date), min(order_date)))) as lifespan
FROM base_query
GROUP BY 
    product_key,
    product_name,
    category,
    subcategory,
    product_cost
)

SELECT
    product_key,
    product_name,
    category,
    subcategory,
    product_cost,
    last_sale_date,
    -- recency (months since last sale)
    (EXTRACT(YEAR FROM age(CURRENT_TIMESTAMP, last_sale_date))
    + 
    EXTRACT(MONTH FROM age(CURRENT_TIMESTAMP, last_sale_date))) AS recency_in_months,
    -- segments products by revenue to identify High Performers, Mid Range or Low Performers.
    CASE WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END product_segment,
    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
            -- average order value
    case when total_sales = 0 then 0
         else total_sales/total_orders
    end as avg_order_value,
    -- average monthly revenue
    case when lifespan = 0 then total_sales
         else total_sales / lifespan
    end as avg_monthly_revenue
FROM product_aggregation;
