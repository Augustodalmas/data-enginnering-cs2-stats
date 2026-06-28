
  
  create view "cs2"."gold"."ranking_tempo_por_local_por_mapa__dbt_tmp" as (
    ﻿

SELECT d.mapa, p.steamid, ANY_VALUE(p.nome) AS nome, p.place, SUM(p.segundos_no_local) AS segundos_totais
FROM "cs2"."gold"."posicionamento_jogador_partida" p
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.mapa, p.steamid, p.place
ORDER BY d.mapa, segundos_totais DESC
  );
