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

{{ taxa_de_tick_por_partida() }}
