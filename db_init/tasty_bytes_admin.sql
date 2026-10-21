/*--
Snowflake setup for the dbt project: database, roles, grants and warehouses.
Run it once, before 'tasty_bytes_source.sql'. Set the Snowflake user that runs dbt below.
--*/

SET dbt_user = '<your_snowflake_user>';

--# DATABASE #------------------------------
USE ROLE sysadmin;

CREATE DATABASE IF NOT EXISTS tasty_bytes;
CREATE SCHEMA IF NOT EXISTS tasty_bytes.source;

--# ROLES #---------------------------------
USE ROLE securityadmin;

CREATE ROLE IF NOT EXISTS dev_role COMMENT = 'Role for DEV environment';
CREATE ROLE IF NOT EXISTS prod_role COMMENT = 'Role for PROD environment, with no access to DEV';

GRANT ROLE dev_role TO ROLE sysadmin;
GRANT ROLE prod_role TO ROLE sysadmin;

GRANT ROLE dev_role TO USER IDENTIFIER($dbt_user);
GRANT ROLE prod_role TO USER IDENTIFIER($dbt_user);

--# GRANTS #--------------------------------
USE ROLE accountadmin;

GRANT USAGE ON WAREHOUSE compute_wh TO ROLE dev_role;
GRANT USAGE ON WAREHOUSE compute_wh TO ROLE prod_role;

GRANT USAGE ON DATABASE tasty_bytes TO ROLE dev_role;
GRANT USAGE ON DATABASE tasty_bytes TO ROLE prod_role;

-- dbt creates *_stg, *_vault, *_marts
GRANT CREATE SCHEMA ON DATABASE tasty_bytes TO ROLE dev_role;
GRANT CREATE SCHEMA ON DATABASE tasty_bytes TO ROLE prod_role;

-- read-only access to the source tables, including the ones loaded after this script
GRANT USAGE ON SCHEMA tasty_bytes.source TO ROLE dev_role;
GRANT USAGE ON SCHEMA tasty_bytes.source TO ROLE prod_role;
GRANT SELECT ON ALL TABLES IN SCHEMA tasty_bytes.source TO ROLE dev_role;
GRANT SELECT ON ALL TABLES IN SCHEMA tasty_bytes.source TO ROLE prod_role;
GRANT SELECT ON FUTURE TABLES IN SCHEMA tasty_bytes.source TO ROLE dev_role;
GRANT SELECT ON FUTURE TABLES IN SCHEMA tasty_bytes.source TO ROLE prod_role;

--# COMPUTE #-------------------------------

CREATE OR REPLACE WAREHOUSE compute_big
    WAREHOUSE_SIZE = 'large'
    WAREHOUSE_TYPE = 'standard'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
COMMENT = 'development warehouse for Orders tables';

CREATE OR REPLACE WAREHOUSE compute_prod
    WAREHOUSE_SIZE = 'small'
    WAREHOUSE_TYPE = 'standard'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
COMMENT = 'production warehouse for the project';

-- the order models run on compute_big in every target
GRANT USAGE ON WAREHOUSE compute_big TO ROLE dev_role;
GRANT USAGE ON WAREHOUSE compute_big TO ROLE prod_role;
GRANT USAGE ON WAREHOUSE compute_prod TO ROLE prod_role;
