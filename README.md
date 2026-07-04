# CS2 Data Engineering — Pipeline Medalhão + API de Consumo

Projeto acadêmico/portfólio de engenharia de dados: partidas de CS2 (demos
`.dem` de campeonatos profissionais) parseadas, transformadas numa
arquitetura medalhão (**bronze → silver → gold**) com DuckDB + dbt, e
servidas por uma API REST (Django/DRF) atrás de um load balancer, com
cache e processamento assíncrono. **Ainda em desenvolvimento** — este
README reflete o estado atual, não um produto terminado.

![Arquitetura do projeto](arquitetura.svg)

## Status atual

- ✅ Ingestão (bronze): parsing de `.dem` com [`awpy`](https://github.com/pnxenopoulos/awpy) e carga idempotente no DuckDB.
- ✅ Transformação (silver/gold): implementada em [dbt](https://www.getdbt.com/) — cast tipado, testes de qualidade de dados, colunas derivadas, fatos e dimensões (incluindo detecção de formato de série MD1/MD3/MD5 e agrupamento de times a partir do nome do arquivo).
- ✅ Consumo via dashboard Streamlit sobre a gold.
- ✅ **API de consumo** (Django + DRF): endpoints `GET` paginados (filtro e paginação empurrados pro SQL do DuckDB, lendo Parquet exportado da gold) e `POST` de upload de demo (`.dem` ou `.zip` em lote), processado de forma assíncrona via **Celery + Redis**.
- ✅ **Infraestrutura**: `docker-compose` com Nginx como load balancer na frente de 3 réplicas da API, cache Redis e worker Celery dedicado.
- ⏳ Aquisição de demos: hoje manual (usuário baixa e organiza os arquivos).
- ⏳ Export Parquet → API ainda é um passo manual depois do `dbt build` (não automatizado de propósito, ver `CLAUDE.md`).

## Arquitetura

Duas partes independentes (ver diagrama acima):

1. **Pipeline de dados** (batch, sem necessidade de estar sempre no ar):
   `demos/*.dem` → `awpy` → **bronze** (DuckDB, tudo `VARCHAR`, sem cast) →
   **silver** (dbt, tipagem + colunas derivadas) → **gold** (dbt, fatos
   jogador×partida + dimensões + rankings) → export pra **Parquet**.
2. **API de consumo** (sempre no ar, containers Docker):
   Nginx (load balancer round-robin, DNS dinâmico) → 3 réplicas da API
   (Django/DRF, sem ORM — consulta o Parquet direto via `duckdb`) → Redis
   (cache dos `GET`, TTL fixo). O `POST` de upload salva o arquivo numa
   pasta de staging isolada (`api_uploads/`, nunca `demos/`) e enfileira o
   processamento num worker Celery — que reusa a mesma função de carga da
   CLI, evita travar a API durante o parse (minutos) e descarta o arquivo
   depois de carregado.

A API **nunca abre o `.duckdb` diretamente** — só o worker Celery
(exclusivo, 1 de cada vez) escreve nele; a API só lê os Parquet
exportados. Isso existe porque o DuckDB só permite 1 processo
leitor-escritor por vez — detalhe de concorrência real que apareceu (e foi
corrigido) durante o desenvolvimento, documentado em `CLAUDE.md`.

## Stack

**Dados**: Python 3.11 · [`awpy`](https://github.com/pnxenopoulos/awpy) (parser de demos) · [DuckDB](https://duckdb.org/) · [dbt-core](https://www.getdbt.com/) + `dbt-duckdb` · [Streamlit](https://streamlit.io/)

**API**: Django + [Django REST Framework](https://www.django-rest-framework.org/) · [Celery](https://docs.celeryq.dev/) · [Redis](https://redis.io/) · [Gunicorn](https://gunicorn.org/) · [Nginx](https://nginx.org/) · [Docker](https://www.docker.com/) / Docker Compose

## Estrutura do repositório

```
ingestion/     parsing das demos, carga na bronze, export Parquet, dashboard
dbt/           transformação silver/gold (models, macros, testes, docs)
docs/          dicionário de dados (validado contra dados reais)
api/           projeto Django/DRF (GET paginado, POST assíncrono de upload)
nginx/         config do load balancer
demos/         arquivos .dem de origem (não versionado — arquivos grandes)
output/        banco DuckDB + Parquet exportado (não versionado)
```

## Rodando o projeto

### Pipeline de dados

```bash
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt

# 1. ingestão — parseia .dem e carrega a bronze
.venv/Scripts/python.exe ingestion/carregar_demo_duckdb.py

# 2. transformação — silver + gold via dbt
cd dbt
../.venv/Scripts/dbt.exe build --profiles-dir .
cd ..

# 3. exportar a gold pra Parquet (necessário antes de subir a API)
.venv/Scripts/python.exe ingestion/exportar_gold_parquet.py

# 4. dashboard
.venv/Scripts/python.exe -m streamlit run ingestion/dashboard.py
```

### API (Docker Compose)

```bash
cp api/.env.example api/.env
docker compose up -d --build --scale api=3
```

API em `http://localhost:8080/api/...`. Detalhes de endpoints, exemplos de
`curl` e limitações conhecidas em [`api/README.md`](api/README.md).

## Qualidade de dados

Testes dbt (`not_null`, `unique`, `accepted_values` e invariantes
customizadas) rodando sobre os dados reais já carregados — não são
suposições sobre o schema, cada teste foi validado contra o dataset atual
antes de ser escrito, incluindo uma auditoria sistemática de `% de NULL`
por coluna em toda a silver/gold. Ver `dbt/models/silver/_silver__models.yml`,
`dbt/models/gold/_gold__models.yml` e `dbt/tests/`.

## Sobre o desenvolvimento

Este projeto foi construído em parceria com o **Claude** (Anthropic) —
boa parte da codificação (models dbt, código Python/Django, configuração
de infraestrutura) foi escrita com o assistente. As decisões de
arquitetura, escolha de tecnologias (dbt, DuckDB, Django/DRF, Celery,
Redis, Nginx, Docker) e critérios de negócio (ex.: como detectar formato
MD1/MD3/MD5, como não contar team-kill como abate) são minhas — usei o
Claude pra validar, questionar e implementar essas decisões, e sempre
revisei o resultado antes de aceitar. Vários problemas reais de
engenharia (limite de concorrência do DuckDB, timeout de upload, DNS
estático do Nginx, um bug que quase apagou uma demo real) só apareceram
testando de verdade, não só lendo o código — parte do valor deste projeto
pra mim foi justamente aprender debugando isso ao vivo.
