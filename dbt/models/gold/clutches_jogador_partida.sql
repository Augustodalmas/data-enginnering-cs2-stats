{{ config(
    alias='clutches_jogador_partida',
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

WITH jogadores AS (
    SELECT match_id, steamid, ANY_VALUE(name) AS nome
    FROM {{ ref('silver_ticks') }}
    GROUP BY match_id, steamid
),
roster AS (
    -- Time (lado) e tamanho real por round, direto do roster conectado
    -- (não fixo em 5 — cobre desconexão, ex.: 4v5).
    SELECT match_id, round_num, side, COUNT(DISTINCT steamid) AS tam_time
    FROM {{ ref('silver_ticks') }}
    GROUP BY match_id, round_num, side
),
roster_nomes AS (
    SELECT match_id, round_num, side, steamid, ANY_VALUE(name) AS nome
    FROM {{ ref('silver_ticks') }}
    GROUP BY match_id, round_num, side, steamid
),
mortes_por_tick AS (
    -- Agrega por tick (não por linha de kill) — necessário pra tratar
    -- corretamente 2+ mortes simultâneas no mesmo tick (ex.: bomba
    -- explodindo com 2 jogadores no raio): se o time pula de 2 vivos pra 0
    -- no mesmo tick, ninguém "ficou sozinho" — o saldo acumulado nunca passa
    -- por 1, e o round/lado corretamente não gera situação de clutch.
    SELECT match_id, round_num, victim_side AS side, tick, COUNT(*) AS mortes_no_tick
    FROM {{ ref('silver_kills') }}
    GROUP BY match_id, round_num, victim_side, tick
),
vivos_acumulado AS (
    SELECT m.match_id, m.round_num, m.side, m.tick,
           r.tam_time - SUM(m.mortes_no_tick) OVER (
               PARTITION BY m.match_id, m.round_num, m.side
               ORDER BY m.tick
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS vivos
    FROM mortes_por_tick m
    JOIN roster r USING (match_id, round_num, side)
),
momento_lone AS (
    -- Primeiro tick em que sobrou exatamente 1 vivo do lado (requer
    -- tam_time >= 2 implicitamente — só existe transição pra "1" se havia
    -- mais de 1 antes).
    SELECT match_id, round_num, side, MIN(tick) AS tick_lone
    FROM vivos_acumulado
    WHERE vivos = 1
    GROUP BY match_id, round_num, side
),
sobrevivente AS (
    -- Jogador do roster daquele lado que ainda não tinha morrido até
    -- (e incluindo) o tick_lone — é, por construção, exatamente 1 por
    -- (match_id, round_num, side).
    SELECT ml.match_id, ml.round_num, ml.side, ml.tick_lone, rn.steamid, rn.nome
    FROM momento_lone ml
    JOIN roster_nomes rn
        ON rn.match_id = ml.match_id AND rn.round_num = ml.round_num AND rn.side = ml.side
    LEFT JOIN {{ ref('silver_kills') }} k
        ON k.match_id = ml.match_id AND k.round_num = ml.round_num
       AND k.victim_side = ml.side AND k.victim_steamid = rn.steamid
       AND k.tick <= ml.tick_lone
    WHERE k.victim_steamid IS NULL
),
clutch_situacoes AS (
    SELECT
        s.match_id, s.round_num, s.side, s.steamid, s.nome,
        ro_op.tam_time - (
            SELECT COALESCE(SUM(mt2.mortes_no_tick), 0)
            FROM mortes_por_tick mt2
            WHERE mt2.match_id = s.match_id AND mt2.round_num = s.round_num
              AND mt2.side = CASE WHEN s.side = 'ct' THEN 't' ELSE 'ct' END
              AND mt2.tick <= s.tick_lone
        ) AS inimigos_vivos
    FROM sobrevivente s
    JOIN roster ro_op
        ON ro_op.match_id = s.match_id AND ro_op.round_num = s.round_num
       AND ro_op.side = CASE WHEN s.side = 'ct' THEN 't' ELSE 'ct' END
),
clutches AS (
    -- Só é uma situação de clutch de verdade se ainda havia inimigo vivo
    -- (senão o round já tinha sido decidido por eliminação total antes).
    -- Resultado (vencido/perdido) vem de rounds.winner, independente de
    -- como o round terminou (kill decisivo, defuse, bomba explodindo,
    -- tempo) — decisão registrada em CLAUDE.md.
    SELECT cs.match_id, cs.steamid, cs.nome, cs.inimigos_vivos,
           (cs.side = r.winner) AS venceu
    FROM clutch_situacoes cs
    JOIN {{ ref('silver_rounds') }} r
        ON r.match_id = cs.match_id AND r.round_num = cs.round_num
    WHERE cs.inimigos_vivos >= 1
),
clutches_agg AS (
    SELECT
        match_id,
        steamid,
        COUNT(*)                                              AS clutches_tentados,
        COUNT(*) FILTER (venceu)                              AS clutches_vencidos,
        COUNT(*) FILTER (venceu AND inimigos_vivos = 1)        AS clutches_1v1_vencidos,
        COUNT(*) FILTER (venceu AND inimigos_vivos = 2)        AS clutches_1v2_vencidos,
        COUNT(*) FILTER (venceu AND inimigos_vivos = 3)        AS clutches_1v3_vencidos,
        COUNT(*) FILTER (venceu AND inimigos_vivos = 4)        AS clutches_1v4_vencidos,
        COUNT(*) FILTER (venceu AND inimigos_vivos = 5)        AS clutches_1v5_vencidos
    FROM clutches
    GROUP BY match_id, steamid
)
SELECT
    j.match_id,
    j.steamid,
    j.nome,
    COALESCE(c.clutches_tentados, 0)     AS clutches_tentados,
    COALESCE(c.clutches_vencidos, 0)     AS clutches_vencidos,
    COALESCE(c.clutches_1v1_vencidos, 0) AS clutches_1v1_vencidos,
    COALESCE(c.clutches_1v2_vencidos, 0) AS clutches_1v2_vencidos,
    COALESCE(c.clutches_1v3_vencidos, 0) AS clutches_1v3_vencidos,
    COALESCE(c.clutches_1v4_vencidos, 0) AS clutches_1v4_vencidos,
    COALESCE(c.clutches_1v5_vencidos, 0) AS clutches_1v5_vencidos,
    'gold' AS _camada,
    NOW()  AS _gerado_em
FROM jogadores j
LEFT JOIN clutches_agg c USING (match_id, steamid)
{% if is_incremental() %}
WHERE j.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
