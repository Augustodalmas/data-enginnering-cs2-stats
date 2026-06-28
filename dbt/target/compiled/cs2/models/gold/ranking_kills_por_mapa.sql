

SELECT d.mapa, c.steamid, ANY_VALUE(c.nome) AS nome, SUM(c.kills) AS kills_totais
FROM "cs2"."gold"."combate_jogador_partida" c
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.mapa, c.steamid
ORDER BY d.mapa, kills_totais DESC