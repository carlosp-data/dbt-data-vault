# dbt-data-vault

Data engineering project showcasing a modern data warehouse on Snowflake using
dbt, Data Vault 2.0 for core data modeling, and SCD Type 2 dimensional marts.
Designed to demonstrate scalable data modeling, ELT workflows, testing, and
analytics engineering best practices.

## Architecture

| Layer | Folder | Schema (dev) | Materialization |
|---|---|---|---|
| Staging | `models/staging/` | `dev_stg` | view |
| Data Vault | `models/datavault/` | `dev_vault` | incremental, insert-only |
| Marts | `models/marts/` | `dev_marts` | table |

## Source tables

The data is Snowflake's fictional **Tasty Bytes** food-truck company, loaded once from
`s3://sfquickstarts/tasty-bytes-builder-education/` into `tasty_bytes.source` (see `db_init/`).
Each table has one staging view, `stg_raw__<table>`.

| Table | Grain (business key) | Rows | Description |
|---|---|---:|---|
| `customers` | `customer_id` | 222,540 | Loyalty-program members, with PII and profile attributes. |
| `franchises` | `franchise_id` | 335 | Franchisees operating trucks. 325 distinct ids; staging keeps one row per id. Franchise 1 is Tasty Bytes itself. |
| `locations` | `location_id` | 13,093 | Places where the trucks sell, with city, region and country. |
| `products` | `menu_item_id` | 100 | Menu items with category, cost, price and health metrics, for 15 menu types (truck brands). |
| `trucks` | `truck_id` | 450 | Food trucks, with their franchise, menu type, primary city and vehicle data. |
| `orders_header` | `order_id` | ~248M | Orders placed at a truck, location and shift, optionally by a loyalty customer (2019-01 to 2022-11). |
| `orders_detail` | `order_detail_id` | ~674M | Order lines: product, quantity, unit price and line amount. |

## Raw Data Vault tables (RV)

Raw vault in `models/datavault/raw_vault/`. Every object is loaded insert-only by a project
macro (`macros/datavault/`): `hub`, `link`, `sat` and `eff_sat`. Each row is stamped with
`load_dts` and `record_source`. Every hub and satellite holds a ghost record with an all-zeros
key: a NULL business key (such as the customer of an anonymous order) hashes to it.

### Hubs

| Table | Business key | Loaded from |
|---|---|---|
| `hub_customer` | `customer_id` | customers |
| `hub_franchise` | `franchise_id` | franchises, trucks |
| `hub_truck` | `truck_id` | trucks |
| `hub_location` | `location_id` | locations |
| `hub_product` | `product_id` | products |
| `hub_menu_type` | `menu_type_id` | products, trucks |
| `hub_city` | `city`, `country` | locations, trucks, franchises, customers |

### Links

| Table | Hubs | Loaded from |
|---|---|---|
| `lnk_truck_franchise` | truck ↔ franchise | trucks |
| `lnk_truck_menu_type` | truck ↔ menu type | trucks |
| `lnk_product_menu_type` | product ↔ menu type | products |
| `lnk_customer_city` | customer ↔ city | customers |
| `lnk_franchise_city` | franchise ↔ city | franchises |
| `lnk_location_city` | location ↔ city | locations |
| `lnk_truck_city` | truck ↔ city | trucks |

### Satellites

| Table | Parent | Payload |
|---|---|---|
| `sat_customer_pii` | `hub_customer` | Name, email, phone, birth date, postal code |
| `sat_customer_profile` | `hub_customer` | Gender, language, favourite brand, marital status, children, sign-up date |
| `sat_franchise_pii` | `hub_franchise` | Franchisee name, email, phone |
| `sat_location_details` | `hub_location` | Placekey, name, region, country code |
| `sat_product_details` | `hub_product` | Name, category, subcategory, health flags, ingredients |
| `sat_product_pricing` | `hub_product` | Cost of goods, sale price |
| `sat_menu_type_details` | `hub_menu_type` | Menu type (cuisine), truck brand name |
| `sat_truck_details` | `hub_truck` | Region codes, ownership and EV flags, make, model, year, opening date |
| `esat_customer_city` | `lnk_customer_city` | Effectivity (`is_active`): the customer's current city |
| `esat_truck_city` | `lnk_truck_city` | Effectivity (`is_active`): the truck's current primary city |

The order objects (`hub_order`, `hub_shift`, the order link and the order lines), the business
vault (PITs, bridges, derived satellites) and the marts are not built yet.

# License

This is a personal portfolio project. The source code is provided for viewing
and evaluation purposes only. All rights reserved. See [LICENSE](LICENSE) for details.
