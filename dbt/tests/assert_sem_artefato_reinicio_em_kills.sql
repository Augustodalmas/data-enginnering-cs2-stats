-- Falha se sobrar em silver.kills algum evento de reinício de round / pausa
-- técnica (2+ jogadores "matando a si mesmos" com weapon = 'world' no mesmo
-- tick) — deveria ter sido filtrado por completo no model silver_kills.
SELECT match_id, round_num, tick, COUNT(*) AS qtd
FROM {{ ref('silver_kills') }}
WHERE weapon = 'world' AND attacker_steamid = victim_steamid
GROUP BY match_id, round_num, tick
HAVING COUNT(*) > 1
