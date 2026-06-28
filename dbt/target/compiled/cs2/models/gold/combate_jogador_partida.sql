

WITH jogadores AS (
    SELECT match_id, steamid, ANY_VALUE(name) AS nome
    FROM "cs2"."silver"."ticks"
    GROUP BY match_id, steamid
),
kills_agg AS (
    SELECT match_id, attacker_steamid AS steamid,
           COUNT(*) AS kills,
           COUNT(*) FILTER (headshot) AS headshots
    FROM "cs2"."silver"."kills"
    WHERE attacker_steamid IS NOT NULL
    GROUP BY match_id, attacker_steamid
),
mortes_agg AS (
    SELECT match_id, victim_steamid AS steamid, COUNT(*) AS mortes
    FROM "cs2"."silver"."kills"
    GROUP BY match_id, victim_steamid
),
assist_agg AS (
    SELECT match_id, assister_steamid AS steamid, COUNT(*) AS assistencias
    FROM "cs2"."silver"."kills"
    WHERE assister_steamid IS NOT NULL
    GROUP BY match_id, assister_steamid
),
dano_causado_agg AS (
    SELECT match_id, attacker_steamid AS steamid, SUM(dmg_health_real) AS dano_causado
    FROM "cs2"."silver"."damages"
    WHERE attacker_steamid IS NOT NULL
    GROUP BY match_id, attacker_steamid
),
dano_recebido_agg AS (
    SELECT match_id, victim_steamid AS steamid, SUM(dmg_health_real) AS dano_recebido
    FROM "cs2"."silver"."damages"
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
    COALESCE(dc.dano_causado, 0)                                      AS dano_causado,
    COALESCE(dr.dano_recebido, 0)                                     AS dano_recebido,
    'gold'  AS _camada,
    NOW()   AS _gerado_em
FROM jogadores j
LEFT JOIN kills_agg k       USING (match_id, steamid)
LEFT JOIN mortes_agg m      USING (match_id, steamid)
LEFT JOIN assist_agg a      USING (match_id, steamid)
LEFT JOIN dano_causado_agg dc USING (match_id, steamid)
LEFT JOIN dano_recebido_agg dr USING (match_id, steamid)
