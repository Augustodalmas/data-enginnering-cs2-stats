{{ config(
    alias='kills',
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
),
-- Ticks onde 2+ jogadores "matam a si mesmos" (attacker_steamid = victim_steamid)
-- com weapon = 'world' no mesmo instante: assinatura de reinício de round /
-- pausa técnica administrada pelo servidor (comum em campeonatos), não morte
-- de jogo real — nunca aconteceu 2 jogadores diferentes com esse padrão no
-- mesmo tick exato por coincidência. Excluído da silver por completo (mesmo
-- tratamento de CKnife/CWeaponGlock em silver_grenades: artefato, não dado
-- de jogo).
ticks_de_reinicio AS (
    SELECT match_id, NULLIF(TRIM(round_num), '')::INTEGER AS round_num, NULLIF(TRIM(tick), '')::INTEGER AS tick
    FROM {{ source('bronze', 'kills') }}
    WHERE NULLIF(TRIM(weapon), '') = 'world'
      AND NULLIF(TRIM(attacker_steamid), '') = NULLIF(TRIM(victim_steamid), '')
    GROUP BY match_id, NULLIF(TRIM(round_num), '')::INTEGER, NULLIF(TRIM(tick), '')::INTEGER
    HAVING COUNT(*) > 1
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
    NULLIF(TRIM(b.assister_name), '')::VARCHAR    AS assister_name,
    NULLIF(TRIM(b.assister_steamid), '')::BIGINT  AS assister_steamid,
    NULLIF(TRIM(b.assister_side), '')::VARCHAR    AS assister_side,
    NULLIF(TRIM(b.assister_X), '')::DOUBLE        AS assister_X,
    NULLIF(TRIM(b.assister_Y), '')::DOUBLE        AS assister_Y,
    NULLIF(TRIM(b.assister_Z), '')::DOUBLE        AS assister_Z,
    NULLIF(TRIM(b.assister_health), '')::INTEGER  AS assister_health,
    NULLIF(TRIM(b.assister_place), '')::VARCHAR   AS assister_place,
    NULLIF(TRIM(b.tick), '')::INTEGER                              AS tick,
    NULLIF(TRIM(b.round_num), '')::INTEGER                         AS round_num,
    (NULLIF(TRIM(b.tick), '')::INTEGER - ir.round_start_tick)
        / t.taxa_de_tick                                             AS segundos_desde_inicio_round,
    LOWER(NULLIF(TRIM(b.assistedflash), ''))::BOOLEAN              AS assistedflash,
    NULLIF(TRIM(b.weapon), '')::VARCHAR                             AS weapon,
    NULLIF(TRIM(b.weapon_itemid), '')::BIGINT                       AS weapon_itemid,
    NULLIF(TRIM(b.weapon_fauxitemid), '')::UBIGINT                  AS weapon_fauxitemid,
    NULLIF(TRIM(b.weapon_originalowner_xuid), '')::BIGINT           AS weapon_originalowner_xuid,
    LOWER(NULLIF(TRIM(b.headshot), ''))::BOOLEAN                    AS headshot,
    NULLIF(TRIM(b.hitgroup), '')::VARCHAR                           AS hitgroup,
    NULLIF(TRIM(b.distance), '')::DOUBLE                            AS distance,
    NULLIF(TRIM(b.dmg_armor), '')::INTEGER                          AS dmg_armor,
    NULLIF(TRIM(b.dmg_health), '')::INTEGER                         AS dmg_health,
    NULLIF(TRIM(b.penetrated), '')::INTEGER                         AS penetrated,
    LOWER(NULLIF(TRIM(b.noscope), ''))::BOOLEAN                     AS noscope,
    LOWER(NULLIF(TRIM(b.thrusmoke), ''))::BOOLEAN                   AS thrusmoke,
    LOWER(NULLIF(TRIM(b.attackerblind), ''))::BOOLEAN               AS attackerblind,
    LOWER(NULLIF(TRIM(b.attackerinair), ''))::BOOLEAN               AS attackerinair,
    LOWER(NULLIF(TRIM(b.noreplay), ''))::BOOLEAN                    AS noreplay,
    LOWER(NULLIF(TRIM(b.dominated), ''))::BOOLEAN                   AS dominated,
    LOWER(NULLIF(TRIM(b.revenge), ''))::BOOLEAN                     AS revenge,
    NULLIF(TRIM(b.wipe), '')::INTEGER                               AS wipe,
    NULLIF(TRIM(b.ct_side), '')::VARCHAR                            AS ct_side,
    NULLIF(TRIM(b.t_side), '')::VARCHAR                             AS t_side,
    b.match_id,
    b._arquivo_origem,
    'silver'                 AS _camada,
    b._carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM {{ source('bronze', 'kills') }} b
LEFT JOIN inicio_round ir ON ir.match_id = b.match_id
    AND ir.round_num = NULLIF(TRIM(b.round_num), '')::INTEGER
LEFT JOIN taxa t ON t.match_id = b.match_id
LEFT JOIN ticks_de_reinicio tr ON tr.match_id = b.match_id
    AND tr.round_num = NULLIF(TRIM(b.round_num), '')::INTEGER
    AND tr.tick = NULLIF(TRIM(b.tick), '')::INTEGER
WHERE tr.match_id IS NULL
{% if is_incremental() %}
AND b.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
