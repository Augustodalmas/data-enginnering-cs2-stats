
  
    
    

    create  table
      "cs2"."gold"."bomba_jogador_partida__dbt_tmp"
  
    as (
      

SELECT
    match_id,
    steamid,
    ANY_VALUE(name) AS nome,
    COUNT(*)        AS plants,
    'gold'          AS _camada,
    NOW()           AS _gerado_em
FROM "cs2"."silver"."bomb"
WHERE event = 'plant'
  AND steamid IS NOT NULL

GROUP BY match_id, steamid
    );
  
  
  