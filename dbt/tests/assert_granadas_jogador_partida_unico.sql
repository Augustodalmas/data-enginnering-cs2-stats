-- Falha se existir mais de uma linha para o mesmo (match_id, steamid, categoria_granada) em
-- gold.granadas_jogador_partida (grao declarado em meta.chave_unica no model).
SELECT match_id, steamid, categoria_granada, COUNT(*) AS qtd
FROM {{ ref('granadas_jogador_partida') }}
GROUP BY match_id, steamid, categoria_granada
HAVING COUNT(*) > 1
