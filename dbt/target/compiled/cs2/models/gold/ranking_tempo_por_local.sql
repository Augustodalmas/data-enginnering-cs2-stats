

SELECT steamid, ANY_VALUE(nome) AS nome, place, SUM(segundos_no_local) AS segundos_totais
FROM "cs2"."gold"."posicionamento_jogador_partida"
GROUP BY steamid, place
ORDER BY segundos_totais DESC