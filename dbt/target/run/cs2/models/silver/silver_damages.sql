
  
    
    

    create  table
      "cs2"."silver"."damages__dbt_tmp"
  
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
    NULLIF(TRIM(tick), '')::INTEGER             AS tick,
    NULLIF(TRIM(round_num), '')::INTEGER        AS round_num,
    NULLIF(TRIM(armor), '')::INTEGER            AS armor,
    NULLIF(TRIM(health), '')::INTEGER           AS health,
    NULLIF(TRIM(dmg_armor), '')::INTEGER        AS dmg_armor,
    NULLIF(TRIM(dmg_health), '')::INTEGER       AS dmg_health,
    NULLIF(TRIM(dmg_health_real), '')::INTEGER  AS dmg_health_real,
    NULLIF(TRIM(weapon), '')::VARCHAR           AS weapon,
    NULLIF(TRIM(hitgroup), '')::VARCHAR         AS hitgroup,
    NULLIF(TRIM(ct_side), '')::VARCHAR          AS ct_side,
    NULLIF(TRIM(t_side), '')::VARCHAR           AS t_side,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM "cs2"."bronze"."damages"

    );
  
  
  