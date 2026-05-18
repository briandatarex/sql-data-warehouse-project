/*
=======================================================================
Create a new database named "DataWarehouse" 
=======================================================================

Script Purpose: This script is designed to set up a new database environment for a data warehouse. 
It creates a new database named "DataWarehouse" and establishes three schemas within it: 
                    1. bronze
                    2. silver 
                    3. gold
These schemas can be used to organize data based on its level of processing or quality, 

Bronze representing raw data, 
Silver representing cleaned and processed data, 
Gold representing highly curated and refined data.

Note: 
The "WITH (FORCE)" option in the DROP DATABASE statement is used to forcefully drop the database 
even if there are active connections to it. 

Proceed with caution and ensure you have proper backups before running this script.
*/

-- Drop the database if it already exists to ensure a clean setup
DROP DATABASE IF EXISTS "DataWarehouse" WITH (FORCE);

-- Create a new database named "DataWarehouse"

CREATE DATABASE "DataWarehouse";

-- Create three schemas: bronze, silver, gold within the "DataWarehouse" database
CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;


