
  
    
    

    create  table
      "cs2"."silver"."ticks__dbt_tmp"
  
    as (
      

SELECT
    NULLIF(TRIM(tick), '')::INTEGER      AS tick,
    NULLIF(TRIM(round_num), '')::INTEGER AS round_num,
    NULLIF(TRIM(health), '')::INTEGER    AS health,
    NULLIF(TRIM(steamid), '')::BIGINT    AS steamid,
    NULLIF(TRIM(name), '')::VARCHAR      AS name,
    NULLIF(TRIM(side), '')::VARCHAR      AS side,
    NULLIF(TRIM(place), '')::VARCHAR     AS place,
    NULLIF(TRIM(X), '')::DOUBLE          AS X,
    NULLIF(TRIM(Y), '')::DOUBLE          AS Y,
    NULLIF(TRIM(Z), '')::DOUBLE          AS Z,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM "cs2"."bronze"."ticks"

    );
  
  
  