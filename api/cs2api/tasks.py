"""
Tasks Celery que processam em background o upload de demo(s): extração de
.zip (se for o caso), parse e carga na bronze, depois descarte do(s)
arquivo(s) .dem. Roda num worker separado (não no processo da API).

**Tudo que envolve I/O pesado roda aqui, nunca na view** — inclusive a
extração do .zip. Isso não é só o parse (minutos): reproduzido na prática
que só a extração de um .zip com demos de ~300-400MB cada, rodando
síncrono na view, já estourava o timeout padrão do Gunicorn (30s) e
derrubava o worker com "WORKER TIMEOUT" (500 pro cliente) — ver CLAUDE.md,
seção "API de consumo".

Reusa a função carregar_demo (parse + idempotência + merge de partes -pN)
já usada pela ingestão manual via CLI, em vez de duplicar essa lógica. Os
arquivos são gravados em settings.API_UPLOADS_DIR/<evento>/<fase>/ (NÃO em
settings.DEMOS_DIR!) — árvore isolada e efêmera, específica pra upload via
API. **Isso é obrigatório, não estético**: já aconteceu de um upload de
teste usar o mesmo evento/fase/nome de arquivo de uma demo real que o
usuário mantinha manualmente em demos/, sobrescrevendo o arquivo original
e depois apagando ele no descarte pós-processamento (a lógica de descarte
só sabe "apagar o que processei", não distingue "vim de um upload" de "já
existia aqui"). Como derivar_match_id_e_parte (cs2_utils.py) deriva o
match_id a partir do caminho relativo a um "pasta_demos" — e
carregar_demo_duckdb usa esse valor como constante de módulo fixa em
demos/ — a task troca essa constante (carregar_demo_duckdb.PASTA_DEMOS)
para API_UPLOADS_DIR antes de qualquer chamada; seguro porque o worker
roda com --concurrency=1 (processa 1 job por vez) e essa troca só importa
para os uploads via API, nunca para a ingestão manual via CLI (processo
Python separado, com sua própria cópia do módulo).
"""

import os
import shutil
import sys
import zipfile

from celery import shared_task
from django.conf import settings

if settings.INGESTION_DIR not in sys.path:
    sys.path.insert(0, settings.INGESTION_DIR)

# Mesma whitelist de nome de arquivo usada na view (path traversal / nome
# inesperado) — duplicada aqui de propósito: a view não faz mais parsing
# de conteúdo de zip (só valida a extensão do upload), quem abre e confia
# nos nomes internos do zip é o worker.
NOME_ARQUIVO_VALIDO_REGEX = r"^[A-Za-z0-9_-]+\.dem$"
MAX_ENTRADAS_ZIP = 200


def _usar_pasta_de_uploads_da_api():
    """
    Aponta carregar_demo_duckdb.PASTA_DEMOS pra settings.API_UPLOADS_DIR em
    vez de demos/ (ver docstring do módulo — protege as demos reais do
    usuário de serem apagadas pelo descarte pós-processamento).
    """
    import carregar_demo_duckdb

    carregar_demo_duckdb.PASTA_DEMOS = settings.API_UPLOADS_DIR
    return carregar_demo_duckdb


@shared_task(bind=True, name="cs2api.processar_upload_demo")
def processar_upload_demo(self, caminho_arquivo, forcar=False):
    resultado = _processar_um_match(caminho_arquivo, forcar)
    return resultado


@shared_task(bind=True, name="cs2api.processar_upload_zip")
def processar_upload_zip(self, caminho_zip, pasta_destino, forcar=False):
    import re

    padrao_nome = re.compile(NOME_ARQUIVO_VALIDO_REGEX)

    caminhos_salvos = []
    rejeitados = []

    with zipfile.ZipFile(caminho_zip) as zf:
        entradas = [info for info in zf.infolist() if not info.is_dir()]
        if len(entradas) > MAX_ENTRADAS_ZIP:
            os.remove(caminho_zip)
            raise ValueError(f"zip com mais de {MAX_ENTRADAS_ZIP} arquivos, recusado.")

        for info in entradas:
            nome_base = os.path.basename(info.filename)
            if not nome_base.lower().endswith(".dem"):
                continue  # ignora o que não é demo (ex.: README dentro do zip)
            if not padrao_nome.match(nome_base):
                rejeitados.append(info.filename)
                continue

            caminho_extraido = os.path.join(pasta_destino, nome_base)
            with zf.open(info) as origem, open(caminho_extraido, "wb") as destino:
                shutil.copyfileobj(origem, destino)
            caminhos_salvos.append(caminho_extraido)

    os.remove(caminho_zip)

    partidas = []
    if caminhos_salvos:
        carregar_demo_duckdb = _usar_pasta_de_uploads_da_api()
        from cs2_utils import derivar_match_id_e_parte

        grupos = {}
        for caminho in caminhos_salvos:
            match_id, _ = derivar_match_id_e_parte(caminho, carregar_demo_duckdb.PASTA_DEMOS)
            grupos.setdefault(match_id, []).append(caminho)

        # Processadas em sequência (não sub-tasks paralelas): o worker já
        # roda com --concurrency=1 por causa do limite de 1 escritor por
        # vez do DuckDB (ver docker-compose.yml) -- paralelizar aqui não
        # ganharia nada, só complicaria o rastreio de resultado.
        for match_id, caminhos_do_grupo in grupos.items():
            try:
                resultado = _processar_um_match(caminhos_do_grupo[0], forcar)
                partidas.append({"match_id": match_id, "status": "ok", **resultado})
            except Exception as exc:  # noqa: BLE001 -- reportado no resultado, não deve abortar as demais partidas do lote
                partidas.append({"match_id": match_id, "status": "erro", "erro": str(exc)})

    return {"partidas": partidas, "arquivos_rejeitados": rejeitados}


def _processar_um_match(caminho_arquivo, forcar):
    """
    Carrega uma partida (parse + idempotência + merge de partes -pN, via
    carregar_demo) e descarta o(s) arquivo(s) .dem dela depois. Usada tanto
    pelo upload de .dem único quanto, em loop, pelo upload em lote (.zip).
    """
    carregar_demo_duckdb = _usar_pasta_de_uploads_da_api()
    from cs2_utils import encontrar_partes_do_match

    pasta_uploads = carregar_demo_duckdb.PASTA_DEMOS
    # Calculado antes de carregar: depois de carregado, ainda precisamos
    # saber quais arquivos (pode ser mais de um, se for uma partida
    # dividida em -p1/-p2/...) apagar.
    caminhos_partes = encontrar_partes_do_match(caminho_arquivo, pasta_uploads)

    carregar_demo_duckdb.carregar_demo(caminho_arquivo, forcar=forcar)

    for caminho in caminhos_partes:
        if os.path.isfile(caminho):
            os.remove(caminho)
    _remover_pastas_vazias(os.path.dirname(caminho_arquivo), pasta_uploads)

    return {
        "arquivos_removidos": caminhos_partes,
        "status": "carregado_na_bronze_e_arquivo_descartado",
    }


def _remover_pastas_vazias(pasta_fase, pasta_raiz):
    """
    Remove api_uploads/<evento>/<fase>/ e api_uploads/<evento>/ se ficarem
    vazias após o descarte do(s) .dem. Nunca remove pastas que ainda têm
    arquivos — protege uploads concorrentes de outras partidas do mesmo
    evento/fase que ainda estejam em processamento.
    """
    pasta_atual = os.path.normpath(pasta_fase)
    raiz = os.path.normpath(pasta_raiz)

    while pasta_atual != raiz and pasta_atual.startswith(raiz):
        if os.path.isdir(pasta_atual) and not os.listdir(pasta_atual):
            os.rmdir(pasta_atual)
            pasta_atual = os.path.dirname(pasta_atual)
        else:
            break
