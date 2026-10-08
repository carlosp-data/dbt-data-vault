--# ROLES #---------------------------------
USE ROLE securityadmin;

CREATE ROLE IF NOT EXISTS dev_role COMMENT = 'Role for DEV environment, with read-only access to PROD';
CREATE ROLE IF NOT EXISTS prod_role COMMENT = 'Role for PROD environment, with no access to DEV';

GRANT ROLE dev_role TO ROLE sysadmin;   -- keeps the role hierarchy tidy
GRANT ROLE dev_role TO ROLE sysadmin;   -- keeps the role hierarchy tidy

GRANT ROLE dev_role TO USER cpalacios;
GRANT ROLE prod_role TO USER cpalacios;

--# GRANTS #--------------------------------
USE ROLE accountadmin;

GRANT USAGE ON WAREHOUSE compute_wh TO ROLE dev_role;
GRANT USAGE ON WAREHOUSE compute_wh TO ROLE prod_role;

GRANT USAGE ON DATABASE tasty_bytes TO ROLE dev_role;
GRANT USAGE ON DATABASE tasty_bytes TO ROLE prod_role;

-- dbt creates *_stg, *_vault, *_marts
GRANT CREATE SCHEMA ON DATABASE tasty_bytes TO ROLE dev_role;
GRANT CREATE SCHEMA ON DATABASE tasty_bytes TO ROLE prod_role;

GRANT USAGE ON SCHEMA tasty_bytes.source TO ROLE dev_role;
GRANT USAGE ON SCHEMA tasty_bytes.source TO ROLE prod_role;
GRANT SELECT ON ALL TABLES IN SCHEMA tasty_bytes.source TO ROLE dev_role;
GRANT SELECT ON ALL TABLES IN SCHEMA tasty_bytes.source TO ROLE prod_role;

-- GRANT SELECT ON FUTURE TABLES IN SCHEMA ...

--# COMPUTE #-------------------------------

CREATE OR REPLACE WAREHOUSE compute_big
    WAREHOUSE_SIZE = 'medium'
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

