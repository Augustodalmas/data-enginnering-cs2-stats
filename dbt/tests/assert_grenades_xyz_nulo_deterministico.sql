-- Falha se o padrão de nulo de X/Y/Z em silver.grenades deixar de ser
-- determinístico pelo grenade_type: deve ser sempre NULL na fase "na mão"
-- (grenade_type sem sufixo Projectile) e sempre populado na fase "em voo"
-- (sufixo Projectile) — ver docs/dicionario_dados.md.
SELECT grenade_type, COUNT(*) AS linhas_fora_do_padrao
FROM {{ ref('silver_grenades') }}
WHERE (grenade_type LIKE '%Projectile' AND X IS NULL)
   OR (grenade_type NOT LIKE '%Projectile' AND X IS NOT NULL)
GROUP BY grenade_type
