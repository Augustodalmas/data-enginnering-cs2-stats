{{ config(alias='ranking_kills_por_mapa', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT d.mapa, c.steamid, ANY_VALUE(c.nome) AS nome, SUM(c.kills) AS kills_totais
FROM {{ ref('combate_jogador_partida') }} c
JOIN {{ ref('dim_partida') }} d USING (match_id)
GROUP BY d.mapa, c.steamid
ORDER BY d.mapa, kills_totais DESC

