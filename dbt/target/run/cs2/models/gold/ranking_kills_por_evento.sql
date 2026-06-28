
  
  create view "cs2"."gold"."ranking_kills_por_evento__dbt_tmp" as (
    ﻿

SELECT d.evento, c.steamid, ANY_VALUE(c.nome) AS nome, SUM(c.kills) AS kills_totais
FROM "cs2"."gold"."combate_jogador_partida" c
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.evento, c.steamid
ORDER BY d.evento, kills_totais DESC
  );
