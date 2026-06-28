

SELECT
    NULLIF(TRIM(tick), '')::INTEGER   AS tick,
    NULLIF(TRIM(name), '')::VARCHAR   AS name,
    NULLIF(TRIM(value), '')::VARCHAR  AS value,
    match_id,
    _arquivo_origem,
    'silver'                 AS _camada,
    _carregado_em::TIMESTAMP AS _carregado_em,
    NOW()                    AS _transformado_em
FROM "cs2"."bronze"."cvars"
