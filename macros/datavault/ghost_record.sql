{#-
    Constants of the Data Vault ghost record. Every hub and satellite holds one ghost row:

        hash key        '00000000000000000000000000000000' (also the satellite hashdiff)
        load_dts        1900-01-01 00:00:00
        record_source   'SYSTEM'
        business key    NULL (hubs), payload NULL (satellites)

    `hash_key()` returns the ghost key for a NULL business key, so a link row with a missing
    key (for example the customer of an anonymous order) points at the ghost row of the hub.
    PITs point at the satellite ghost row when a key has no satellite version at the snapshot
    date, so PIT → satellite joins are always inner joins. Links have no ghost row.
-#}
{% macro ghost_hk() -%}
    '00000000000000000000000000000000'
{%- endmacro %}

{% macro ghost_load_dts() -%}
    cast('1900-01-01 00:00:00' as timestamp_ntz)
{%- endmacro %}

{% macro ghost_source() -%}
    'SYSTEM'
{%- endmacro %}
