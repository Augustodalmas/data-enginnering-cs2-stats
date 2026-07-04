# API (Django + DRF) — camada de consumo da gold

Lê a camada `gold` via Parquet exportado (nunca abre `output/cs2.duckdb`
diretamente — ver `CLAUDE.md`, seção "API de consumo").

## Rodando via Docker Compose (recomendado)

```
# 1. Exportar a gold pra Parquet (rodar de novo sempre que a gold mudar)
.venv/Scripts/python.exe ingestion/exportar_gold_parquet.py

# 2. Copiar api/.env.example pra api/.env e ajustar se necessário

# 3. Subir tudo (Nginx + 3 réplicas da API + Redis + worker Celery)
docker compose up -d --build --scale api=3
```

API disponível em `http://localhost:8080/api/...` (via Nginx, que
balanceia entre as 3 réplicas).

**Importante — sempre use `--scale api=3`, não 3 serviços fixos.** O Nginx
open-source não re-resolve DNS de um `upstream {}` estático (recurso
exclusivo do Nginx Plus): com serviços de nome fixo, toda vez que uma
réplica é recriada ela ganha IP novo e o Nginx passa a recusar conexão pra
esse backend até ser reiniciado manualmente. Com as réplicas sob o mesmo
nome de serviço (`api`), o `nginx.conf` usa `resolver` + variável pra
re-resolver sozinho a cada ~10s — testado na prática: matar e recriar uma
réplica não exige nenhuma ação manual, o tráfego volta a fluir pra ela
sozinho.

Comandos úteis:
```
docker compose ps                      # status dos containers
docker compose logs api --tail 100     # logs das 3 réplicas (prefixados por nome)
docker compose logs celery_worker -f   # acompanhar o worker em tempo real
docker compose logs nginx -f
docker compose restart celery_worker   # depois de mudar cs2api/tasks.py
docker compose up -d --build --scale api=3   # depois de mudar qualquer código da API
```

## Rodando localmente (dev, sem Docker)

```
.venv/Scripts/python.exe ingestion/exportar_gold_parquet.py
docker run -d -p 6379:6379 redis:7-alpine   # ou outro Redis acessível
cp api/.env.example api/.env

cd api
../.venv/Scripts/python.exe manage.py runserver

# noutro terminal, o worker Celery:
cd api
../.venv/Scripts/celery.exe -A config worker --loglevel=info --pool=solo --concurrency=1
```

`--pool=solo` é necessário no Windows. `--concurrency=1` não é opcional —
ver "Limitações conhecidas" abaixo.

## Endpoints

- `GET /api/partidas/` — dim_partida (evento, fase, mapa, confronto_id,
  formato, time_1, time_2)
- `GET /api/combate/` — combate_jogador_partida
- `GET /api/granadas/` — granadas_jogador_partida
- `GET /api/posicionamento/` — posicionamento_jogador_partida
- `GET /api/bomba/` — bomba_jogador_partida

Todos paginados (`page`, `page_size`, máx. 500) e filtráveis por query
params (ver `colunas_filtro` de cada view em `cs2api/views_consulta.py`),
ex.: `GET /api/combate/?fase=final&mapa=de_mirage&page_size=20`. `count`
no payload é sempre o total da consulta inteira (considerando os
filtros), não o total da página.

- `POST /api/demos/` — multipart: `evento`, `fase`, `arquivo` (`.dem` OU
  `.zip` com uma ou mais `.dem` dentro — inclusive partes `-p1`/`-p2` de
  uma mesma partida), `forcar` (opcional). Retorna 202 com 1 `job_id` na
  hora; toda a extração/parse/carga na bronze roda em background num
  worker Celery — o(s) arquivo(s) `.dem` são descartados depois de
  carregados (`demos/` é só área de trabalho efêmera nesse fluxo, ao
  contrário do fluxo manual via CLI).
- `GET /api/demos/status/<job_id>/` — status do job (`PENDING`, `STARTED`,
  `SUCCESS`, `FAILURE`). Se for um `.zip` com várias partidas, o resultado
  traz um resumo por partida encontrada.

## Limitações conhecidas

- **O `POST` só carrega até a camada bronze.** `dbt build` e
  `ingestion/exportar_gold_parquet.py` continuam sendo passos manuais
  depois — os dados de um upload novo só aparecem nos GETs depois de
  rodar os dois (decisão deliberada: manter o worker rápido e a imagem
  Docker enxuta, em vez de rodar dbt dentro da task). A resposta do POST e
  do status do job já avisam disso.
- **O worker Celery roda com `--concurrency=1` por exigência, não por
  opção de performance**: o DuckDB só permite 1 processo leitor-escritor
  por vez. Enfileirar vários uploads em paralelo funciona (nenhum se
  perde), mas são processados em série, um de cada vez.
