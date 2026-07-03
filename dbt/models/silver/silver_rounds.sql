{{ config(
    alias='rounds',
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
)

SELECT
    NULLIF(TRIM(b.round_num), '')::INTEGER    AS round_num,
    NULLIF(TRIM(b.start), '')::INTEGER        AS start,
    NULLIF(TRIM(b.freeze_end), '')::INTEGER   AS freeze_end,
    NULLIF(TRIM(b."end"), '')::INTEGER        AS "end",
    NULLIF(TRIM(b.official_end), '')::INTEGER AS official_end,
    NULLIF(TRIM(b.bomb_plant), '')::INTEGER   AS bomb_plant,
    NULLIF(TRIM(b.winner), '')::VARCHAR       AS winner,
    NULLIF(TRIM(b.reason), '')::VARCHAR       AS reason,
    NULLIF(TRIM(b.bomb_site), '')::VARCHAR    AS bomb_site,
    (NULLIF(TRIM(b."end"), '')::INTEGER - NULLIF(TRIM(b.start), '')::INTEGER)
        / t.taxa_de_tick                        AS duracao_segundos,
    b.match_id,
    b._arquivo_origem,
    'silver'                 AS _camada,
    b._carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'rounds') }} b
LEFT JOIN taxa t ON t.match_id = b.match_id
{% if is_incremental() %}
WHERE b.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
