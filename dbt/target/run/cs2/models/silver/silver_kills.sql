
  
    
    

    create  table
      "cs2"."silver"."kills__dbt_tmp"
  
    as (
      

SELECT
    NULLIF(TRIM(attacker_name), '')::VARCHAR    AS attacker_name,
    NULLIF(TRIM(attacker_steamid), '')::BIGINT  AS attacker_steamid,
    NULLIF(TRIM(attacker_side), '')::VARCHAR    AS attacker_side,
    NULLIF(TRIM(attacker_X), '')::DOUBLE        AS attacker_X,
    NULLIF(TRIM(attacker_Y), '')::DOUBLE        AS attacker_Y,
    NULLIF(TRIM(attacker_Z), '')::DOUBLE        AS attacker_Z,
    NULLIF(TRIM(attacker_health), '')::INTEGER  AS attacker_health,
    NULLIF(TRIM(attacker_place), '')::VARCHAR   AS attacker_place,
    NULLIF(TRIM(victim_name), '')::VARCHAR      AS victim_name,
    NULLIF(TRIM(victim_steamid), '')::BIGINT    AS victim_steamid,
    NULLIF(TRIM(victim_side), '')::VARCHAR      AS victim_side,
    NULLIF(TRIM(victim_X), '')::DOUBLE          AS victim_X,
    NULLIF(TRIM(victim_Y), '')::DOUBLE          AS victim_Y,
    NULLIF(TRIM(victim_Z), '')::DOUBLE          AS victim_Z,
    NULLIF(TRIM(victim_health), '')::INTEGER    AS victim_health,
    NULLIF(TRIM(victim_place), '')::VARCHAR     AS victim_place,
    NULLIF(TRIM(assister_name), '')::VARCHAR    AS assister_name,
    NULLIF(TRIM(assister_steamid), '')::BIGINT  AS assister_steamid,
    NULLIF(TRIM(assister_side), '')::VARCHAR    AS assister_side,
    NULLIF(TRIM(assister_X), '')::DOUBLE        AS assister_X,
    NULLIF(TRIM(assister_Y), '')::DOUBLE        AS assister_Y,
    NULLIF(TRIM(assister_Z), '')::DOUBLE        AS assister_Z,
    NULLIF(TRIM(assister_health), '')::INTEGER  AS assister_health,
    NULLIF(TRIM(assister_place), '')::VARCHAR   AS assister_place,
    NULLIF(TRIM(tick), '')::INTEGER                              AS tick,
    NULLIF(TRIM(round_num), '')::INTEGER                         AS round_num,
    LOWER(NULLIF(TRIM(assistedflash), ''))::BOOLEAN              AS assistedflash,
    LOWER(NULLIF(TRIM(headshot), ''))::BOOLEAN                   AS headshot,
    LOWER(NULLIF(TRIM(noscope), ''))::BOOLEAN                    AS noscope,
    LOWER(NULLIF(TRIM(thrusmoke), ''))::BOOLEAN                  AS thrusmoke,
    LOWER(NULLIF(TRIM(attackerblind), ''))::BOOLEAN              AS attackerblind,
    LOWER(NULLIF(TRIM(attackerinair), ''))::BOOLEAN              AS attackerinair,
    LOWER(NULLIF(TRIM(noreplay), ''))::BOOLEAN                   AS noreplay,
    LOWER(NULLIF(TRIM(dominated), ''))::BOOLEAN                  AS dominated,
    LOWER(NULLIF(TRIM(revenge), ''))::BOOLEAN                    AS revenge,
    NULLIF(TRIM(weapon), '')::VARCHAR                            AS weapon,
    NULLIF(TRIM(hitgroup), '')::VARCHAR                          AS hitgroup,
    NULLIF(TRIM(ct_side), '')::VARCHAR                           AS ct_side,
    NULLIF(TRIM(t_side), '')::VARCHAR                            AS t_side,
    NULLIF(TRIM(weapon_itemid), '')::UBIGINT                     AS weapon_itemid,
    NULLIF(TRIM(weapon_fauxitemid), '')::UBIGINT                 AS weapon_fauxitemid,
    NULLIF(TRIM(weapon_originalowner_xuid), '')::UBIGINT         AS weapon_originalowner_xuid,
    NULLIF(TRIM(distance), '')::DOUBLE                           AS distance,
    NULLIF(TRIM(dmg_armor), '')::INTEGER                         AS dmg_armor,
    NULLIF(TRIM(dmg_health), '')::INTEGER                        AS dmg_health,
    NULLIF(TRIM(penetrated), '')::INTEGER                        AS penetrated,
    NULLIF(TRIM(wipe), '')::INTEGER                              AS wipe,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM "cs2"."bronze"."kills"

    );
  
  
  