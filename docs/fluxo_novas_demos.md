# Fluxo: adicionar novas demos ao projeto

Duas formas de carregar uma demo nova. As duas terminam na bronze — dali
em diante o processo é o mesmo (passo 3).

## Opção A — CLI manual

1. Colocar a(s) `.dem` em `./demos/<evento>/<fase>/` (subpasta obrigatória
   — é dela que o `match_id` é derivado).
2. Carregar na bronze:
   ```
   .venv/Scripts/python.exe ingestion/carregar_demo_duckdb.py [caminho_do_dem]
   ```
   Sem argumento, acha a primeira `.dem` em `./demos/` recursivamente.
   Idempotente (pula `match_id` já carregado; `--forcar` recarrega). Não
   toca no `.duckdb` (bronze é Parquet) — só é preciso fechar `duckdb_ui.py`
   antes do passo 3, que sim usa o DuckDB (silver/gold).

## Opção B — API de upload

1. `POST /api/demos/` (multipart: `evento`, `fase`, `arquivo` — um `.dem`
   único ou um `.zip` com várias, inclusive partes `-p1`/`-p2` da mesma
   partida — `forcar` opcional) → 202 com `job_id`.
2. `GET /api/demos/status/<job_id>/` até concluir. O worker Celery já
   rodou o mesmo `carregar_demo` da CLI (parse + merge de partes +
   idempotência) e a demo está na bronze; o(s) `.dem` já foram descartados
   (área de upload é efêmera, separada de `demos/`).
   Pode repetir esse passo várias vezes (vários uploads/lotes) antes de
   ir pro passo 3 — não precisa rodar o passo 3 a cada upload individual.

## Passo 3 (comum às duas opções) — processar silver/gold e exportar

```
cd dbt
./build_e_exportar.ps1
```

Roda `dbt build` (silver + gold + testes, só reprocessa `match_id` novos,
incremental) e, se passar, exporta a gold pra
`output/parquet/gold/*.parquet`. Sem esse passo, uma demo carregada (por
CLI ou API) fica presa na bronze e invisível pra API de consumo — ela só
lê a gold já materializada/exportada, nunca a bronze direto.

Aceita `-Select <model>` repassado direto pro `dbt build`, ex.:
`./build_e_exportar.ps1 -Select silver_kills`.

**Se mudou lógica de algum model** (não só demo nova): rodar
`--full-refresh` nesse model antes, direto no dbt (`dbt build
--full-refresh --profiles-dir . --select <model>`) — o wrapper não expõe
essa flag hoje.

## Depois do passo 3

- API (`GET /api/combate/`, `/api/granadas/`, etc.) já serve os dados
  novos, direto do Parquet.
