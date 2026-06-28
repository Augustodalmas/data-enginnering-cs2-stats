{{ config(
    alias='dim_partida',
    materialized='view',
    tags=['gold', 'dim'],
    meta={
        'camada': 'gold',
        'grao': 'partida',
        'chave_unica': ['match_id'],
        'owner': 'augustodalmas',
    }
) }}

SELECT
    match_id,
    split_part(match_id, '/', 1) AS evento,
    split_part(match_id, '/', 2) AS fase,
    map_name                     AS mapa
FROM {{ ref('silver_header') }}
