-- Falha se a ordem esperada de ticks de um round (start <= freeze_end <= end <= official_end)
-- for violada em algum round. Essa invariante sustenta o calculo de duracao_segundos e de
-- segundos_desde_inicio_round nas demais tabelas silver.
SELECT match_id, round_num, start, freeze_end, "end", official_end
FROM {{ ref('silver_rounds') }}
WHERE NOT (start <= freeze_end AND freeze_end <= "end" AND "end" <= official_end)
