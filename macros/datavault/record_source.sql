{#-
    Data Vault `record_source` literal, derived from a `source()` relation so the lineage is
    never typed by hand. Identifier quotes are stripped from the rendered name:

        {{ record_source(source('raw', 'customers')) }} as record_source
        -- 'tasty_bytes.source.customers'
-#}
{% macro record_source(source_relation) -%}
    '{{ source_relation | string | replace('"', '') }}'
{%- endmacro %}
