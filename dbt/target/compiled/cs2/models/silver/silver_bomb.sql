

SELECT
    NULLIF(TRIM(tick), '')::INTEGER       AS tick,
    NULLIF(TRIM(round_num), '')::INTEGER  AS round_num,
    NULLIF(TRIM(event), '')::VARCHAR      AS event,
    NULLIF(TRIM(bombsite), '')::VARCHAR   AS bombsite,
    NULLIF(TRIM(name), '')::VARCHAR       AS name,
    NULLIF(TRIM(X), '')::DOUBLE           AS X,
    NULLIF(TRIM(Y), '')::DOUBLE           AS Y,
    NULLIF(TRIM(Z), '')::DOUBLE           AS Z,
    NULLIF(TRIM(steamid), '')::BIGINT     AS steamid,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM "cs2"."bronze"."bomb"
