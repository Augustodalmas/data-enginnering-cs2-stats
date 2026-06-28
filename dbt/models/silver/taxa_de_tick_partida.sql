{{ config(
    alias='taxa_de_tick_partida',
    materialized='view',
    tags=['silver'],
    meta={
        'camada': 'silver',
        'owner': 'augustodalmas',
        'descricao': 'Taxa de tick real (ticks/segundo) por partida, calculada via mp_freezetime',
    }
) }}

SELECT
    pr.match_id,
    pr.ticks_de_freeze / ft.freezetime_segundos AS taxa_de_tick
FROM (
    SELECT match_id, MODE(freeze_end - start) AS ticks_de_freeze
    FROM {{ ref('silver_rounds') }}
    GROUP BY match_id
) pr
JOIN (
    SELECT match_id, ANY_VALUE(value)::DOUBLE AS freezetime_segundos
    FROM {{ ref('silver_cvars') }}
    WHERE name = 'mp_freezetime'
    GROUP BY match_id
) ft USING (match_id)
