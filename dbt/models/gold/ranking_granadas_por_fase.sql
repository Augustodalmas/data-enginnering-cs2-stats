{{ config(alias='ranking_granadas_por_fase', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT d.evento, d.fase, g.steamid, ANY_VALUE(g.nome) AS nome, SUM(g.granadas_lancadas) AS granadas_totais
FROM {{ ref('granadas_jogador_partida') }} g
JOIN {{ ref('dim_partida') }} d USING (match_id)
GROUP BY d.evento, d.fase, g.steamid
ORDER BY d.evento, d.fase, granadas_totais DESC

