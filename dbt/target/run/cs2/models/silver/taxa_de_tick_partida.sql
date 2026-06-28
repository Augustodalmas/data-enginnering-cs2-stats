
  
  create view "cs2"."silver"."taxa_de_tick_partida__dbt_tmp" as (
    

SELECT
    pr.match_id,
    pr.ticks_de_freeze / ft.freezetime_segundos AS taxa_de_tick
FROM (
    SELECT match_id, MODE(freeze_end - start) AS ticks_de_freeze
    FROM "cs2"."silver"."rounds"
    GROUP BY match_id
) pr
JOIN (
    SELECT match_id, ANY_VALUE(value)::DOUBLE AS freezetime_segundos
    FROM "cs2"."silver"."cvars"
    WHERE name = 'mp_freezetime'
    GROUP BY match_id
) ft USING (match_id)
  );
