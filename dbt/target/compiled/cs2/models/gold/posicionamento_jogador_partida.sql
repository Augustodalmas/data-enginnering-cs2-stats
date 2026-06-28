

SELECT
    t.match_id,
    t.steamid,
    ANY_VALUE(t.name)          AS nome,
    t.place,
    COUNT(*)                   AS qtd_ticks,
    COUNT(*) / r.taxa_de_tick  AS segundos_no_local,
    'gold'                     AS _camada,
    NOW()                      AS _gerado_em
FROM "cs2"."silver"."ticks" t
JOIN "cs2"."silver"."taxa_de_tick_partida" r USING (match_id)

GROUP BY t.match_id, t.steamid, t.place, r.taxa_de_tick