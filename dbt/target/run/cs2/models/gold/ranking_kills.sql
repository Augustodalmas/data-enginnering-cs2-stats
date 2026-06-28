
  
  create view "cs2"."gold"."ranking_kills__dbt_tmp" as (
    ﻿

SELECT steamid, ANY_VALUE(nome) AS nome, SUM(kills) AS kills_totais
FROM "cs2"."gold"."combate_jogador_partida"
GROUP BY steamid
ORDER BY kills_totais DESC
  );
