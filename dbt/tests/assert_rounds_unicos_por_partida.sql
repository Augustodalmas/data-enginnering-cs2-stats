-- Falha se existir mais de uma linha para o mesmo (match_id, round_num) em silver.rounds.
SELECT match_id, round_num, COUNT(*) AS qtd
FROM {{ ref('silver_rounds') }}
GROUP BY match_id, round_num
HAVING COUNT(*) > 1
