
  
  create view "cs2"."gold"."dim_partida__dbt_tmp" as (
    

SELECT
    match_id,
    split_part(match_id, '/', 1) AS evento,
    split_part(match_id, '/', 2) AS fase,
    map_name                     AS mapa
FROM "cs2"."silver"."header"
  );
