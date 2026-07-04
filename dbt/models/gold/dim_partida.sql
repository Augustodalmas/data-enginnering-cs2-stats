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

WITH base AS (
    SELECT
        match_id,
        split_part(match_id, '/', 1) AS evento,
        split_part(match_id, '/', 2) AS fase,
        map_name                     AS mapa,
        split_part(match_id, '/', 3) AS confronto_arquivo,
        replace(map_name, 'de_', '') AS mapa_slug
    FROM {{ ref('silver_header') }}
),

extraido AS (
    SELECT
        *,
        NULLIF(regexp_extract(confronto_arquivo, '^(.*)-m[0-9]+-.*$', 1), '') AS times_prefixo,
        NULLIF(regexp_extract(confronto_arquivo, '^.*-m([0-9]+)-.*$', 1), '') AS jogo_num_extraido
    FROM base
),

-- times_raw: "time1-vs-time2", sem o sufixo de mapa/jogo. Para MD3/MD5,
-- times_prefixo já vem sem o "-mN-mapa" (ver dim_jogador_partida/confronto_id
-- acima). Para MD1, o nome do arquivo não tem separador "-mN-" entre os times
-- e o mapa (ex.: "faze-vs-mibr-ancient") — remove o sufixo "-<mapa_slug>"
-- usando o mapa real (silver_header.map_name) como referência.
times AS (
    SELECT
        *,
        COALESCE(times_prefixo, regexp_replace(confronto_arquivo, '-' || mapa_slug || '$', '')) AS times_raw
    FROM extraido
)

SELECT
    match_id,
    evento,
    fase,
    mapa,
    evento || '/' || fase || '/' || COALESCE(times_prefixo, confronto_arquivo) AS confronto_id,
    CAST(COALESCE(jogo_num_extraido, '1') AS INTEGER)                          AS jogo_num,
    CASE
        WHEN times_prefixo IS NULL THEN 'MD1'
        WHEN fase = 'final'       THEN 'MD5'
        ELSE 'MD3'
    END AS formato,
    regexp_extract(times_raw, '^(.*)-vs-(.*)$', 1) AS time_1,
    regexp_extract(times_raw, '^(.*)-vs-(.*)$', 2) AS time_2
FROM times
