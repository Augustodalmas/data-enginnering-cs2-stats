{{ config(
    alias='damages',
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
    NULLIF(TRIM(b.attacker_name), '')::VARCHAR    AS attacker_name,
    NULLIF(TRIM(b.attacker_steamid), '')::BIGINT  AS attacker_steamid,
    NULLIF(TRIM(b.attacker_side), '')::VARCHAR    AS attacker_side,
    NULLIF(TRIM(b.attacker_X), '')::DOUBLE        AS attacker_X,
    NULLIF(TRIM(b.attacker_Y), '')::DOUBLE        AS attacker_Y,
    NULLIF(TRIM(b.attacker_Z), '')::DOUBLE        AS attacker_Z,
    NULLIF(TRIM(b.attacker_health), '')::INTEGER  AS attacker_health,
    NULLIF(TRIM(b.attacker_place), '')::VARCHAR   AS attacker_place,
    NULLIF(TRIM(b.victim_name), '')::VARCHAR      AS victim_name,
    NULLIF(TRIM(b.victim_steamid), '')::BIGINT    AS victim_steamid,
    NULLIF(TRIM(b.victim_side), '')::VARCHAR      AS victim_side,
    NULLIF(TRIM(b.victim_X), '')::DOUBLE          AS victim_X,
    NULLIF(TRIM(b.victim_Y), '')::DOUBLE          AS victim_Y,
    NULLIF(TRIM(b.victim_Z), '')::DOUBLE          AS victim_Z,
    NULLIF(TRIM(b.victim_health), '')::INTEGER    AS victim_health,
    NULLIF(TRIM(b.victim_place), '')::VARCHAR     AS victim_place,
    NULLIF(TRIM(b.tick), '')::INTEGER             AS tick,
    NULLIF(TRIM(b.round_num), '')::INTEGER        AS round_num,
    (NULLIF(TRIM(b.tick), '')::INTEGER - ir.round_start_tick)
        / t.taxa_de_tick                            AS segundos_desde_inicio_round,
    NULLIF(TRIM(b.armor), '')::INTEGER            AS armor,
    NULLIF(TRIM(b.health), '')::INTEGER           AS health,
    NULLIF(TRIM(b.dmg_armor), '')::INTEGER        AS dmg_armor,
    NULLIF(TRIM(b.dmg_health), '')::INTEGER       AS dmg_health,
    NULLIF(TRIM(b.dmg_health_real), '')::INTEGER  AS dmg_health_real,
    NULLIF(TRIM(b.weapon), '')::VARCHAR           AS weapon,
    NULLIF(TRIM(b.hitgroup), '')::VARCHAR         AS hitgroup,
    NULLIF(TRIM(b.ct_side), '')::VARCHAR          AS ct_side,
    NULLIF(TRIM(b.t_side), '')::VARCHAR           AS t_side,
    b.match_id,
    b._arquivo_origem,
    'silver'                 AS _camada,
    b._carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'damages') }} b
LEFT JOIN inicio_round ir ON ir.match_id = b.match_id
    AND ir.round_num = NULLIF(TRIM(b.round_num), '')::INTEGER
LEFT JOIN taxa t ON t.match_id = b.match_id
{% if is_incremental() %}
WHERE b.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
