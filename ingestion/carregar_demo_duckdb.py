# -*- coding: utf-8 -*-
"""
Parseia uma demo (.dem) de CS2 e carrega os dataframes em um arquivo
DuckDB (output/cs2.duckdb), uma tabela por dataframe, para inspecionar
os dados pela UI do DuckDB.
"""

import sys
import glob
import os
from datetime import datetime

import duckdb
import pandas as pd
from awpy import Demo

from cs2_utils import derivar_match_id_e_parte, encontrar_partes_do_match

# Nome de todas as tabelas que esse script pode criar no banco.
# Usado tanto para carregar quanto para limpar o banco (--limpar).
TODAS_AS_TABELAS = ["header", "rounds", "kills", "damages", "grenades",
                    "shots", "bomb", "ticks", "cvars"]

# Nome das tabelas de dataset (sem o header, que não tem round_num/tick).
TABELAS_DE_DATASET = [t for t in TODAS_AS_TABELAS if t != "header"]

# Schema do DuckDB onde fica a camada raw (sem nenhum tratamento): cada
# coluna gravada como string, só com metadados de rastreabilidade
# adicionados (_camada, _arquivo_origem, _carregado_em). Tratamento de tipo
# e qualquer transformação fica para a camada silver (schema separado, a
# ser criado depois).
SCHEMA_BRONZE = "bronze"

CAMINHO_DUCKDB = os.path.join(os.path.dirname(
    __file__), "..", "output", "cs2.duckdb")

PASTA_DEMOS = os.path.join(os.path.dirname(__file__), "..", "demos")


def encontrar_demo_padrao():
    """Procura o primeiro arquivo .dem dentro da pasta ./demos/ (recursivo, já que as demos ficam em subpastas por evento/fase)."""
    arquivos = sorted(glob.glob(os.path.join(PASTA_DEMOS, "**", "*.dem"), recursive=True))
    if not arquivos:
        return None
    return arquivos[0]


def converter_tudo_para_string(df_pandas):
    """
    Converte todas as colunas do dataframe para string (preservando nulos
    como NULL, não como a string "nan"). Camada bronze não faz tratamento
    de tipo — qualquer conversão (int, float, bool, timestamp) é
    responsabilidade da camada silver, pra ingestão nunca falhar por
    divergência de tipo entre demos (foi exatamente isso que quebrou a
    carga antes: campos do header vindo como tipos diferentes entre demos).
    """
    return df_pandas.astype("string")


def inserir_dataframe(con, nome_tabela, df_pandas):
    """
    Insere um dataframe pandas numa tabela do schema bronze, acumulando com
    cargas anteriores (não substitui mais o conteúdo da tabela — cada
    match_id é só adicionado). Cria a tabela na primeira carga, a partir do
    schema do próprio dataframe.

    Usa "INSERT ... BY NAME" porque demos diferentes podem ter as mesmas
    colunas em ordens diferentes (ex.: campos do header) — casar por posição
    (SELECT *) faria valores caírem em colunas erradas.
    """
    nome_tabela_completo = f"{SCHEMA_BRONZE}.{nome_tabela}"
    df_pandas = converter_tudo_para_string(df_pandas)
    con.register("df_temp", df_pandas)
    con.execute(
        f"CREATE TABLE IF NOT EXISTS {nome_tabela_completo} AS SELECT * FROM df_temp WHERE false")
    con.execute(
        f"INSERT INTO {nome_tabela_completo} BY NAME SELECT * FROM df_temp")
    con.unregister("df_temp")
    print(
        f"Tabela '{nome_tabela_completo}': {df_pandas.shape[0]} linhas inseridas.")


def match_id_ja_carregado(con, match_id):
    """
    Verifica se um match_id já existe na bronze (checa só bronze.header,
    que sempre é inserido junto com as demais tabelas da mesma carga).
    Usado pra idempotência: evita reparsear uma demo (operação cara, minutos
    por demo grande) se ela já estiver carregada.
    """
    tabela_existe = con.execute(
        "SELECT 1 FROM information_schema.tables "
        "WHERE table_schema = ? AND table_name = 'header'",
        [SCHEMA_BRONZE],
    ).fetchone()
    if tabela_existe is None:
        return False

    linha = con.execute(
        f"SELECT 1 FROM {SCHEMA_BRONZE}.header WHERE match_id = ? LIMIT 1",
        [match_id],
    ).fetchone()
    return linha is not None


def remover_match_id_da_bronze(con, match_id):
    """
    Remove todas as linhas de um match_id de todas as tabelas da bronze,
    usado antes de reinserir (--forcar). Como as linhas de um match_id são
    sempre inseridas juntas (numa carga só), elas ficam em blocos contíguos
    no DuckDB — o filtro WHERE match_id = ? só toca os blocos daquela
    partida (zonemaps), não escaneia a tabela inteira.
    """
    for nome_tabela in TODAS_AS_TABELAS:
        con.execute(
            f"DELETE FROM {SCHEMA_BRONZE}.{nome_tabela} WHERE match_id = ?",
            [match_id],
        )
    print(f"Linhas antigas de '{match_id}' removidas da bronze.")


def parsear_e_mesclar_partes(caminhos_partes):
    """
    Parseia cada arquivo .dem de uma partida (uma ou mais partes -p1/-p2/...)
    e mescla os dataframes de todas as partes em um só por dataset.

    round_num e tick reiniciam em cada arquivo .dem (ver CLAUDE.md), então
    cada parte (a partir da segunda) tem seus round_num e tick deslocados
    para continuar de onde a parte anterior parou.

    Cada linha recebe _arquivo_origem com o caminho do .dem de onde ela veio
    (cada parte tem seu próprio arquivo, mesmo depois de mescladas).
    """
    dataframes_das_partes = {nome: [] for nome in TABELAS_DE_DATASET}
    arquivos_origem_header = []
    header_primeira_parte = None
    round_offset = 0
    tick_offset = 0

    for caminho in caminhos_partes:
        print(f"Parseando parte: {caminho}")
        arquivo_origem = os.path.relpath(caminho, PASTA_DEMOS).replace(os.sep, "/")
        arquivos_origem_header.append(arquivo_origem)
        dem = Demo(caminho)
        dem.parse()

        if header_primeira_parte is None:
            header_primeira_parte = dem.header

        # use_pyarrow_extension_array=True preserva colunas inteiras com
        # nulos como inteiro exato (ex.: assister_steamid quando não há
        # assistência). Sem isso, o polars cai para float64 no pandas, e
        # SteamID64 (~17 dígitos) não cabe exato num float64 — corrompia o
        # valor silenciosamente (ex.: 76561198074762801 virava
        # 7.65611980747628e+16, perdendo o último dígito).
        df_rounds = dem.rounds.to_pandas(use_pyarrow_extension_array=True)
        df_rounds["round_num"] += round_offset
        for coluna_tick in ("start", "freeze_end", "end", "official_end", "bomb_plant"):
            df_rounds[coluna_tick] += tick_offset

        df_cvars = dem.server_cvars.to_pandas(use_pyarrow_extension_array=True)
        # tick == -1 é um "sem tick associado" (cvar inicial, antes da
        # gravação começar) — não desloca esse valor sentinela.
        df_cvars.loc[df_cvars["tick"] != -1, "tick"] += tick_offset

        dfs_da_parte = {
            "rounds": df_rounds,
            "kills": dem.kills.to_pandas(use_pyarrow_extension_array=True),
            "damages": dem.damages.to_pandas(use_pyarrow_extension_array=True),
            "grenades": dem.grenades.to_pandas(use_pyarrow_extension_array=True),
            "shots": dem.shots.to_pandas(use_pyarrow_extension_array=True),
            "bomb": dem.bomb.to_pandas(use_pyarrow_extension_array=True),
            "ticks": dem.ticks.to_pandas(use_pyarrow_extension_array=True),
            "cvars": df_cvars,
        }
        for nome, df in dfs_da_parte.items():
            if nome not in ("rounds", "cvars"):
                df["round_num"] += round_offset
                df["tick"] += tick_offset
            df["_arquivo_origem"] = arquivo_origem

        for nome, df in dfs_da_parte.items():
            dataframes_das_partes[nome].append(df)

        round_offset = df_rounds["round_num"].max()
        tick_offset = max(
            df_rounds["official_end"].max(),
            dfs_da_parte["ticks"]["tick"].max(),
        ) + 1

    dataframes_mesclados = {
        nome: pd.concat(partes, ignore_index=True)
        for nome, partes in dataframes_das_partes.items()
    }
    df_header = pd.DataFrame([header_primeira_parte])
    df_header["_arquivo_origem"] = ", ".join(arquivos_origem_header)
    dataframes_mesclados["header"] = df_header
    return dataframes_mesclados


def limpar_banco():
    """
    Remove todas as tabelas conhecidas do banco DuckDB (DROP TABLE IF EXISTS
    para cada uma). Usado antes de testes, para garantir que o banco comece
    vazio em vez de acumular tabelas de cargas anteriores.
    """
    if not os.path.isfile(CAMINHO_DUCKDB):
        print(
            f"Banco não existe ainda em: {CAMINHO_DUCKDB} (nada para limpar).")
        return

    con = duckdb.connect(CAMINHO_DUCKDB)
    con.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA_BRONZE}")
    for nome_tabela in TODAS_AS_TABELAS:
        con.execute(f"DROP TABLE IF EXISTS {SCHEMA_BRONZE}.{nome_tabela}")
        print(f"Tabela '{SCHEMA_BRONZE}.{nome_tabela}' removida (se existia).")
    con.close()
    print("Banco limpo.")


def carregar_demo(caminho_demo, forcar=False):
    """
    Fluxo principal: detecta se a demo faz parte de uma partida dividida em
    várias partes (-p1/-p2/...) e junta todas; deriva o match_id a partir da
    pasta (evento/fase); parseia e mescla os dataframes; e insere cada um
    como tabela no DuckDB, com a coluna match_id.

    Idempotência: se o match_id já existir na bronze, pula sem reparsear
    (operação cara) a menos que forcar=True, que remove as linhas antigas
    desse match_id e recarrega.
    """
    caminhos_partes = encontrar_partes_do_match(caminho_demo, PASTA_DEMOS)
    match_id, _ = derivar_match_id_e_parte(caminho_demo, PASTA_DEMOS)

    if len(caminhos_partes) > 1:
        nomes_partes = [os.path.basename(c) for c in caminhos_partes]
        print(f"Partida dividida em {len(caminhos_partes)} partes, juntando: {', '.join(nomes_partes)}")
    print(f"match_id: {match_id}")

    pasta_output = os.path.dirname(CAMINHO_DUCKDB)
    os.makedirs(pasta_output, exist_ok=True)
    con = duckdb.connect(CAMINHO_DUCKDB)
    con.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA_BRONZE}")

    if match_id_ja_carregado(con, match_id):
        if not forcar:
            print(f"'{match_id}' já está carregado na bronze. Pulando "
                  f"(use --forcar para recarregar).")
            con.close()
            return
        remover_match_id_da_bronze(con, match_id)

    print("Parseando demo(s). Isso pode levar alguns minutos para demos grandes...")
    dataframes = parsear_e_mesclar_partes(caminhos_partes)

    # Metadados de rastreabilidade: _arquivo_origem já foi adicionado por
    # linha em parsear_e_mesclar_partes (cada parte tem seu próprio
    # arquivo). _camada e _carregado_em são iguais para a carga inteira.
    carregado_em = datetime.now().isoformat()
    for df in dataframes.values():
        df["match_id"] = match_id
        df["_camada"] = "bronze"
        df["_carregado_em"] = carregado_em

    for nome_tabela in TODAS_AS_TABELAS:
        inserir_dataframe(con, nome_tabela, dataframes[nome_tabela])

    con.close()
    print(f"\nDados carregados em: {CAMINHO_DUCKDB}")


def main():
    # Flag --limpar: apaga todas as tabelas do banco e encerra, sem parsear nenhuma demo.
    if "--limpar" in sys.argv:
        limpar_banco()
        return

    # Flag --forcar: recarrega o match_id mesmo se já existir na bronze
    # (remove as linhas antigas e reparseia). Sem ela, demo já carregada é pulada.
    forcar = "--forcar" in sys.argv
    argumentos_posicionais = [a for a in sys.argv[1:] if a != "--forcar"]

    if argumentos_posicionais:
        caminho_demo = argumentos_posicionais[0]
    else:
        caminho_demo = encontrar_demo_padrao()
        if caminho_demo is None:
            print(
                "Nenhum arquivo .dem encontrado em ./demos/ e nenhum caminho foi informado.")
            sys.exit(1)
        print(
            f"Nenhum argumento informado. Usando demo padrão: {caminho_demo}")

    if not os.path.isfile(caminho_demo):
        print(f"Arquivo não encontrado: {caminho_demo}")
        sys.exit(1)

    carregar_demo(caminho_demo, forcar=forcar)


if __name__ == "__main__":
    main()
