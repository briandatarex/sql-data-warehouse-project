/*
===============================================================================
PROCEDURE: silver.load_silver
===============================================================================

DESCRIPTION:
------------
This procedure loads and transforms data from the BRONZE layer into the
SILVER layer of the data warehouse.

The procedure performs the following operations:

1. Loads and cleans customer information
   - Removes duplicates
   - Standardizes gender values
   - Standardizes marital status values
   - Trims unnecessary spaces

2. Loads and transforms product information
   - Standardizes product line categories
   - Derives category identifiers
   - Calculates product end dates

3. Loads and cleans sales details
   - Validates order, ship, and due dates
   - Recalculates invalid sales amounts
   - Recalculates missing or invalid prices

4. Loads ERP supporting datasets
   - Customer demographics
   - Customer locations
   - Product category mappings

LOGGING & MONITORING:
---------------------
The procedure includes detailed logging for:
- Pipeline start and end times
- Individual table load start and end times
- Rows loaded per table
- Load durations
- Error messages and exception context

ERROR HANDLING:
---------------
Each table load is wrapped in its own exception block. This means:
- If one table fails, the remaining tables can still continue loading
- Errors are captured and displayed using RAISE NOTICE
- PostgreSQL exception context is included for troubleshooting

IMPORTANT:
----------
This procedure uses TRUNCATE TABLE before each load.
Running this procedure will fully replace the existing SILVER layer data.

EXECUTION:
----------
CALL silver.load_silver();

===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$

DECLARE

    -- =====================================================
    -- PIPELINE VARIABLES
    -- =====================================================

    v_pipeline_start      TIMESTAMP;
    v_pipeline_end        TIMESTAMP;

    v_table_start         TIMESTAMP;
    v_table_end           TIMESTAMP;

    v_rows_loaded         INT;

    v_error_message       TEXT;
    v_error_context       TEXT;

BEGIN

    -- =====================================================
    -- PIPELINE START
    -- =====================================================

    v_pipeline_start := clock_timestamp();

    RAISE NOTICE '';
    RAISE NOTICE '==========================================================';
    RAISE NOTICE 'STARTING SILVER LAYER LOAD';
    RAISE NOTICE 'Pipeline Start Time : %', v_pipeline_start;
    RAISE NOTICE '==========================================================';

    -- =====================================================
    -- LOAD CUSTOMER INFORMATION
    -- =====================================================

    BEGIN

        v_table_start := clock_timestamp();

        RAISE NOTICE '';
        RAISE NOTICE 'Loading Table      : silver.crm_cust_info';
        RAISE NOTICE 'Table Start Time   : %', v_table_start;

        TRUNCATE TABLE silver.crm_cust_info;

        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )

        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,

            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S'
                    THEN 'Single'

                WHEN UPPER(TRIM(cst_marital_status)) = 'M'
                    THEN 'Married'

                ELSE 'n/a'
            END AS cst_marital_status,

            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'M'
                    THEN 'Male'

                WHEN UPPER(TRIM(cst_gndr)) = 'F'
                    THEN 'Female'

                ELSE 'n/a'
            END AS cst_gndr,

            CAST(cst_create_date AS DATE) AS cst_create_date

        FROM (

            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS flag_last

            FROM bronze.crm_cust_info

        ) t

        WHERE flag_last = 1;

        GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

        v_table_end := clock_timestamp();

        RAISE NOTICE 'Rows Loaded        : %', v_rows_loaded;
        RAISE NOTICE 'Table End Time     : %', v_table_end;
        RAISE NOTICE 'Load Duration      : % seconds',
            ROUND(EXTRACT(EPOCH FROM (
                v_table_end - v_table_start
            )), 2);

        RAISE NOTICE 'STATUS             : SUCCESS';
        RAISE NOTICE '----------------------------------------------------------';

    EXCEPTION
        WHEN OTHERS THEN

            GET STACKED DIAGNOSTICS
                v_error_message = MESSAGE_TEXT,
                v_error_context = PG_EXCEPTION_CONTEXT;

            RAISE NOTICE '';
            RAISE NOTICE 'STATUS             : FAILED';
            RAISE NOTICE 'Failed Table       : silver.crm_cust_info';
            RAISE NOTICE 'Error Message      : %', v_error_message;
            RAISE NOTICE 'Error Context      : %', v_error_context;
            RAISE NOTICE '----------------------------------------------------------';

    END;

    -- =====================================================
    -- LOAD PRODUCT INFORMATION
    -- =====================================================

    BEGIN

        v_table_start := clock_timestamp();

        RAISE NOTICE '';
        RAISE NOTICE 'Loading Table      : silver.crm_prd_info';
        RAISE NOTICE 'Table Start Time   : %', v_table_start;

        TRUNCATE TABLE silver.crm_prd_info;

        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )

        SELECT
            prd_id,

            REPLACE(
                SUBSTRING(prd_key, 1, 5),
                '-',
                '_'
            ) AS cat_id,

            SUBSTRING(
                prd_key,
                7,
                LENGTH(prd_key)
            ) AS prd_key,

            prd_nm,

            COALESCE(prd_cost, 0) AS prd_cost,

            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,

            CAST(prd_start_dt AS DATE) AS prd_start_dt,

            LEAD(CAST(prd_start_dt AS DATE))
            OVER (
                PARTITION BY prd_key
                ORDER BY CAST(prd_start_dt AS DATE)
            ) - 1 AS prd_end_dt

        FROM bronze.crm_prd_info;

        GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

        v_table_end := clock_timestamp();

        RAISE NOTICE 'Rows Loaded        : %', v_rows_loaded;
        RAISE NOTICE 'Table End Time     : %', v_table_end;
        RAISE NOTICE 'Load Duration      : % seconds',
            ROUND(EXTRACT(EPOCH FROM (
                v_table_end - v_table_start
            )), 2);

        RAISE NOTICE 'STATUS             : SUCCESS';
        RAISE NOTICE '----------------------------------------------------------';

    EXCEPTION
        WHEN OTHERS THEN

            GET STACKED DIAGNOSTICS
                v_error_message = MESSAGE_TEXT,
                v_error_context = PG_EXCEPTION_CONTEXT;

            RAISE NOTICE '';
            RAISE NOTICE 'STATUS             : FAILED';
            RAISE NOTICE 'Failed Table       : silver.crm_prd_info';
            RAISE NOTICE 'Error Message      : %', v_error_message;
            RAISE NOTICE 'Error Context      : %', v_error_context;
            RAISE NOTICE '----------------------------------------------------------';

    END;

    -- =====================================================
    -- LOAD SALES DETAILS
    -- =====================================================

    BEGIN

        v_table_start := clock_timestamp();

        RAISE NOTICE '';
        RAISE NOTICE 'Loading Table      : silver.crm_sales_details';
        RAISE NOTICE 'Table Start Time   : %', v_table_start;

        TRUNCATE TABLE silver.crm_sales_details;

        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )

        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,

            CASE
                WHEN sls_order_dt = 0
                     OR LENGTH(sls_order_dt::TEXT) != 8
                    THEN NULL

                ELSE TO_DATE(
                    sls_order_dt::TEXT,
                    'YYYYMMDD'
                )
            END AS sls_order_dt,

            CASE
                WHEN sls_ship_dt = 0
                     OR LENGTH(sls_ship_dt::TEXT) != 8
                    THEN NULL

                ELSE TO_DATE(
                    sls_ship_dt::TEXT,
                    'YYYYMMDD'
                )
            END AS sls_ship_dt,

            CASE
                WHEN sls_due_dt = 0
                     OR LENGTH(sls_due_dt::TEXT) != 8
                    THEN NULL

                ELSE TO_DATE(
                    sls_due_dt::TEXT,
                    'YYYYMMDD'
                )
            END AS sls_due_dt,

            CASE
                WHEN sls_sales IS NULL
                     OR sls_sales <= 0
                     OR sls_sales != sls_quantity * ABS(sls_price)
                    THEN sls_quantity * ABS(sls_price)

                ELSE sls_sales
            END AS sls_sales,

            sls_quantity,

            CASE
                WHEN sls_price IS NULL
                     OR sls_price <= 0
                    THEN sls_sales / NULLIF(sls_quantity, 0)

                ELSE sls_price
            END AS sls_price

        FROM bronze.crm_sales_details;

        GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

        v_table_end := clock_timestamp();

        RAISE NOTICE 'Rows Loaded        : %', v_rows_loaded;
        RAISE NOTICE 'Table End Time     : %', v_table_end;
        RAISE NOTICE 'Load Duration      : % seconds',
            ROUND(EXTRACT(EPOCH FROM (
                v_table_end - v_table_start
            )), 2);

        RAISE NOTICE 'STATUS             : SUCCESS';
        RAISE NOTICE '----------------------------------------------------------';

    EXCEPTION
        WHEN OTHERS THEN

            GET STACKED DIAGNOSTICS
                v_error_message = MESSAGE_TEXT,
                v_error_context = PG_EXCEPTION_CONTEXT;

            RAISE NOTICE '';
            RAISE NOTICE 'STATUS             : FAILED';
            RAISE NOTICE 'Failed Table       : silver.crm_sales_details';
            RAISE NOTICE 'Error Message      : %', v_error_message;
            RAISE NOTICE 'Error Context      : %', v_error_context;
            RAISE NOTICE '----------------------------------------------------------';

    END;

    -- =====================================================
    -- LOAD ERP CUSTOMER DATA
    -- =====================================================

    BEGIN

        v_table_start := clock_timestamp();

        RAISE NOTICE '';
        RAISE NOTICE 'Loading Table      : silver.erp_cust_az12';
        RAISE NOTICE 'Table Start Time   : %', v_table_start;

        TRUNCATE TABLE silver.erp_cust_az12;

        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )

        SELECT
            CASE
                WHEN "CID" LIKE 'NAS%'
                    THEN SUBSTRING("CID", 4, LENGTH("CID"))

                ELSE "CID"
            END AS cid,

            CASE
                WHEN CAST("BDATE" AS DATE) > CURRENT_TIMESTAMP
                    THEN NULL

                ELSE CAST("BDATE" AS DATE)
            END AS bdate,

            CASE
                WHEN UPPER(TRIM("GEN")) IN ('F', 'FEMALE')
                    THEN 'Female'

                WHEN UPPER(TRIM("GEN")) IN ('M', 'MALE')
                    THEN 'Male'

                ELSE 'n/a'
            END AS gen

        FROM bronze.erp_cust_az12;

        GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

        v_table_end := clock_timestamp();

        RAISE NOTICE 'Rows Loaded        : %', v_rows_loaded;
        RAISE NOTICE 'Table End Time     : %', v_table_end;
        RAISE NOTICE 'Load Duration      : % seconds',
            ROUND(EXTRACT(EPOCH FROM (
                v_table_end - v_table_start
            )), 2);

        RAISE NOTICE 'STATUS             : SUCCESS';
        RAISE NOTICE '----------------------------------------------------------';

    EXCEPTION
        WHEN OTHERS THEN

            GET STACKED DIAGNOSTICS
                v_error_message = MESSAGE_TEXT,
                v_error_context = PG_EXCEPTION_CONTEXT;

            RAISE NOTICE '';
            RAISE NOTICE 'STATUS             : FAILED';
            RAISE NOTICE 'Failed Table       : silver.erp_cust_az12';
            RAISE NOTICE 'Error Message      : %', v_error_message;
            RAISE NOTICE 'Error Context      : %', v_error_context;
            RAISE NOTICE '----------------------------------------------------------';

    END;

    -- =====================================================
    -- LOAD ERP LOCATION DATA
    -- =====================================================

    BEGIN

        v_table_start := clock_timestamp();

        RAISE NOTICE '';
        RAISE NOTICE 'Loading Table      : silver.erp_loc_a101';
        RAISE NOTICE 'Table Start Time   : %', v_table_start;

        TRUNCATE TABLE silver.erp_loc_a101;

        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )

        SELECT
            REPLACE("CID", '-', '') AS cid,

            CASE
                WHEN TRIM("CNTRY") = 'DE'
                    THEN 'Germany'

                WHEN TRIM("CNTRY") IN ('USA', 'US')
                    THEN 'United States'

                WHEN TRIM("CNTRY") = ''
                     OR "CNTRY" IS NULL
                    THEN 'n/a'

                ELSE TRIM("CNTRY")
            END AS cntry

        FROM bronze.erp_loc_a101;

        GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

        v_table_end := clock_timestamp();

        RAISE NOTICE 'Rows Loaded        : %', v_rows_loaded;
        RAISE NOTICE 'Table End Time     : %', v_table_end;
        RAISE NOTICE 'Load Duration      : % seconds',
            ROUND(EXTRACT(EPOCH FROM (
                v_table_end - v_table_start
            )), 2);

        RAISE NOTICE 'STATUS             : SUCCESS';
        RAISE NOTICE '----------------------------------------------------------';

    EXCEPTION
        WHEN OTHERS THEN

            GET STACKED DIAGNOSTICS
                v_error_message = MESSAGE_TEXT,
                v_error_context = PG_EXCEPTION_CONTEXT;

            RAISE NOTICE '';
            RAISE NOTICE 'STATUS             : FAILED';
            RAISE NOTICE 'Failed Table       : silver.erp_loc_a101';
            RAISE NOTICE 'Error Message      : %', v_error_message;
            RAISE NOTICE 'Error Context      : %', v_error_context;
            RAISE NOTICE '----------------------------------------------------------';

    END;

    -- =====================================================
    -- LOAD ERP PRODUCT CATEGORY DATA
    -- =====================================================

    BEGIN

        v_table_start := clock_timestamp();

        RAISE NOTICE '';
        RAISE NOTICE 'Loading Table      : silver.erp_px_cat_g1v2';
        RAISE NOTICE 'Table Start Time   : %', v_table_start;

        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )

        SELECT
            "ID"                   AS id,
            TRIM("CAT")           AS cat,
            TRIM("SUBCAT")        AS subcat,
            TRIM("MAINTENANCE")   AS maintenance

        FROM bronze.erp_px_cat_g1v2;

        GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

        v_table_end := clock_timestamp();

        RAISE NOTICE 'Rows Loaded        : %', v_rows_loaded;
        RAISE NOTICE 'Table End Time     : %', v_table_end;
        RAISE NOTICE 'Load Duration      : % seconds',
            ROUND(EXTRACT(EPOCH FROM (
                v_table_end - v_table_start
            )), 2);

        RAISE NOTICE 'STATUS             : SUCCESS';
        RAISE NOTICE '----------------------------------------------------------';

    EXCEPTION
        WHEN OTHERS THEN

            GET STACKED DIAGNOSTICS
                v_error_message = MESSAGE_TEXT,
                v_error_context = PG_EXCEPTION_CONTEXT;

            RAISE NOTICE '';
            RAISE NOTICE 'STATUS             : FAILED';
            RAISE NOTICE 'Failed Table       : silver.erp_px_cat_g1v2';
            RAISE NOTICE 'Error Message      : %', v_error_message;
            RAISE NOTICE 'Error Context      : %', v_error_context;
            RAISE NOTICE '----------------------------------------------------------';

    END;

    -- =====================================================
    -- PIPELINE END
    -- =====================================================

    v_pipeline_end := clock_timestamp();

    RAISE NOTICE '';
    RAISE NOTICE '==========================================================';
    RAISE NOTICE 'SILVER LAYER LOAD COMPLETED';
    RAISE NOTICE 'Pipeline End Time  : %', v_pipeline_end;

    RAISE NOTICE 'Total Duration     : % seconds',
        ROUND(EXTRACT(EPOCH FROM (
            v_pipeline_end - v_pipeline_start
        )), 2);

    RAISE NOTICE '==========================================================';

END;
$$;
