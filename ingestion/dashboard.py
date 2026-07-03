# -*- coding: utf-8 -*-
"""
Dashboard simples (Streamlit) pra explorar a camada gold de output/cs2.duckdb.

Uso: .venv/Scripts/python.exe -m streamlit run src/dashboard.py
"""

import os

import duckdb
import streamlit as st

CAMINHO_DUCKDB = os.path.join(os.path.dirname(__file__), "..", "output", "cs2.duckdb")

st.set_page_config(page_title="CS2 — Dashboard", layout="wide")


@st.cache_data
def carregar_tabela_gold(nome_tabela):
    """Lê uma tabela/view da gold inteira pra um dataframe (tabelas pequenas — grão por jogador/partida)."""
    con = duckdb.connect(CAMINHO_DUCKDB, read_only=True)
    df = con.execute(f"SELECT * FROM gold.{nome_tabela}").df()
    con.close()
    return df


dim_partida = carregar_tabela_gold("dim_partida")
combate = carregar_tabela_gold("combate_jogador_partida").merge(dim_partida, on="match_id")
granadas = carregar_tabela_gold("granadas_jogador_partida").merge(dim_partida, on="match_id")
posicionamento = carregar_tabela_gold("posicionamento_jogador_partida").merge(dim_partida, on="match_id")
bomba = carregar_tabela_gold("bomba_jogador_partida").merge(dim_partida, on="match_id")

st.sidebar.header("Filtros")

eventos = sorted(dim_partida["evento"].unique())
evento_sel = st.sidebar.multiselect("Evento", eventos, default=eventos)

fases_disponiveis = sorted(dim_partida.loc[dim_partida["evento"].isin(evento_sel), "fase"].unique())
fase_sel = st.sidebar.multiselect("Fase", fases_disponiveis, default=fases_disponiveis)

mapas_disponiveis = sorted(dim_partida.loc[
    dim_partida["evento"].isin(evento_sel) & dim_partida["fase"].isin(fase_sel), "mapa"
].unique())
mapa_sel = st.sidebar.multiselect("Mapa", mapas_disponiveis, default=mapas_disponiveis)


def filtrar(df):
    return df[df["evento"].isin(evento_sel) & df["fase"].isin(fase_sel) & df["mapa"].isin(mapa_sel)]


combate_f = filtrar(combate)
granadas_f = filtrar(granadas)
posicionamento_f = filtrar(posicionamento)
bomba_f = filtrar(bomba)

st.title("CS2 — Estatísticas (camada gold)")
st.caption(f"{combate_f['match_id'].nunique()} partida(s) selecionada(s)")

aba_combate, aba_granadas, aba_posicionamento, aba_bomba = st.tabs(
    ["Combate", "Granadas", "Posicionamento", "Bomba"]
)

with aba_combate:
    ranking = combate_f.groupby(["steamid", "nome"], as_index=False).agg(
        kills=("kills", "sum"),
        mortes=("mortes", "sum"),
        assistencias=("assistencias", "sum"),
        headshots=("headshots", "sum"),
        team_kills=("team_kills", "sum"),
        dano_causado=("dano_causado", "sum"),
        dano_recebido=("dano_recebido", "sum"),
    ).sort_values("kills", ascending=False)
    ranking["hs_pct"] = (ranking["headshots"] / ranking["kills"]).round(3)

    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Kills")
        st.bar_chart(ranking.set_index("nome")["kills"])
    with col2:
        st.subheader("Dano causado")
        st.bar_chart(ranking.set_index("nome")["dano_causado"])
    st.dataframe(ranking, use_container_width=True)

    fogo_amigo = ranking[ranking["team_kills"] > 0].sort_values("team_kills", ascending=False)
    if not fogo_amigo.empty:
        st.subheader("Fogo amigo (team-kills)")
        st.bar_chart(fogo_amigo.set_index("nome")["team_kills"])

with aba_granadas:
    ranking_g = granadas_f.groupby(["nome", "categoria_granada"], as_index=False)["granadas_lancadas"].sum()
    pivot_g = ranking_g.pivot(index="nome", columns="categoria_granada", values="granadas_lancadas").fillna(0)

    st.subheader("Granadas lançadas por categoria")
    st.bar_chart(pivot_g)
    st.dataframe(ranking_g.sort_values("granadas_lancadas", ascending=False), use_container_width=True)

with aba_posicionamento:
    ranking_p = posicionamento_f.groupby(["nome", "place"], as_index=False)["segundos_no_local"].sum()
    jogadores = sorted(ranking_p["nome"].unique())
    jogador_sel = st.selectbox("Jogador", jogadores) if jogadores else None

    if jogador_sel:
        st.subheader(f"Tempo por local — {jogador_sel}")
        dados_jogador = ranking_p[ranking_p["nome"] == jogador_sel].sort_values(
            "segundos_no_local", ascending=False)
        st.bar_chart(dados_jogador.set_index("place")["segundos_no_local"])
    st.dataframe(ranking_p.sort_values("segundos_no_local", ascending=False), use_container_width=True)

with aba_bomba:
    ranking_b = bomba_f.groupby(["nome"], as_index=False)["plants"].sum().sort_values(
        "plants", ascending=False)
    st.subheader("Plants de bomba")
    st.bar_chart(ranking_b.set_index("nome")["plants"])
    st.dataframe(ranking_b, use_container_width=True)
