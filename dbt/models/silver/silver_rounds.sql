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

SELECT
    NULLIF(TRIM(round_num), '')::INTEGER    AS round_num,
    NULLIF(TRIM(start), '')::INTEGER        AS start,
    NULLIF(TRIM(freeze_end), '')::INTEGER   AS freeze_end,
    NULLIF(TRIM("end"), '')::INTEGER        AS "end",
    NULLIF(TRIM(official_end), '')::INTEGER AS official_end,
    NULLIF(TRIM(bomb_plant), '')::INTEGER   AS bomb_plant,
    NULLIF(TRIM(winner), '')::VARCHAR       AS winner,
    NULLIF(TRIM(reason), '')::VARCHAR       AS reason,
    NULLIF(TRIM(bomb_site), '')::VARCHAR    AS bomb_site,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'rounds') }}
{% if is_incremental() %}
WHERE match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
