{% macro taxa_de_tick_por_partida() %}
    SELECT
        pr.match_id,
        pr.ticks_de_freeze / cf.freezetime_segundos AS taxa_de_tick
    FROM (
        SELECT
            match_id,
            MODE(NULLIF(TRIM(freeze_end), '')::INTEGER - NULLIF(TRIM(start), '')::INTEGER) AS ticks_de_freeze
        FROM {{ source('bronze', 'rounds') }}
        GROUP BY match_id
    ) pr
    JOIN (
        SELECT
            match_id,
            ANY_VALUE(NULLIF(TRIM(value), ''))::DOUBLE AS freezetime_segundos
        FROM {{ source('bronze', 'cvars') }}
        WHERE NULLIF(TRIM(name), '') = 'mp_freezetime'
        GROUP BY match_id
    ) cf USING (match_id)
{% endmacro %}
