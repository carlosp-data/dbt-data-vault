{#-
    Data Vault hash key of a business key, for hubs and links. When every key column is NULL
    it returns the all-zeros ghost key (`ghost_hk()`), so a missing key points at the ghost
    record of the hub. Otherwise it hashes the columns with `dbt_utils.generate_surrogate_key()`,
    which also handles keys where only some columns are NULL (for example the order link of an
    anonymous order). List the columns in alphabetical order.

        {{ hash_key(['customer_id']) }} as customer_hk
        {{ hash_key(['city', 'country']) }} as city_hk

    Hashdiffs keep using `dbt_utils.generate_surrogate_key()` directly.
-#}
{% macro hash_key(key_columns) -%}
    case
        when {% for col in key_columns %}{{ col }} is null{% if not loop.last %} and {% endif %}{% endfor %}
            then {{ ghost_hk() }}
        else {{ dbt_utils.generate_surrogate_key(key_columns) }}
    end
{%- endmacro %}
