{{ config(
    alias='cvars',
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
    NULLIF(TRIM(tick), '')::INTEGER   AS tick,
    NULLIF(TRIM(name), '')::VARCHAR   AS name,
    NULLIF(TRIM(value), '')::VARCHAR  AS value,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'cvars') }}
{% if is_incremental() %}
WHERE match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
