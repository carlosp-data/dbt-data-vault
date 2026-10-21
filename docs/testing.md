# Testing

About **350 data tests** check the data on every build, and **8 unit tests** check the logic of
the models and loading macros on fixed inputs. Tests are declared in each model's YAML file, next
to its documentation.

## Approach by layer

| Layer | What is tested | Tests |
|---|---|---|
| Staging | Keys, required values, value domains and references between sources | `not_null` on hash keys, business keys and hashdiffs; `unique` on business keys; `accepted_values` on fixed domains (currency, gender, language, ...); `relationships` from each foreign key to its staged parent |
| Hubs | One row per key | `unique` and `not_null` on the hash key and the business key |
| Links | One row per relationship, and every hub key exists | `unique` and `not_null` on the link hash key; `relationships` from each hub key to its hub |
| Satellites | One version per key and load, and every parent exists | `dbt_utils.unique_combination_of_columns` on (parent key, `load_dts`); `relationships` to the parent hub or link |
| Macros | Loading logic: deduplication, ghost records, incremental inserts, change detection | Unit tests |

Tests encode the **facts found while profiling** the data, so a new data set that breaks an
assumption fails the build instead of silently producing wrong numbers. For example,
`order_currency` accepts only `USD`, because summing amounts is safe only while that holds.

Where a test is deliberately different from the standard, its config says why. For example, the
ghost record of `sat_order_line_details` has no parent (links have no ghost row), so its
`relationships` test excludes it:

```yaml
- relationships:
    arguments:
      to: ref('lnk_order_line')
      field: order_line_hk
    config:
      # the ghost record has no parent: links have no ghost row
      where: "record_source != 'SYSTEM' AND load_dts >= {{ load_dts() }}"
      tags: ['heavy_test']
```

## Tests at scale

On the order tables (~248M orders, ~674M order lines), tests dominate the build time. Three
techniques keep them affordable without losing coverage:

1. **Test only the current batch.** In the vault, the tests on the order links and satellites
   filter on the load timestamp of the run:

   ```yaml
   config:
     where: "load_dts >= {{ load_dts() }}"
   ```

   Rows already in the vault were tested when they were loaded. The first load still tests
   everything.

2. **Tag the full-scan tests.** Tests that must read the whole table, such as `unique` on a
   link key or `relationships` to `hub_order`, are tagged `heavy_test`. Routine runs skip them
   with `--exclude tag:heavy_test`, and a full build still runs them.

3. **Avoid redundant expensive tests.** The large staging views have no `unique` test on their
   computed hash keys: uniqueness is already tested on the business key, and the hash is derived
   from it.

The order models also run on the larger `compute_big` warehouse (see
[dbt_design.md](dbt_design.md#large-tables)).

## Unit tests

Unit tests run the model's SQL on rows given in the YAML and compare the result with expected
rows, without reading the real tables. Incremental cases override `is_incremental()` and provide
the existing table as the `this` input, so the insert-only logic can be tested against a known
state.

| Unit test | Proves that |
|---|---|
| `stg_raw__orders_header_null_customer_gets_ghost_key` | An anonymous order gets the ghost customer key, while a member's id hashes normally. The link key hashes normally in both cases, and the dates come from the order timestamp. |
| `hub_city_first_load_dedups_sources_and_adds_ghost` | A city staged by several models loads once, from the highest-priority model, and the ghost record is added on the first load. |
| `hub_city_incremental_inserts_only_new_keys` | On an incremental run, keys already in the hub (including the ghost record) are skipped and only new cities are inserted. |
| `lnk_truck_franchise_incremental_adds_reassignment` | A truck moved to another franchise adds a new link row, and existing pairs are not inserted again. |
| `lnk_order_line_keeps_dependent_child_key` | The same product on two lines of one order gives two link rows, and a line already loaded is not inserted again. |
| `sat_menu_type_details_first_load_dedups_and_adds_ghost` | A menu type repeated on several products loads one row, plus the ghost record. |
| `sat_product_pricing_incremental_detects_hashdiff_changes` | A new product and a changed price insert a version (even when a price returns to an earlier value); unchanged products and the ghost record are skipped. |
| `esat_truck_city_incremental_tracks_moves` | A truck that moves opens its new city and closes the old one; an unchanged truck inserts nothing; a truck that returns to an earlier city reopens it; a truck missing from the batch stays active. |

The load timestamp is fixed with a var override (`load_dts: '2026-01-01 00:00:00'`), so expected
rows are deterministic. Expected hash values follow the `dbt_utils.generate_surrogate_key()`
formula: the MD5 of the values cast to text, with NULLs replaced, joined with `-`.

## Running the tests

```bash
dbt build --exclude tag:heavy_test   # routine run: build and test, skip full scans
dbt build                            # full run, all tests
dbt test --select test_type:unit     # unit tests only
```
