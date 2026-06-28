# -*- coding: utf-8 -*-
"""
Funções utilitárias reutilizáveis para trabalhar com demos de CS2
parseadas pela lib awpy. Começando pela conversão de tick -> segundos.
"""

import os
import re

# Sufixo de parte no nome do arquivo (ex.: "g2-vs-spirit-m3-mirage-p1").
PADRAO_SUFIXO_PARTE = re.compile(r"^(?P<base>.+)-p(?P<parte>\d+)$")


def detectar_taxa_de_tick(dem):
    """
    Detecta a taxa real de ticks/segundo de uma demo já parseada.

    Não usamos dem.tickrate porque ele reflete a configuração do servidor,
    que pode não corresponder à taxa real de gravação da demo (ex.: demos
    GOTV/SourceTV podem gravar a uma taxa menor que o servidor real).

    A taxa real é calculada comparando o tempo de freeze configurado
    (cvar mp_freezetime, em segundos) com a quantidade de ticks observada
    entre o início do round 1 e o fim do freeze desse round.
    """
    cvars = dem.server_cvars.to_pandas()
    freezetime_segundos = cvars[cvars["name"] == "mp_freezetime"]["value"].astype(float).iloc[0]

    rounds = dem.rounds.to_pandas()
    primeiro_round = rounds.iloc[0]
    ticks_de_freeze = primeiro_round["freeze_end"] - primeiro_round["start"]

    return ticks_de_freeze / freezetime_segundos


def tick_para_segundos(tick, taxa_de_tick):
    """Converte um valor (ou uma série/coluna) de tick para segundos."""
    return tick / taxa_de_tick


def derivar_match_id_e_parte(caminho_demo, pasta_demos):
    """
    Deriva o match_id e o número da parte a partir do caminho do .dem.

    match_id é o caminho relativo a pasta_demos, sem extensão e sem o
    sufixo -pN (ex.: "iem-katowice-2026/quarterfinal/g2-vs-spirit-m3-mirage").
    Exige que os .dem estejam organizados em subpastas por evento/fase
    dentro de pasta_demos — duas partidas com mesmos times/mapa em
    campeonatos ou fases diferentes só ficam com match_id distinto se
    estiverem em subpastas distintas.

    Arquivos sem sufixo -pN são tratados como parte 1 (partida não dividida).
    """
    caminho_relativo = os.path.relpath(caminho_demo, pasta_demos)
    caminho_sem_ext, _ = os.path.splitext(caminho_relativo)
    caminho_sem_ext = caminho_sem_ext.replace(os.sep, "/")

    match = PADRAO_SUFIXO_PARTE.match(caminho_sem_ext)
    if match:
        return match.group("base"), int(match.group("parte"))
    return caminho_sem_ext, 1


def encontrar_partes_do_match(caminho_demo, pasta_demos):
    """
    Encontra todos os arquivos .dem da mesma pasta que pertencem à mesma
    partida que caminho_demo (mesmo match_id, sufixos -p1/-p2/... diferentes),
    devolvidos em ordem de parte. Se caminho_demo não tiver sufixo -pN,
    devolve só ele mesmo.
    """
    match_id, _ = derivar_match_id_e_parte(caminho_demo, pasta_demos)
    pasta = os.path.dirname(caminho_demo)

    partes = []
    for nome_arquivo in os.listdir(pasta):
        if not nome_arquivo.endswith(".dem"):
            continue
        caminho_candidato = os.path.join(pasta, nome_arquivo)
        match_id_candidato, numero_parte = derivar_match_id_e_parte(
            caminho_candidato, pasta_demos)
        if match_id_candidato == match_id:
            partes.append((numero_parte, caminho_candidato))

    partes.sort(key=lambda item: item[0])
    return [caminho for _, caminho in partes]
