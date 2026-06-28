

SELECT
    NULLIF(TRIM(map_name), '')::VARCHAR                          AS map_name,
    NULLIF(TRIM(server_name), '')::VARCHAR                       AS server_name,
    NULLIF(TRIM(client_name), '')::VARCHAR                       AS client_name,
    NULLIF(TRIM(demo_version_name), '')::VARCHAR                 AS demo_version_name,
    NULLIF(TRIM(demo_version_guid), '')::VARCHAR                 AS demo_version_guid,
    NULLIF(TRIM(patch_version), '')::VARCHAR                     AS patch_version,
    NULLIF(TRIM(game_directory), '')::VARCHAR                    AS game_directory,
    NULLIF(TRIM(demo_file_stamp), '')::VARCHAR                   AS demo_file_stamp,
    NULLIF(TRIM(addons), '')::VARCHAR                            AS addons,
    LOWER(NULLIF(TRIM(allow_clientside_entities), ''))::BOOLEAN  AS allow_clientside_entities,
    LOWER(NULLIF(TRIM(allow_clientside_particles), ''))::BOOLEAN AS allow_clientside_particles,
    NULLIF(TRIM(fullpackets_version), '')::BIGINT                AS fullpackets_version,
    match_id,
    _arquivo_origem,
    'silver'                        AS _camada,
    _carregado_em::TIMESTAMP        AS _carregado_em,
    NOW()                           AS _transformado_em
FROM "cs2"."bronze"."header"
