# dbt project design

How the dbt project is organized, and why. Data Vault details are in
[raw_vault.md](raw_vault.md), the staging layer in [staging.md](staging.md) and the tests in
[testing.md](testing.md).

## Layers and responsibilities

Each layer has one job, and the rules about what it may *not* do matter as much as what it does.

| Layer | Folder | Does | Does not |
|---|---|---|---|
| Staging | `models/staging/` | Renames, casts, trims, flattens semi-structured data, drops empty columns. Adds hash keys, hashdiffs and `record_source`. | Join sources, apply business logic, set load timestamps. |
| Raw vault | `models/datavault/raw_vault/` | Integrates the sources around business keys (hubs, links, satellites) and keeps full history, insert-only. | Apply business rules. Data is stored as delivered. |
| Business vault | `models/datavault/business_vault/` | *(roadmap)* Cross-table business rules, point-in-time and bridge tables. | |
| Marts | `models/marts/` | *(roadmap)* Star schema for BI: SCD Type 2 dimensions, facts, monthly KPIs. | Read from staging or sources. |

Keeping business rules out of staging and the raw vault means a rule can change later without
reloading history: only the downstream models are rebuilt.

Materializations are set per folder in `dbt_project.yml`, so models only override them when they
need to:

```yaml
models:
  tasty_bytes:
    +static_analysis: strict
    staging:
      +schema: stg
      +materialized: view
    datavault:
      +schema: vault
      # insert-only: the loading macros select only new keys and changed rows
      +materialized: incremental
      +incremental_strategy: append
```

Staging models are **views**: they cost nothing to build, and the vault is the only layer that
reads them.

## Environments and access

| Target | Schema prefix | Role | Warehouse | Use |
|---|---|---|---|---|
| `dev` (default) | `dev_` | `dev_role` | `compute_wh` | Development |
| `prod` | `prod_` | `prod_role` | `compute_prod` | Deployment |

- **Schemas** follow dbt's default `<target_schema>_<custom_schema>`: `dev_stg`, `dev_vault`,
  `dev_marts`. No custom `generate_schema_name` is needed.
- **Roles** separate the environments. Both roles read the `source` schema and create their own
  schemas. `prod_role` has no access to dev objects. The setup is scripted in
  [`db_init/tasty_bytes_admin.sql`](../db_init/tasty_bytes_admin.sql).
- **Credentials** come from environment variables (`SF_ACCOUNT`, `SF_USER`, `SF_PASSWORD`,
  `SF_DATABASE`), read by `env_var()` in [`profiles.yml`](../profiles.yml). The file holds no
  secrets and is committed; a local `.env` (template: [`.env.example`](../.env.example)) holds the
  values.

## Conventions

- **Naming**
  - Staging: `stg_raw__<table>` (source name, double underscore, table).
  - Raw vault: `hub_`, `lnk_`, `sat_`, `esat_`. Business vault: `pit_`, `brg_`, `sal_`, `bsat_`.
  - Keys: `<entity>_hk` for hash keys, `<satellite>_hashdiff` for change-detection hashes.
  - One name per concept across every layer: the menu item is a **product** everywhere after
    staging.
- **SQL style**: lowercase, 4-space indent, trailing commas. Every model is a chain of CTEs:
  import CTEs first, then logic, then `final`, ending with `select * from final`. Columns are
  listed explicitly, except in import CTEs and the final select.
- **References**: always `ref()` and `source()`, never hard-coded table names, so lineage and
  environments resolve automatically.
- **Documentation**: one YAML file per model, with the same basename as the SQL file. Every model
  and every column has a description. Model descriptions state the grain, the primary key, what
  the model feeds, and the data facts found while profiling the source.

## Macros as the loading framework

The raw vault is loaded by six project macros in [`macros/datavault/`](../macros/datavault/), so
each vault model is a single macro call. A satellite, for example:

```sql
{{ sat(
    parent_hk='customer_hk',
    hashdiff='customer_pii_hashdiff',
    payload_columns=['cust_first_name', 'cust_last_name', ...],
    src_model='stg_raw__customers'
) }}
```

| Macro | Generates |
|---|---|
| `hub()` | A hub fed by one or more staging models, with one row per business key. |
| `link()` | A link between hubs, with optional dependent child keys. |
| `sat()` | A satellite that inserts a row only when the payload hash changes. |
| `eff_sat()` | An effectivity satellite that tracks which relationship is current. |
| `hash_key()` | The hash key expression used in staging. |
| `load_dts()`, `record_source()`, `ghost_*()` | Load metadata and ghost-record constants. |

How they are built:

- **The same SQL shape as hand-written models**: CTEs ending in `final`, so the compiled SQL is
  readable and debuggable.
- **Two branches**: `{% if is_incremental() %}` adds the filter against the existing table
  (`{{ this }}`); the first load skips it.
- **Hidden dependencies declared**: `eff_sat()` reads the link table only in its incremental
  branch. A `-- depends_on: {{ ref(link_model) }}` comment makes dbt order the models correctly on
  every run.
- **Documented like models**: each macro has a docstring with a usage example, and its arguments
  are described in [`_macros.yml`](../macros/datavault/_macros.yml).

Each Data Vault loading rule is written out in the macros, so it can be read in the compiled
SQL, and the macros are covered by unit tests (see [testing.md](testing.md#unit-tests)).

## Incremental, insert-only loading

Vault models use `materialized: incremental` with `incremental_strategy: append`. There is no
`unique_key` and no merge: the macros select only what is new, and the warehouse only appends.

| Object | Inserts a row when |
|---|---|
| Hub | the business key has not been seen before |
| Link | the relationship has not been seen before |
| Satellite | the key is new, or its hashdiff differs from its latest row |
| Effectivity satellite | a relationship starts, ends, or comes back |

Consequences:

- **Re-running a load is safe**: unchanged data inserts nothing.
- **No updates or deletes**: end dates (`load_end_dts`) are derived downstream, never stored.
- **Append instead of merge**: the macros already filter out existing keys in the `select`, so
  the warehouse only inserts and never rewrites existing rows.
- **A full refresh is needed only when a definition changes**: a satellite's payload or hashdiff,
  or a link's key columns. Otherwise old rows would no longer match the new hashes.

**Load timestamp**: every vault model stamps new rows with `load_dts()`, the start time of the dbt
invocation, so all models in one run share one value. The `load_dts` var overrides it, which is
how history can be simulated by loading data sets in date order:

```bash
dbt build -s datavault --vars '{load_dts: "2021-07-01 00:00:00"}'
```

Staging never sets `load_dts`: a view would either freeze the value at build time or change it on
every read.

## Static analysis with dbt Fusion

The project runs on the **dbt Fusion engine** (2.0) with `+static_analysis: strict` for every
model. Fusion parses and type-checks each model's SQL against the schemas of its upstream models
before anything runs, so a misspelled column, an ambiguous join column or a type error fails at
compile time instead of in the warehouse.

Strict mode rules out **introspective Jinja**: macros that query the warehouse while compiling,
such as `run_query()` or `dbt_utils.get_column_values()`. Column lists are therefore passed as
literal macro arguments. This also makes the generated SQL deterministic: the same code always
compiles to the same statement.

## Large tables

Orders (~248M rows) and order lines (~674M rows) account for most of the cost of every build, so
their models, in every layer, set:

```sql
{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}
```

- **A larger warehouse per model**: only these models use `compute_big`. The rest of the project
  keeps the small default warehouse, so compute is paid for only where it speeds things up.
- **Tag-based selection**: `-s tag:large_table` builds only the order models, and
  `--exclude tag:large_table` skips them during development.
- **Tests sized for the volume**: on these tables, tests check only the current batch, and the
  full-scan tests carry a `heavy_test` tag (see [testing.md](testing.md#tests-at-scale)).

## Decision log

| Decision | Alternatives considered | Reason |
|---|---|---|
| Hash keys and hashdiffs computed in staging | Compute them in each vault model | Computed once per source row, and every vault model that loads the same key gets the same value. |
| Project macros for vault loading | One hand-written model per vault table | One tested implementation of each loading pattern, reused by every hub, link and satellite. |
| `append` strategy, insert-only | `merge` with `unique_key` | The macros already select only new rows, so a merge would add nothing; append can never rewrite history. |
| `load_dts` set by the vault, overridable by a var | `current_timestamp` in staging | One value per run, and history can be simulated by loading data sets in order. |
| Staging as views | Tables | No storage or build cost; only the vault reads them. |
| Default schema naming | Custom `generate_schema_name` | Built-in behaviour already separates dev and prod. |
| `record_source` from `source()` | Typing the table name | Lineage can never drift from the real source relation. |
