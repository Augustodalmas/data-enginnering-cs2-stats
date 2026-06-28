{{ config(alias='ranking_granadas', materialized='view', tags=['gold', 'ranking'], meta={'camada': 'gold', 'owner': 'augustodalmas'}) }}

SELECT steamid, ANY_VALUE(nome) AS nome, SUM(granadas_lancadas) AS granadas_totais
FROM {{ ref('granadas_jogador_partida') }}
GROUP BY steamid
ORDER BY granadas_totais DESC

