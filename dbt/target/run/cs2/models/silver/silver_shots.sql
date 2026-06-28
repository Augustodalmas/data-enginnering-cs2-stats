
  
    
    

    create  table
      "cs2"."silver"."shots__dbt_tmp"
  
    as (
      

SELECT
    NULLIF(TRIM(player_name), '')::VARCHAR    AS player_name,
    NULLIF(TRIM(player_steamid), '')::BIGINT  AS player_steamid,
    NULLIF(TRIM(player_side), '')::VARCHAR    AS player_side,
    NULLIF(TRIM(player_X), '')::DOUBLE        AS player_X,
    NULLIF(TRIM(player_Y), '')::DOUBLE        AS player_Y,
    NULLIF(TRIM(player_Z), '')::DOUBLE        AS player_Z,
    NULLIF(TRIM(player_health), '')::INTEGER  AS player_health,
    NULLIF(TRIM(player_place), '')::VARCHAR   AS player_place,
    NULLIF(TRIM(tick), '')::INTEGER           AS tick,
    NULLIF(TRIM(round_num), '')::INTEGER      AS round_num,
    NULLIF(TRIM(weapon), '')::VARCHAR         AS weapon,
    NULLIF(TRIM(ct_side), '')::VARCHAR        AS ct_side,
    NULLIF(TRIM(t_side), '')::VARCHAR         AS t_side,
    LOWER(NULLIF(TRIM(silenced), ''))::BOOLEAN AS silenced,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM "cs2"."bronze"."shots"

    );
  
  
  