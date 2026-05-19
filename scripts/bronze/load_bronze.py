# =========================================================
# BRONZE LAYER ETL PIPELINE
# ---------------------------------------------------------
# This script automates the ingestion of raw CRM and ERP
# CSV files into the PostgreSQL bronze layer.
#
# Features:
# - Reads source CSV files using pandas
# - Loads data into PostgreSQL using SQLAlchemy
# - Tracks execution time for each table load
# - Logs pipeline activity and failures
# - Creates both console and log file outputs
# =========================================================

import pandas as pd
from sqlalchemy import create_engine
import logging
import time
from datetime import datetime
import os
from dotenv import load_dotenv

# =========================================================
# LOAD ENVIRONMENT VARIABLES
# =========================================================

load_dotenv()

# =========================================================
# LOGGING CONFIGURATION
# =========================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.FileHandler("etl_pipeline.log"),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# =========================================================
# DATABASE CONNECTION
# =========================================================

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")

DB_CONNECTION = (
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

engine = create_engine(DB_CONNECTION)

# =========================================================
# FILE CONFIGURATION
# =========================================================

BASE_PATH = "datasets"

FILES_TO_LOAD = [
    {
        "file_path": f"{BASE_PATH}/source_crm/cust_info.csv",
        "table_name": "crm_cust_info"
    },
    {
        "file_path": f"{BASE_PATH}/source_crm/prd_info.csv",
        "table_name": "crm_prd_info"
    },
    {
        "file_path": f"{BASE_PATH}/source_crm/sales_details.csv",
        "table_name": "crm_sales_details"
    },
    {
        "file_path": f"{BASE_PATH}/source_erp/cust_az12.csv",
        "table_name": "erp_cust_az12"
    },
    {
        "file_path": f"{BASE_PATH}/source_erp/loc_a101.csv",
        "table_name": "erp_loc_a101"
    },
    {
        "file_path": f"{BASE_PATH}/source_erp/px_cat_g1v2.csv",
        "table_name": "erp_px_cat_g1v2"
    }
]

# =========================================================
# LOAD FUNCTION
# =========================================================

def load_csv_to_postgres(file_path, table_name):

    start_time = time.time()

    try:
        logger.info(f"Starting load for table: {table_name}")

        # Read CSV
        df = pd.read_csv(file_path)

        logger.info(
            f"CSV loaded successfully | Rows: {len(df)} | Columns: {len(df.columns)}"
        )

        # Load into PostgreSQL
        df.to_sql(
            table_name,
            schema="bronze",
            con=engine,
            if_exists="replace",
            index=False
        )

        end_time = time.time()

        logger.info(
            f"SUCCESS: {table_name} loaded successfully "
            f"in {round(end_time - start_time, 2)} seconds"
        )

    except Exception as e:

        logger.error(
            f"FAILED loading table: {table_name} | Error: {str(e)}",
            exc_info=True
        )

# =========================================================
# MAIN EXECUTION
# =========================================================

def main():

    pipeline_start = datetime.now()

    logger.info("=" * 70)
    logger.info("STARTING BRONZE LAYER LOAD")
    logger.info("=" * 70)

    try:

        # Test connection
        with engine.connect() as conn:
            logger.info("Database connection established successfully")

        # Load all files
        for file in FILES_TO_LOAD:
            load_csv_to_postgres(
                file["file_path"],
                file["table_name"]
            )

        pipeline_end = datetime.now()

        logger.info("=" * 70)
        logger.info("PIPELINE COMPLETED SUCCESSFULLY")
        logger.info(f"Start Time: {pipeline_start}")
        logger.info(f"End Time: {pipeline_end}")
        logger.info("=" * 70)

    except Exception as e:

        logger.critical(
            f"PIPELINE FAILURE: {str(e)}",
            exc_info=True
        )

# =========================================================
# ENTRY POINT
# =========================================================

if __name__ == "__main__":
    main()
