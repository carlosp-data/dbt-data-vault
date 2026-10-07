{#-
    Loads a hub, insert-only: one row per hash key, stamped with `load_dts()` the first time
    the key is seen. A key that is already in the hub is never inserted again.

    Several staging models can feed the same hub. They must expose the same hash key and
    business key column names. When a new key arrives from more than one model in the same
    batch, the row (and its `record_source`) comes from the first model in `src_models`.

    The ghost record (see `ghost_record.sql`) is inserted on the first load. Its all-zeros key
    is the one `hash_key()` returns for a NULL business key, and it wins over staged rows with
    that key.

        {{ hub(
            hk='city_hk',
            bk_columns=['city', 'country'],
            src_models=['stg_raw__customers', 'stg_raw__trucks']
        ) }}
-#}
{% macro hub(hk, bk_columns, src_models) -%}

with

staged as (
    {%- for src_model in src_models %}

    select
        {{ hk }},
        {%- for bk in bk_columns %}
        {{ bk }},
        {%- endfor %}
        {{ load_dts() }} as load_dts,
        record_source,
        {{ loop.index }} as source_priority
    from {{ ref(src_model) }}
    {%- if not loop.last %}

    union all
    {%- endif %}
    {%- endfor %}

),

ghost as (

    select
        {{ ghost_hk() }} as {{ hk }},
        {%- for bk in bk_columns %}
        null as {{ bk }},
        {%- endfor %}
        {{ ghost_load_dts() }} as load_dts,
        {{ ghost_source() }} as record_source,
        -- wins over staged rows whose business key is NULL (same hash key)
        0 as source_priority

),

candidates as (

    select
        {{ hk }},
        {%- for bk in bk_columns %}
        {{ bk }},
        {%- endfor %}
        load_dts,
        record_source,
        source_priority
    from staged

    union all

    select
        {{ hk }},
        {%- for bk in bk_columns %}
        {{ bk }},
        {%- endfor %}
        load_dts,
        record_source,
        source_priority
    from ghost

),

deduplicated as (

    select
        {{ hk }},
        {%- for bk in bk_columns %}
        {{ bk }},
        {%- endfor %}
        load_dts,
        record_source
    from candidates
    qualify row_number() over (partition by {{ hk }} order by source_priority) = 1

),

final as (

    select
        deduplicated.{{ hk }},
        {%- for bk in bk_columns %}
        deduplicated.{{ bk }},
        {%- endfor %}
        deduplicated.load_dts,
        deduplicated.record_source
    from deduplicated
    {%- if is_incremental() %}
    -- insert-only: skip keys already loaded
    where not exists (
        select 1
        from {{ this }} as hub
        where hub.{{ hk }} = deduplicated.{{ hk }}
    )
    {%- endif %}

)

select * from final

{%- endmacro %}
