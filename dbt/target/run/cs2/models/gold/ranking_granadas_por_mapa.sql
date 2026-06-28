
  
  create view "cs2"."gold"."ranking_granadas_por_mapa__dbt_tmp" as (
    ﻿

SELECT d.mapa, g.steamid, ANY_VALUE(g.nome) AS nome, SUM(g.granadas_lancadas) AS granadas_totais
FROM "cs2"."gold"."granadas_jogador_partida" g
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.mapa, g.steamid
ORDER BY d.mapa, granadas_totais DESC
  );
