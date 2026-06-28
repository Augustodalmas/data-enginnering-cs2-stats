
  
  create view "cs2"."gold"."ranking_tempo_por_local_por_evento__dbt_tmp" as (
    ﻿

SELECT d.evento, p.steamid, ANY_VALUE(p.nome) AS nome, p.place, SUM(p.segundos_no_local) AS segundos_totais
FROM "cs2"."gold"."posicionamento_jogador_partida" p
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.evento, p.steamid, p.place
ORDER BY d.evento, segundos_totais DESC
  );
