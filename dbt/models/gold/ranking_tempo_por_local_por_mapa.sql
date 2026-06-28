{{ config(alias='ranking_tempo_por_local_por_mapa', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT d.mapa, p.steamid, ANY_VALUE(p.nome) AS nome, p.place, SUM(p.segundos_no_local) AS segundos_totais
FROM {{ ref('posicionamento_jogador_partida') }} p
JOIN {{ ref('dim_partida') }} d USING (match_id)
GROUP BY d.mapa, p.steamid, p.place
ORDER BY d.mapa, segundos_totais DESC

