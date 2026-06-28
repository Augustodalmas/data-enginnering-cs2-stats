

SELECT d.evento, g.steamid, ANY_VALUE(g.nome) AS nome, SUM(g.granadas_lancadas) AS granadas_totais
FROM "cs2"."gold"."granadas_jogador_partida" g
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.evento, g.steamid
ORDER BY d.evento, granadas_totais DESC