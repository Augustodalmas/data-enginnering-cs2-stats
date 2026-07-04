{{ config(
    alias='dim_jogador_partida',
    materialized='incremental',
    unique_key=['match_id', 'steamid'],
    on_schema_change='append_new_columns',
    tags=['gold', 'dim'],
    meta={
        'camada': 'gold',
        'grao': 'jogador × partida',
        'chave_unica': ['match_id', 'steamid'],
        'particao': 'match_id',
        'owner': 'augustodalmas',
    }
) }}

-- O awpy não expõe o nome real do time em nenhuma tabela (ct_side/t_side
-- vêm sempre fixos como "ct"/"t", ver docs/dicionario_dados.md). O roster de
-- cada time é fixo durante a partida inteira — só o lado (CT/T) troca no
-- intervalo — então o lado do jogador na primeira rodada em que ele aparece
-- já identifica o time dele em relação ao outro. 'equipe' é um rótulo
-- genérico (team_a/team_b, não o nome real do time), estável dentro de uma
-- mesma partida: team_a = quem começou do lado CT, team_b = quem começou T.
WITH primeira_rodada AS (
    SELECT
        match_id,
        steamid,
        ANY_VALUE(name) AS nome,
        MIN(round_num)  AS primeiro_round
    FROM {{ ref('silver_ticks') }}
    GROUP BY match_id, steamid
),
lado_inicial AS (
    SELECT
        p.match_id,
        p.steamid,
        p.nome,
        ANY_VALUE(t.side) AS lado_inicial
    FROM primeira_rodada p
    JOIN {{ ref('silver_ticks') }} t
        ON  t.match_id  = p.match_id
        AND t.steamid   = p.steamid
        AND t.round_num = p.primeiro_round
    GROUP BY p.match_id, p.steamid, p.nome
)
SELECT
    match_id,
    steamid,
    nome,
    CASE WHEN lado_inicial = 'ct' THEN 'team_a' ELSE 'team_b' END AS equipe,
    'gold'  AS _camada,
    NOW()   AS _gerado_em
FROM lado_inicial
{% if is_incremental() %}
WHERE match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
