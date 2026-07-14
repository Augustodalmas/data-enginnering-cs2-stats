# Fluxo: adicionar novas demos ao projeto

**Única forma suportada: upload via API.** A CLI
(`ingestion/carregar_demo_duckdb.py`) ainda existe no código — é reusada
internamente pelo worker Celery — mas não é mais um fluxo recomendado
pra carregar demos manualmente; use sempre o upload da API.

## Upload via API

1. `POST /api/demos/` (multipart: `evento`, `fase`, `arquivo` — um `.dem`
   único ou um `.zip` com várias, inclusive partes `-p1`/`-p2` da mesma
   partida — `forcar` opcional) → 202 com `job_id`.
2. `GET /api/demos/status/<job_id>/` até concluir. O worker Celery roda
   `carregar_demo` (parse + merge de partes + idempotência) e a demo fica
   na bronze; o(s) `.dem` já foram descartados (área de upload é efêmera,
   separada de `demos/`).
   Pode repetir esse passo várias vezes (vários uploads/lotes) antes de
   ir pro passo 3 — não precisa rodar o passo 3 a cada upload individual.

## Passo 3 — processar silver/gold e exportar

```
cd dbt
./build_e_exportar.ps1
```

Roda `dbt build` (silver + gold + testes, só reprocessa `match_id` novos,
incremental) e, se passar, exporta a gold pra
`output/parquet/gold/*.parquet`. Sem esse passo, uma demo carregada via
API fica presa na bronze e invisível pra API de consumo — ela só lê a
gold já materializada/exportada, nunca a bronze direto.

Aceita `-Select <model>` repassado direto pro `dbt build`, ex.:
`./build_e_exportar.ps1 -Select silver_kills`.

**Se mudou lógica de algum model** (não só demo nova): rodar
`--full-refresh` nesse model antes, direto no dbt (`dbt build
--full-refresh --profiles-dir . --select <model>`) — o wrapper não expõe
essa flag hoje.

## Depois do passo 3

- API (`GET /api/combate/`, `/api/granadas/`, etc.) já serve os dados
  novos, direto do Parquet.
