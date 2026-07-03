{{ config(
    alias='combate_jogador_partida',
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
kills_agg AS (
    -- Exclui team-kill (attacker_side = victim_side): matar companheiro não
    -- conta como "kill" (mesmo critério usado pela HLTV). O artefato de
    -- reinício de round (attacker = victim) já nem aparece aqui — filtrado
    -- na silver_kills.
    SELECT match_id, attacker_steamid AS steamid,
           COUNT(*) AS kills,
           COUNT(*) FILTER (headshot) AS headshots
    FROM {{ ref('silver_kills') }}
    WHERE attacker_steamid IS NOT NULL
      AND attacker_side != victim_side
    GROUP BY match_id, attacker_steamid
),
team_kills_agg AS (
    -- Quantas vezes o jogador matou um companheiro de time (fogo amigo).
    SELECT match_id, attacker_steamid AS steamid, COUNT(*) AS team_kills
    FROM {{ ref('silver_kills') }}
    WHERE attacker_steamid IS NOT NULL
      AND attacker_side = victim_side
    GROUP BY match_id, attacker_steamid
),
mortes_agg AS (
    -- Morte conta mesmo quando causada por companheiro (dano real recebido)
    -- ou pela bomba (attacker_steamid nulo) — só o artefato de reinício de
    -- round (já filtrado na silver_kills) não deveria contar, e não conta.
    SELECT match_id, victim_steamid AS steamid, COUNT(*) AS mortes
    FROM {{ ref('silver_kills') }}
    GROUP BY match_id, victim_steamid
),
assist_agg AS (
    SELECT match_id, assister_steamid AS steamid, COUNT(*) AS assistencias
    FROM {{ ref('silver_kills') }}
    WHERE assister_steamid IS NOT NULL
    GROUP BY match_id, assister_steamid
),
dano_causado_agg AS (
    SELECT match_id, attacker_steamid AS steamid, SUM(dmg_health_real) AS dano_causado
    FROM {{ ref('silver_damages') }}
    WHERE attacker_steamid IS NOT NULL
    GROUP BY match_id, attacker_steamid
),
dano_recebido_agg AS (
    SELECT match_id, victim_steamid AS steamid, SUM(dmg_health_real) AS dano_recebido
    FROM {{ ref('silver_damages') }}
    GROUP BY match_id, victim_steamid
)
SELECT
    j.match_id,
    j.steamid,
    j.nome,
    COALESCE(k.kills, 0)                                              AS kills,
    COALESCE(k.headshots, 0)                                          AS headshots,
    COALESCE(k.headshots, 0)::DOUBLE / NULLIF(COALESCE(k.kills, 0), 0) AS hs_pct,
    COALESCE(m.mortes, 0)                                             AS mortes,
    COALESCE(a.assistencias, 0)                                       AS assistencias,
    COALESCE(tk.team_kills, 0)                                        AS team_kills,
    COALESCE(dc.dano_causado, 0)                                      AS dano_causado,
    COALESCE(dr.dano_recebido, 0)                                     AS dano_recebido,
    'gold'  AS _camada,
    NOW()   AS _gerado_em
FROM jogadores j
LEFT JOIN kills_agg k       USING (match_id, steamid)
LEFT JOIN mortes_agg m      USING (match_id, steamid)
LEFT JOIN assist_agg a      USING (match_id, steamid)
LEFT JOIN team_kills_agg tk USING (match_id, steamid)
LEFT JOIN dano_causado_agg dc USING (match_id, steamid)
LEFT JOIN dano_recebido_agg dr USING (match_id, steamid)
{% if is_incremental() %}
WHERE j.match_id NOT IN (SELECT DISTINCT match_id FROM {{ this }})
{% endif %}
