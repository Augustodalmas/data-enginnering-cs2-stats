{{ config(alias='ranking_granadas_por_mapa', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT d.mapa, g.steamid, ANY_VALUE(g.nome) AS nome, SUM(g.granadas_lancadas) AS granadas_totais
FROM {{ ref('granadas_jogador_partida') }} g
JOIN {{ ref('dim_partida') }} d USING (match_id)
GROUP BY d.mapa, g.steamid
ORDER BY d.mapa, granadas_totais DESC

