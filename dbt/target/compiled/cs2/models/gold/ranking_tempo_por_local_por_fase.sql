

SELECT d.evento, d.fase, p.steamid, ANY_VALUE(p.nome) AS nome, p.place, SUM(p.segundos_no_local) AS segundos_totais
FROM "cs2"."gold"."posicionamento_jogador_partida" p
JOIN "cs2"."gold"."dim_partida" d USING (match_id)
GROUP BY d.evento, d.fase, p.steamid, p.place
ORDER BY d.evento, d.fase, segundos_totais DESC