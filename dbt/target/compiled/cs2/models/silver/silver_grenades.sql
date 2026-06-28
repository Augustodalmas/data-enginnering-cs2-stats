

SELECT
    NULLIF(TRIM(entity_id), '')::BIGINT        AS entity_id,
    NULLIF(TRIM(thrower_steamid), '')::BIGINT  AS thrower_steamid,
    NULLIF(TRIM(thrower), '')::VARCHAR         AS thrower,
    NULLIF(TRIM(grenade_type), '')::VARCHAR    AS grenade_type,
    NULLIF(TRIM(tick), '')::INTEGER            AS tick,
    NULLIF(TRIM(round_num), '')::INTEGER       AS round_num,
    NULLIF(TRIM(X), '')::DOUBLE                AS X,
    NULLIF(TRIM(Y), '')::DOUBLE                AS Y,
    NULLIF(TRIM(Z), '')::DOUBLE                AS Z,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM "cs2"."bronze"."grenades"
