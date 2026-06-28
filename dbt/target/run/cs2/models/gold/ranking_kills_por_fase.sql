
  
  create view "cs2"."gold"."ranking_kills_por_fase__dbt_tmp" as (
    ﻿

SELECT d.evento, d.fase, c.steamid, ANY_VALUE(c.nome) AS nome, SUM(c.kills) AS kills_totais
FROM "cs2"."gold"."combate_jogador_partida" c
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.evento, d.fase, c.steamid
ORDER BY d.evento, d.fase, kills_totais DESC
  );
