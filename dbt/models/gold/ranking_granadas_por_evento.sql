{{ config(alias='ranking_granadas_por_evento', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT d.evento, g.steamid, ANY_VALUE(g.nome) AS nome, SUM(g.granadas_lancadas) AS granadas_totais
FROM {{ ref('granadas_jogador_partida') }} g
JOIN {{ ref('dim_partida') }} d USING (match_id)
GROUP BY d.evento, g.steamid
ORDER BY d.evento, granadas_totais DESC

