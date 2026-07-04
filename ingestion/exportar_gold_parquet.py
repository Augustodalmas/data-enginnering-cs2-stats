# -*- coding: utf-8 -*-
"""
Exporta todas as tabelas/views do schema gold (output/cs2.duckdb) para
arquivos Parquet (output/parquet/gold/<tabela>.parquet).

A API (Django/DRF) nunca abre o cs2.duckdb diretamente — só lê esses
Parquet. Isso desacopla o uptime da API do pipeline de ingestão/dbt, já
que o DuckDB só permite 1 processo leitor-escritor por vez (ver CLAUDE.md).

Uso: .venv/Scripts/python.exe ingestion/exportar_gold_parquet.py
Rodar depois de qualquer `dbt build`/`dbt run` que mude a gold.
"""

import os

import duckdb

CAMINHO_DUCKDB = os.path.join(os.path.dirname(__file__), "..", "output", "cs2.duckdb")
PASTA_PARQUET = os.path.join(os.path.dirname(__file__), "..", "output", "parquet", "gold")


def exportar_gold_para_parquet():
    os.makedirs(PASTA_PARQUET, exist_ok=True)

    con = duckdb.connect(CAMINHO_DUCKDB, read_only=True)
    tabelas = con.execute(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'gold' ORDER BY 1"
    ).fetchall()

    for (tabela,) in tabelas:
        caminho_destino = os.path.join(PASTA_PARQUET, f"{tabela}.parquet").replace(os.sep, "/")
        con.execute(
            f"COPY (SELECT * FROM gold.{tabela}) TO '{caminho_destino}' (FORMAT PARQUET)"
        )
        print(f"gold.{tabela} -> {caminho_destino}")

    con.close()
    print(f"\n{len(tabelas)} tabela(s)/view(s) exportada(s) para {PASTA_PARQUET}")


if __name__ == "__main__":
    exportar_gold_para_parquet()
