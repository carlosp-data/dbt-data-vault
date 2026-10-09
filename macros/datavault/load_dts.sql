{#-
    Load timestamp of a Data Vault load (`load_dts`). Called by the vault loading models, not
    by staging, so the value is set when rows are inserted and never stored in a view.

    Defaults to the start time (UTC) of the current dbt invocation, so every model built in
    the same run shares one value. Override it to simulate a specific load:

        dbt build --vars '{load_dts: "2026-01-01 00:00:00"}'
-#}
{% macro load_dts() -%}
    {%- set ts = var('load_dts', run_started_at.strftime('%Y-%m-%d %H:%M:%S.%f')) -%}
    cast('{{ ts }}' as timestamp_ntz)
{%- endmacro %}
