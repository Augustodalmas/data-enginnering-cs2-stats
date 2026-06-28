
  
    
    

    create  table
      "cs2"."silver"."rounds__dbt_tmp"
  
    as (
      

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
FROM "cs2"."bronze"."rounds"

    );
  
  
  