

SELECT steamid, ANY_VALUE(nome) AS nome, SUM(granadas_lancadas) AS granadas_totais
FROM "cs2"."gold"."granadas_jogador_partida"
GROUP BY steamid
ORDER BY granadas_totais DESC