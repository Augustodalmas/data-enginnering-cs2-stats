{{ config(
    alias='bomba_jogador_partida',
    materialized='incremental',
    unique_key=['match_id', 'steamid'],
    on_schema_change='append_new_columns',
    tags=['gold', 'fact'],
    meta={
        'camada': 'gold',
        'grao': 'jogador × partida',
        'chave_unica': ['match_id', 'steamid'],
        'particao': 'match_id',
        'owner': 'augustodalmas',
    }
) }}

SELECT
    match_id,
    steamid,
    ANY_VALUE(name) AS nome,
    COUNT(*)        AS plants,
    'gold'          AS _camada,
    NOW()           AS _gerado_em
FROM {{ ref('silver_bomb') }}
WHERE event = 'plant'
  AND steamid IS NOT NULL
{% if is_incremental() %}
  AND match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
GROUP BY match_id, steamid
