/*
===============================================================================
 GOLD LAYER - DIMENSIONAL MODEL VIEWS
===============================================================================

PURPOSE
-------------------------------------------------------------------------------
This script creates the GOLD layer views for a data warehouse environment.

The GOLD layer represents the business-ready analytical layer of the warehouse.
It transforms cleaned SILVER layer data into a dimensional model structure
consisting of:

1. Fact Table View
   - gold.fact_sales

2. Dimension Table Views
   - gold.dim_products
   - gold.dim_customers

These views are designed for:
- Business Intelligence reporting
- Dashboarding
- Data analytics
- KPI calculations
- Star schema modeling
- Power BI / Tableau / Looker consumption

-------------------------------------------------------------------------------
WHAT THIS SCRIPT DOES
-------------------------------------------------------------------------------

1. CREATES PRODUCT DIMENSION VIEW
   - Builds a product dimension from CRM and ERP product sources
   - Generates surrogate product keys using ROW_NUMBER()
   - Enriches products with category and maintenance information
   - Filters out historical/inactive products
   - Keeps only current active product records

2. CREATES CUSTOMER DIMENSION VIEW
   - Builds a customer dimension from CRM and ERP customer sources
   - Generates surrogate customer keys using ROW_NUMBER()
   - Combines customer demographic and location data
   - Standardizes gender information using fallback logic
   - Includes customer creation dates and birthdates

3. CREATES SALES FACT VIEW
   - Builds a centralized sales fact table
   - Connects sales transactions to product and customer dimensions
   - Stores transactional metrics including:
       * sales amount
       * quantity
       * price
       * order dates
       * shipping dates
       * due dates

-------------------------------------------------------------------------------
SOURCE TABLES USED
-------------------------------------------------------------------------------

SILVER LAYER TABLES:
- silver.crm_sales_details
- silver.crm_prd_info
- silver.crm_cust_info
- silver.erp_px_cat_g1v2
- silver.erp_cust_az12
- silver.erp_loc_a101

-------------------------------------------------------------------------------
TARGET OBJECTS CREATED
-------------------------------------------------------------------------------

- gold.fact_sales
- gold.dim_products
- gold.dim_customers

-------------------------------------------------------------------------------
IMPORTANT NOTES
-------------------------------------------------------------------------------

- CREATE OR REPLACE VIEW is used:
  Running this script will overwrite existing views with the same names.

- No physical tables are created:
  These are logical SQL views referencing SILVER layer data.

- The fact table depends on:
    * gold.dim_products
    * gold.dim_customers

- Historical product records are excluded intentionally:
  Only active/current products are retained where:
      prd_end_dt IS NULL

- Surrogate keys are generated dynamically using ROW_NUMBER().
  These keys are recalculated whenever the views are queried.

-------------------------------------------------------------------------------
WHAT HAPPENS WHEN YOU RUN THIS SCRIPT
-------------------------------------------------------------------------------

1. Existing GOLD views (if any) will be replaced
2. Product dimension view will be created
3. Customer dimension view will be created
4. Sales fact view will be created
5. The GOLD analytical layer becomes available for reporting and analytics

-------------------------------------------------------------------------------
RECOMMENDED USAGE
-------------------------------------------------------------------------------

This script is typically executed:
- After SILVER layer data loads complete
- During warehouse deployment
- During ETL/ELT pipeline execution
- Before connecting BI/reporting tools

===============================================================================
*/


-- gold layer views

create or replace view gold.fact_sales as

SELECT 
       sd.sls_ord_num as order_number,
       pr.product_key,
       cu.customer_key,
       sd.sls_order_dt as order_date,
       sd.sls_ship_dt as shipping_date,
       sd.sls_due_dt as due_date,
       sd.sls_sales as sales_amount,
       sd.sls_quantity as quantity,
       sd.sls_price as price
FROM silver.crm_sales_details sd 
LEFT JOIN gold.dim_products pr 
on sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu 
on sd.sls_cust_id = cu.customer_id;

create or replace view gold.dim_products AS
select
    ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key) as product_key,
    pn.prd_id AS product_id,
    pn.prd_key as product_number,
    pn.prd_nm as product_name,
    pn.cat_id as category_id,
    pc.cat as category,
    pc.subcat as subcategory,
    pc.maintenance as maintenance,
    pn.prd_cost as product_cost,
    pn.prd_line as product_line,
    pn.prd_start_dt as start_date
from silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc 
on pn.cat_id = pc.id
where pn.prd_end_dt is null; --filter out all historical records, only keep the current active products

CREATE VIEW gold.dim_customers AS

SELECT 
    ROW_NUMBER() OVER(ORDER BY ci.cst_id) as customer_key,
    ci.cst_id as customer_id,
    ci.cst_key as customer_number,
    ci.cst_firstname as first_name,
    ci.cst_lastname as last_name,
    la.cntry as country,
    ci.cst_marital_status as marital_status,
    case when ci.cst_gndr != 'n/a' then ci.cst_gndr ---- CRM is Master for gender Info
    ELSE coalesce(ca.gen, 'n/a')
    END as gender,
    ca.bdate as birthdate,
    ci.cst_create_date as create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca 
ON        ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON        ci.cst_key = la.cid;
