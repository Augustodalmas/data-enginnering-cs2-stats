"""
Consulta a camada gold direto dos arquivos Parquet exportados (nunca do
cs2.duckdb — ver ingestion/exportar_gold_parquet.py e CLAUDE.md, seção "API
de consumo"). Paginação e filtros são empurrados pro SQL (LIMIT/OFFSET/
WHERE), sem materializar a tabela inteira em memória Python.

Cada conexão é efêmera e em memória (`duckdb.connect()` sem caminho de
arquivo) — não abre nenhum banco em disco, só lê os Parquet via
`read_parquet()`. Isso evita qualquer contenção de concorrência entre as
réplicas da API (o gargalo de "1 escritor por vez" é do arquivo .duckdb,
que a API nunca abre).
"""

import os

import duckdb
from django.conf import settings


def _caminho_parquet(tabela):
    caminho = os.path.join(settings.PARQUET_GOLD_DIR, f"{tabela}.parquet")
    return caminho.replace(os.sep, "/")


def _montar_from_e_select(tabela_fato, com_join_dim_partida):
    caminho_fato = _caminho_parquet(tabela_fato)
    if not com_join_dim_partida:
        return f"read_parquet('{caminho_fato}') AS f", "f.*"

    caminho_dim = _caminho_parquet("dim_partida")
    from_clause = (
        f"read_parquet('{caminho_fato}') AS f "
        f"JOIN read_parquet('{caminho_dim}') AS d USING (match_id)"
    )
    select_cols = "f.*, d.evento, d.fase, d.mapa, d.confronto_id, d.formato, d.time_1, d.time_2"
    return from_clause, select_cols


def executar_consulta_paginada(tabela_fato, com_join_dim_partida, colunas_filtro,
                                filtros, coluna_ordenacao, pagina, tamanho_pagina):
    """
    filtros: dict {coluna: valor}, só as chaves presentes em colunas_filtro
    são de fato usadas (whitelist definida pela view, não pelo request —
    protege contra injeção de nome de coluna). Valores sempre entram via
    bind parameter (?), nunca interpolados na string SQL.
    coluna_ordenacao: string fixa definida pela view (não vem do request).
    """
    from_clause, select_cols = _montar_from_e_select(tabela_fato, com_join_dim_partida)

    condicoes = []
    parametros = []
    for coluna, valor in filtros.items():
        if coluna not in colunas_filtro:
            continue
        condicoes.append(f'"{coluna}" = ?')
        parametros.append(valor)
    where_sql = f"WHERE {' AND '.join(condicoes)}" if condicoes else ""

    con = duckdb.connect()
    try:
        total = con.execute(
            f"SELECT COUNT(*) FROM {from_clause} {where_sql}", parametros
        ).fetchone()[0]

        offset = (pagina - 1) * tamanho_pagina
        linhas_df = con.execute(
            f"SELECT {select_cols} FROM {from_clause} {where_sql} "
            f"ORDER BY {coluna_ordenacao} LIMIT ? OFFSET ?",
            parametros + [tamanho_pagina, offset],
        ).fetchdf()
    finally:
        con.close()

    return total, linhas_df.to_dict(orient="records")
