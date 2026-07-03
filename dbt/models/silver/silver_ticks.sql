{{ config(
    alias='ticks',
    materialized='incremental',
    on_schema_change='append_new_columns',
    tags=['silver'],
    meta={
        'camada': 'silver',
        'particao': 'match_id',
        'owner': 'augustodalmas',
    }
) }}

WITH taxa AS (
    {{ taxa_de_tick_por_partida() }}
),
inicio_round AS (
    {{ round_start_por_partida() }}
)

SELECT
    NULLIF(TRIM(b.tick), '')::INTEGER      AS tick,
    NULLIF(TRIM(b.round_num), '')::INTEGER AS round_num,
    (NULLIF(TRIM(b.tick), '')::INTEGER - ir.round_start_tick)
        / t.taxa_de_tick                     AS segundos_desde_inicio_round,
    NULLIF(TRIM(b.health), '')::INTEGER    AS health,
    NULLIF(TRIM(b.steamid), '')::BIGINT    AS steamid,
    NULLIF(TRIM(b.name), '')::VARCHAR      AS name,
    NULLIF(TRIM(b.side), '')::VARCHAR      AS side,
    NULLIF(TRIM(b.place), '')::VARCHAR     AS place,
    NULLIF(TRIM(b.X), '')::DOUBLE          AS X,
    NULLIF(TRIM(b.Y), '')::DOUBLE          AS Y,
    NULLIF(TRIM(b.Z), '')::DOUBLE          AS Z,
    b.match_id,
    b._arquivo_origem,
    'silver'                 AS _camada,
    b._carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'ticks') }} b
LEFT JOIN inicio_round ir ON ir.match_id = b.match_id
    AND ir.round_num = NULLIF(TRIM(b.round_num), '')::INTEGER
LEFT JOIN taxa t ON t.match_id = b.match_id
{% if is_incremental() %}
WHERE b.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
