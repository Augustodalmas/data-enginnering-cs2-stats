-- Falha se existir mais de uma linha para o mesmo (match_id, steamid) em
-- gold.dim_jogador_partida (grao declarado em meta.chave_unica no model).
SELECT match_id, steamid, COUNT(*) AS qtd
FROM {{ ref('dim_jogador_partida') }}
GROUP BY match_id, steamid
HAVING COUNT(*) > 1
