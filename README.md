# CS2 Data Engineering — Pipeline Medalhão de Demos de Campeonato

Portfólio de engenharia de dados: partidas de CS2 (demos `.dem` de
campeonatos profissionais) parseadas, transformadas numa arquitetura
medalhão (**bronze → silver → gold**) e expostas via dashboard — com um
banco DuckDB local como motor de armazenamento/consulta.

![Pipeline de dados de CS2 em camadas](cs2_data_pipeline_medallion.svg)

## Status atual

- ✅ Ingestão (bronze): parsing de `.dem` com [`awpy`](https://github.com/pnxenopoulos/awpy) e carga idempotente no DuckDB.
- ✅ Transformação (silver/gold): implementada em [dbt](https://www.getdbt.com/) — cast tipado, testes de qualidade de dados, colunas derivadas (duração de round, tempo desde o início do round), fatos e views de ranking.
- ✅ Consumo: dashboard Streamlit sobre a camada gold.
- ⏳ Aquisição de demos: hoje manual (usuário baixa e organiza os arquivos).
- ⏳ API de consumo: ainda não iniciada.

Detalhes de arquitetura, decisões e achados de qualidade de dados estão em
`CLAUDE.md` (não versionado — notas de trabalho) e no catálogo gerado pelo
dbt (`dbt docs generate` + `dbt docs serve`, ver abaixo).

## Arquitetura

```
demos/*.dem (awpy) → bronze (DuckDB, tudo VARCHAR)
                        │
                        ▼  dbt (cast tipado + testes)
                     silver (tipos corretos, colunas derivadas)
                        │
                        ▼  dbt (agregação jogador × partida)
                      gold (fatos + rankings)
                        │
                        ▼
                dashboard (Streamlit)
```

- **Bronze**: toda coluna gravada como `VARCHAR`, sem cast — ingestão nunca
  falha por divergência de tipo entre demos. Idempotente por `match_id`
  (demo já carregada é pulada, salvo `--forcar`).
- **Silver**: models dbt incrementais, 1 por dataframe do `awpy`
  (`kills`, `damages`, `rounds`, ...), com cast pro tipo lógico correto e
  colunas derivadas (`duracao_segundos`, `segundos_desde_inicio_round`) via
  macros SQL reutilizáveis.
- **Gold**: fatos no grão jogador × partida (combate, granadas,
  posicionamento, bomba) + views de ranking em 4 granularidades (total,
  por fase, por evento, por mapa).

## Stack

Python 3.11 · [`awpy`](https://github.com/pnxenopoulos/awpy) (parser de demos, Polars) · [DuckDB](https://duckdb.org/) · [dbt-core](https://www.getdbt.com/) + `dbt-duckdb` · [Streamlit](https://streamlit.io/)

## Estrutura do repositório

```
ingestion/    parsing das demos e carga na bronze, dashboard, UI do DuckDB
dbt/          transformação silver/gold (models, macros, testes, docs)
docs/         dicionário de dados (significado de cada coluna, validado contra dados reais)
demos/        arquivos .dem de origem (não versionado — arquivos grandes)
output/       banco DuckDB gerado pelo pipeline (não versionado)
```

## Rodando o projeto

```bash
# ambiente
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt

# 1. ingestão — parseia .dem e carrega a bronze
.venv/Scripts/python.exe ingestion/carregar_demo_duckdb.py

# 2. transformação — silver + gold via dbt
cd dbt
../.venv/Scripts/dbt.exe build --profiles-dir .

# 3. consumo
../.venv/Scripts/python.exe -m streamlit run ../ingestion/dashboard.py
```

Catálogo de dados navegável (descrição de toda tabela/coluna, gerado a
partir de `dbt/models/**/*.yml`):

```bash
cd dbt
../.venv/Scripts/dbt.exe docs generate --profiles-dir .
../.venv/Scripts/dbt.exe docs serve --profiles-dir .
```

## Qualidade de dados

63 testes dbt (`not_null`, `unique`, `accepted_values` e invariantes
customizadas) rodando sobre os dados reais já carregados — não são
suposições sobre o schema, cada teste foi validado contra o dataset atual
antes de ser escrito. Ver `dbt/models/silver/_silver__models.yml`,
`dbt/models/gold/_gold__models.yml` e `dbt/tests/`.
