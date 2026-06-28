{{ config(alias='ranking_tempo_por_local', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT steamid, ANY_VALUE(nome) AS nome, place, SUM(segundos_no_local) AS segundos_totais
FROM {{ ref('posicionamento_jogador_partida') }}
GROUP BY steamid, place
ORDER BY segundos_totais DESC

