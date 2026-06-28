{{ config(
    alias='posicionamento_jogador_partida',
    materialized='incremental',
    unique_key=['match_id', 'steamid', 'place'],
    on_schema_change='append_new_columns',
    tags=['gold', 'fact'],
    meta={
        'camada': 'gold',
        'grao': 'jogador × partida × área do mapa',
        'chave_unica': ['match_id', 'steamid', 'place'],
        'particao': 'match_id',
        'owner': 'augustodalmas',
    }
) }}

SELECT
    t.match_id,
    t.steamid,
    ANY_VALUE(t.name)          AS nome,
    t.place,
    COUNT(*)                   AS qtd_ticks,
    COUNT(*) / r.taxa_de_tick  AS segundos_no_local,
    'gold'                     AS _camada,
    NOW()                      AS _gerado_em
FROM {{ ref('silver_ticks') }} t
JOIN {{ ref('taxa_de_tick_partida') }} r USING (match_id)
{% if is_incremental() %}
WHERE t.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
GROUP BY t.match_id, t.steamid, t.place, r.taxa_de_tick
