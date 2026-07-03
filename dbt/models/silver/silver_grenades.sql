{{ config(
    alias='grenades',
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
    NULLIF(TRIM(entity_id), '')::BIGINT        AS entity_id,
    NULLIF(TRIM(thrower_steamid), '')::BIGINT  AS thrower_steamid,
    NULLIF(TRIM(thrower), '')::VARCHAR         AS thrower,
    NULLIF(TRIM(grenade_type), '')::VARCHAR    AS grenade_type,
    NULLIF(TRIM(tick), '')::INTEGER            AS tick,
    NULLIF(TRIM(round_num), '')::INTEGER       AS round_num,
    NULLIF(TRIM(X), '')::DOUBLE                AS X,
    NULLIF(TRIM(Y), '')::DOUBLE                AS Y,
    NULLIF(TRIM(Z), '')::DOUBLE                AS Z,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'grenades') }}
-- Exclui entidades que não são granadas (CKnife, CWeaponGlock): artefato de
-- parsing do awpy observado numa demo/round específico, não granada real.
WHERE NULLIF(TRIM(grenade_type), '') NOT IN ('CKnife', 'CWeaponGlock')
{% if is_incremental() %}
AND match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
