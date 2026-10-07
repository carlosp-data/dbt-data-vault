{#-
    Loads a link, insert-only: one row per link hash key, stamped with `load_dts()` the first
    time the relationship is seen. A relationship that is already in the link is never
    inserted again, even if it stops being current (effectivity satellites track that).

    Several staging models can feed the same link. They must expose the same column names.
    When a new key arrives from more than one model in the same batch, the row (and its
    `record_source`) comes from the first model in `src_models`.

        {{ link(
            link_hk='truck_franchise_hk',
            fk_columns=['truck_hk', 'franchise_hk'],
            src_models=['stg_raw__trucks']
        ) }}
-#}
{% macro link(link_hk, fk_columns, src_models) -%}

with

staged as (
    {%- for src_model in src_models %}

    select
        {{ link_hk }},
        {%- for fk in fk_columns %}
        {{ fk }},
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

deduplicated as (

    select
        {{ link_hk }},
        {%- for fk in fk_columns %}
        {{ fk }},
        {%- endfor %}
        load_dts,
        record_source
    from staged
    qualify row_number() over (partition by {{ link_hk }} order by source_priority) = 1

),

final as (

    select
        deduplicated.{{ link_hk }},
        {%- for fk in fk_columns %}
        deduplicated.{{ fk }},
        {%- endfor %}
        deduplicated.load_dts,
        deduplicated.record_source
    from deduplicated
    {%- if is_incremental() %}
    -- insert-only: skip relationships already loaded
    where not exists (
        select 1
        from {{ this }} as lnk
        where lnk.{{ link_hk }} = deduplicated.{{ link_hk }}
    )
    {%- endif %}

)

select * from final

{%- endmacro %}
