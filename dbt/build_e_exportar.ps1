# Roda `dbt build` (silver + gold + testes) e, se for bem-sucedido, exporta
# a gold pra Parquet — substitui os dois passos manuais de sempre (dbt build
# + ingestion/exportar_gold_parquet.py) por um só. Ver CLAUDE.md, seção
# "API de consumo", pra por que a API só le Parquet (nunca o cs2.duckdb
# diretamente).
#
# Uso (a partir de dbt/, mesmo lugar dos outros comandos dbt do projeto):
#   ./build_e_exportar.ps1
#   ./build_e_exportar.ps1 -Select silver_kills   # repassado direto pro dbt build

param(
    [string]$Select
)

$ErrorActionPreference = "Stop"

$dbtArgs = @("build", "--profiles-dir", ".")
if ($Select) {
    $dbtArgs += @("--select", $Select)
}

& ../.venv/Scripts/dbt.exe @dbtArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "dbt build falhou (exit code $LASTEXITCODE) - export para Parquet nao foi executado."
    exit $LASTEXITCODE
}

& ../.venv/Scripts/python.exe ../ingestion/exportar_gold_parquet.py
exit $LASTEXITCODE
