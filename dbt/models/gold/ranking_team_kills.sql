{{ config(alias='ranking_team_kills', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT steamid, ANY_VALUE(nome) AS nome, SUM(team_kills) AS team_kills_totais
FROM {{ ref('combate_jogador_partida') }}
GROUP BY steamid
HAVING SUM(team_kills) > 0
ORDER BY team_kills_totais DESC
