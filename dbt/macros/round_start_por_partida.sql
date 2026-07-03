{% macro round_start_por_partida() %}
    SELECT
        match_id,
        NULLIF(TRIM(round_num), '')::INTEGER AS round_num,
        NULLIF(TRIM(start), '')::INTEGER     AS round_start_tick
    FROM {{ source('bronze', 'rounds') }}
{% endmacro %}
