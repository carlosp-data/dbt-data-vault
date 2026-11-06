{#-
    Drops the schemas built by a CI run, called when a pull request is closed:

        dbt run-operation drop_ci_schema --target ci

    The base schema comes from the env var `DBT_CI_SCHEMA` (for example `ci_pr_42`). dbt
    builds each layer in `<base>_<custom_schema>` (`ci_pr_42_stg`, `ci_pr_42_vault`), so the
    macro drops the base schema and every schema named `<base>_*`.

    Guards, each of which stops the macro before anything is dropped:

    - the target must be `ci`;
    - the base schema must start with `ci_` and contain only lowercase letters, digits and
      underscores (it is inserted into SQL, so nothing else is accepted).
-#}
{% macro drop_ci_schema() -%}

    {%- set base_schema = env_var('DBT_CI_SCHEMA', '') | trim | lower -%}
    {%- set allowed_chars = 'abcdefghijklmnopqrstuvwxyz0123456789_' -%}

    {%- if target.name != 'ci' -%}
        {{ exceptions.raise_compiler_error(
            "drop_ci_schema runs only on the 'ci' target, not '" ~ target.name ~ "'. Nothing dropped."
        ) }}
    {%- endif -%}

    {%- if not base_schema.startswith('ci_') -%}
        {{ exceptions.raise_compiler_error(
            "DBT_CI_SCHEMA must start with 'ci_', got '" ~ base_schema ~ "'. Nothing dropped."
        ) }}
    {%- endif -%}

    {%- for char in base_schema -%}
        {%- if char not in allowed_chars -%}
            {{ exceptions.raise_compiler_error(
                "DBT_CI_SCHEMA may only contain a-z, 0-9 and '_', got '" ~ base_schema ~ "'. Nothing dropped."
            ) }}
        {%- endif -%}
    {%- endfor -%}

    {%- if execute -%}

        {%- set find_schemas -%}
            select schema_name
            from {{ target.database }}.information_schema.schemata
            where lower(schema_name) = '{{ base_schema }}'
                or startswith(lower(schema_name), '{{ base_schema }}_')
        {%- endset -%}

        {%- set ci_schemas = run_query(find_schemas).columns[0].values() -%}

        {%- if ci_schemas | length == 0 -%}
            {{ log("No schema matches '" ~ base_schema ~ "'. Nothing dropped.", info=true) }}
        {%- endif -%}

        {%- for schema_name in ci_schemas -%}
            {%- do run_query('drop schema if exists ' ~ target.database ~ '.' ~ schema_name ~ ' cascade') -%}
            {{ log("Dropped schema " ~ target.database ~ "." ~ schema_name, info=true) }}
        {%- endfor -%}

    {%- endif -%}

{%- endmacro %}
