{#-
    Loads a satellite, insert-only: a row is inserted for a parent key when the key is new or
    when its staged hashdiff differs from the hashdiff of its latest row in the satellite.
    Unchanged rows are skipped, so re-running a load adds nothing. Rows are never updated;
    `load_end_dts` is derived downstream.

    The staged rows are made distinct first, so a model where the parent key repeats with
    identical payload (for example menu types in `stg_raw__products`) loads one row per key.

    The ghost record (see `ghost_record.sql`) is inserted on the first load, with a NULL
    payload.

        {{ sat(
            parent_hk='customer_hk',
            hashdiff='customer_pii_hashdiff',
            payload_columns=['cust_first_name', 'cust_last_name'],
            src_model='stg_raw__customers'
        ) }}
-#}
{% macro sat(parent_hk, hashdiff, payload_columns, src_model) -%}

with

staged as (

    select distinct
        {{ parent_hk }},
        {{ hashdiff }},
        {%- for col in payload_columns %}
        {{ col }},
        {%- endfor %}
        {{ load_dts() }} as load_dts,
        record_source
    from {{ ref(src_model) }}

),

ghost as (

    select
        {{ ghost_hk() }} as {{ parent_hk }},
        {{ ghost_hk() }} as {{ hashdiff }},
        {%- for col in payload_columns %}
        null as {{ col }},
        {%- endfor %}
        {{ ghost_load_dts() }} as load_dts,
        {{ ghost_source() }} as record_source

),

candidates as (

    select
        {{ parent_hk }},
        {{ hashdiff }},
        {%- for col in payload_columns %}
        {{ col }},
        {%- endfor %}
        load_dts,
        record_source
    from staged

    union all

    select
        {{ parent_hk }},
        {{ hashdiff }},
        {%- for col in payload_columns %}
        {{ col }},
        {%- endfor %}
        load_dts,
        record_source
    from ghost

),
{%- if is_incremental() %}

latest as (

    -- current hashdiff of every parent key already in the satellite
    select
        {{ parent_hk }},
        {{ hashdiff }}
    from {{ this }}
    qualify row_number() over (partition by {{ parent_hk }} order by load_dts desc) = 1

),
{%- endif %}

final as (

    select
        candidates.{{ parent_hk }},
        candidates.load_dts,
        candidates.{{ hashdiff }},
        {%- for col in payload_columns %}
        candidates.{{ col }},
        {%- endfor %}
        candidates.record_source
    from candidates
    {%- if is_incremental() %}
    left join latest
        on candidates.{{ parent_hk }} = latest.{{ parent_hk }}
    -- insert-only: new parent keys and changed payloads
    where latest.{{ parent_hk }} is null
        or latest.{{ hashdiff }} != candidates.{{ hashdiff }}
    {%- endif %}

)

select * from final

{%- endmacro %}
