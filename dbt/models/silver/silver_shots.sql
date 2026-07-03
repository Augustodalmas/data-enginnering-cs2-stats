{{ config(
    alias='shots',
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
    NULLIF(TRIM(b.player_name), '')::VARCHAR    AS player_name,
    NULLIF(TRIM(b.player_steamid), '')::BIGINT  AS player_steamid,
    NULLIF(TRIM(b.player_side), '')::VARCHAR    AS player_side,
    NULLIF(TRIM(b.player_X), '')::DOUBLE        AS player_X,
    NULLIF(TRIM(b.player_Y), '')::DOUBLE        AS player_Y,
    NULLIF(TRIM(b.player_Z), '')::DOUBLE        AS player_Z,
    NULLIF(TRIM(b.player_health), '')::INTEGER  AS player_health,
    NULLIF(TRIM(b.player_place), '')::VARCHAR   AS player_place,
    NULLIF(TRIM(b.tick), '')::INTEGER           AS tick,
    NULLIF(TRIM(b.round_num), '')::INTEGER      AS round_num,
    (NULLIF(TRIM(b.tick), '')::INTEGER - ir.round_start_tick)
        / t.taxa_de_tick                          AS segundos_desde_inicio_round,
    NULLIF(TRIM(b.weapon), '')::VARCHAR         AS weapon,
    NULLIF(TRIM(b.ct_side), '')::VARCHAR        AS ct_side,
    NULLIF(TRIM(b.t_side), '')::VARCHAR         AS t_side,
    LOWER(NULLIF(TRIM(b.silenced), ''))::BOOLEAN AS silenced,
    b.match_id,
    b._arquivo_origem,
    'silver'                 AS _camada,
    b._carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'shots') }} b
LEFT JOIN inicio_round ir ON ir.match_id = b.match_id
    AND ir.round_num = NULLIF(TRIM(b.round_num), '')::INTEGER
LEFT JOIN taxa t ON t.match_id = b.match_id
{% if is_incremental() %}
WHERE b.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
