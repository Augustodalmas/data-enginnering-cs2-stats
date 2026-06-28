# -*- coding: utf-8 -*-
"""
Sobe a UI web do DuckDB (http://localhost:4213) e mantém o processo vivo
até o usuário interromper com Ctrl+C.
"""

import os

import duckdb

caminho_duckdb = os.path.join(os.path.dirname(__file__), "..", "output", "cs2.duckdb")

con = duckdb.connect(caminho_duckdb)
con.install_extension("ui")
con.load_extension("ui")
con.sql("CALL start_ui()")

print("DuckDB UI rodando em http://localhost:4213 (Ctrl+C para fechar)")
input()
