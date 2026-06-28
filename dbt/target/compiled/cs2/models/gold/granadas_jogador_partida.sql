

WITH granadas_unicas AS (
    SELECT
        match_id,
        entity_id,
        round_num,
        thrower_steamid,
        CASE
            WHEN grenade_type LIKE '%HEGrenade%'  THEN 'HE'
            WHEN grenade_type LIKE '%Flashbang%'  THEN 'Flash'
            WHEN grenade_type LIKE '%SmokeGrenade%' THEN 'Smoke'
            WHEN grenade_type LIKE '%Molotov%'    THEN 'Molotov'
            WHEN grenade_type LIKE '%Incendiary%' THEN 'Incendiary'
            WHEN grenade_type LIKE '%Decoy%'      THEN 'Decoy'
            ELSE grenade_type
        END AS categoria_granada,
        ANY_VALUE(thrower) AS nome
    FROM "cs2"."silver"."grenades"
    WHERE thrower_steamid IS NOT NULL
    
    GROUP BY match_id, entity_id, round_num, thrower_steamid, categoria_granada
)
SELECT
    match_id,
    thrower_steamid AS steamid,
    ANY_VALUE(nome) AS nome,
    categoria_granada,
    COUNT(*)        AS granadas_lancadas,
    'gold'          AS _camada,
    NOW()           AS _gerado_em
FROM granadas_unicas
GROUP BY match_id, thrower_steamid, categoria_granada