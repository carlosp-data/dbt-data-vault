# Source data and staging

The source data, what profiling it revealed, and how the staging layer prepares it for the Data
Vault. Project-wide design is in [dbt_design.md](dbt_design.md).

## Source data

**Tasty Bytes** is Snowflake's fictional global food-truck company. The raw files come from the
public bucket `s3://sfquickstarts/tasty-bytes-builder-education/` and are loaded once into
`tasty_bytes.source` by [`db_init/tasty_bytes_source.sql`](../db_init/tasty_bytes_source.sql). In
dbt they are the source `raw`, declared in
[`_raw__sources.yml`](../models/staging/_raw__sources.yml).

| Table | Rows | Grain |
|---|---:|---|
| `customers` | 222,540 | One loyalty-program member |
| `franchises` | 335 | One franchise and city (the id is not unique, see below) |
| `locations` | 13,093 | One selling location |
| `products` | 100 | One menu item |
| `trucks` | 450 | One food truck |
| `orders_header` | ~248M | One order (2019-01 to 2022-11) |
| `orders_detail` | ~674M | One order line |

**Business domain.** A franchise operates one or more trucks; franchise 1 is Tasty Bytes itself
and owns every company-operated truck. Each truck sells one brand (menu type) and its products.
Trucks work shifts at locations, usually a morning and an evening shift at two different places.
Orders are placed at a truck during a shift, optionally by a loyalty member, and have one line per
product.

## Data profiling findings

Every modeling decision was checked against the data first. The findings below shaped the models;
they are also recorded in each model's YAML description.

**Columns and values**

- Eight columns are entirely NULL and are not staged, among them `discount_id`, `order_channel`,
  `served_ts`, the tax and discount amounts, and the customers' `favourite_brand`.
- Every amount is in USD. `order_amount` always equals `order_total`, and a line amount always
  equals `quantity × unit_price`.
- The product health metrics are a VARIANT whose array always holds exactly one element, so it can
  be flattened into columns instead of rows.
- Coded values are kept as delivered: `children_count` is text (`0`–`4`, `5+`, `Undisclosed`), and
  the source spells `Divorced/Seperated` that way.

**Keys and relationships**

- `franchise_id` is not unique: 335 rows for 325 franchises. Five ids are exact duplicates, and
  five more appear with two different cities because the franchise operates in both.
- Every foreign key resolves: truck → franchise and brand, order → truck, location and customer,
  order line → order and product.
- About 95% of orders have no `customer_id`: they come from customers outside the loyalty program.

**Geography**

- 32 (city, country) pairs, consistent across the four tables that carry them, with one exception:
  customers say `United Kingdom` for London and Manchester, where the other tables say `England`.
- `locations` covers every city of trucks and franchises, so it is the reference source for city
  attributes such as the ISO country code.
- `trucks.iso_region` is not an ISO code: it uses the region names of `locations`, while
  `trucks.region` is sometimes wrong for the city. Only the first is staged.

**Shifts and time**

- The source has no shift table. A shift is one truck at one location in one time window, and every
  order of a shift agrees on truck, location, date and times. No shift crosses midnight, so the
  shift date is derived from the order timestamp.
- Timestamps carry no time zone: they are local time at the truck.
- The sources have no load timestamp or change-tracking column. Each table is a single snapshot, so
  history is built by the vault on each load.

## Staging rules

- **One view per source table**, `stg_raw__<table>`, with a YAML file of the same name.
- **Light transformations only**: rename to clear snake_case names, cast types, trim strings,
  convert 0/1 flags to booleans, flatten the health-metrics VARIANT, drop all-NULL columns.
- **No joins and no business logic.** Anything that combines tables belongs to the vault or later.
- **No deduplication** of repeated keys with identical data: the vault macros keep one row per key.
  Staging would deduplicate only conflicting rows, and only on a business decision.
- **Model structure**: a `source` CTE, a `renamed` CTE, then `final` with the vault metadata, and
  `select * from final`.

## Data Vault metadata in staging

Staging computes everything the vault needs, so each vault model only selects and loads.

- **Hash keys** come from the project macro `hash_key()`, for hubs and links alike. It sorts the
  key columns before hashing, so two models that list them in a different order still produce the
  same key. When every key column is NULL it returns the all-zeros ghost key: the customer of an
  anonymous order points at a "ghost" customer instead of being NULL.
- **Hashdiffs** (one per satellite) hash the payload with `dbt_utils.generate_surrogate_key()`, with
  the columns listed alphabetically. A changed hashdiff is what makes the vault insert a new
  version.
- **`record_source`** comes from `record_source(source('raw', '<table>'))`, which renders the
  source relation name, for example `'tasty_bytes.source.orders_header'`. The lineage is never typed
  by hand.
- **No load timestamp**: `load_dts` is set by the vault when rows are inserted (see
  [dbt_design.md](dbt_design.md#incremental-insert-only-loading)).
- **Column order**: hash keys, business keys, payload, hashdiffs, `record_source`.

Example, from [`stg_raw__orders_header`](../models/staging/stg_raw__orders_header.sql):

```sql
final as (

    select
        {{ hash_key(['order_id']) }} as order_hk,
        {{ hash_key(['customer_id']) }} as customer_hk,
        {{ hash_key(['customer_id', 'order_id', 'shift_id']) }} as order_shift_customer_hk,
        ...
        {{ dbt_utils.generate_surrogate_key([
            'order_amount',
            'order_currency',
            'order_date',
            'order_total',
            'order_ts'
        ]) }} as order_details_hashdiff,
        {{ record_source(source('raw', 'orders_header')) }} as record_source
    from renamed

)
```

## Models

| Model | Grain | Notable transformations | Feeds |
|---|---|---|---|
| [`stg_raw__customers`](../models/staging/stg_raw__customers.sql) | `customer_id` | PII and profile attributes hashed separately, for separate satellites | customer, city |
| [`stg_raw__franchises`](../models/staging/stg_raw__franchises.sql) | Source row | Kept as delivered; the vault keeps one row per franchise and per franchise–city pair | franchise, city |
| [`stg_raw__locations`](../models/staging/stg_raw__locations.sql) | `location_id` | ISO country code staged as a city attribute | location, city |
| [`stg_raw__products`](../models/staging/stg_raw__products.sql) | `product_id` | Health-metrics VARIANT flattened into flags and an ingredients array | product, menu type |
| [`stg_raw__trucks`](../models/staging/stg_raw__trucks.sql) | `truck_id` | 0/1 flags to booleans; truck region from `iso_region` | truck, franchise, menu type, city |
| [`stg_raw__orders_header`](../models/staging/stg_raw__orders_header.sql) | `order_id` | All-NULL columns dropped; `location_id` cast from FLOAT; shift and order dates derived | order, shift |
| [`stg_raw__orders_detail`](../models/staging/stg_raw__orders_detail.sql) | `order_detail_id` | All-NULL columns dropped; `price` renamed `line_amount` | order line |

The two order models run on the larger `compute_big` warehouse and carry the `large_table` tag.
The exact vault objects each model feeds are listed in its YAML description.
