"""
Endpoint de escrita: upload de demo(s). Aceita um único `.dem` ou um `.zip`
com uma ou mais `.dem` dentro (inclusive as partes -p1/-p2/... de uma
mesma partida dividida — resolve o problema de partes incompletas: com
upload de arquivo único, se as partes chegassem em POSTs separados, o
primeiro disparava o processamento sem a segunda parte ainda existir).

A view só grava o arquivo recebido em disco (rápido: é 1 write sequencial)
e enfileira — **nunca abre o .zip aqui**. Extrair um .zip grande (várias
demos de ~300-400MB cada) é I/O pesado o bastante pra estourar sozinho o
timeout do Gunicorn se rodasse dentro da request (reproduzido na prática:
"WORKER TIMEOUT" / 500 pro cliente) — ver tasks.py e CLAUDE.md, seção "API
de consumo". Toda a extração, parse e carga na bronze rodam no worker
Celery.

Grava em settings.API_UPLOADS_DIR (não settings.DEMOS_DIR!) — árvore
isolada, nunca a mesma pasta que o usuário usa pra guardar demos
manualmente. Já aconteceu de um upload de teste usar o mesmo
evento/fase/nome de arquivo de uma demo real do usuário, sobrescrevendo
e depois apagando o arquivo original dele (o worker só sabe "descartar o
que processei", não distingue "vim eu" de "já existia aqui").
"""

import os
import re

from celery.result import AsyncResult
from django.conf import settings
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .tasks import processar_upload_demo, processar_upload_zip

# Só letras/números/hífen/underscore — sem barra nem "..", pra evento/fase
# nunca poderem escapar de demos/<evento>/<fase>/ (path traversal).
NOME_PASTA_VALIDO = re.compile(r"^[A-Za-z0-9_-]+$")
NOME_ARQUIVO_VALIDO = re.compile(r"^[A-Za-z0-9_-]+\.dem$")


class UploadDemoView(APIView):
    """
    POST multipart/form-data:
      evento   (obrigatório) ex.: "iem-cologne-major-2026"
      fase     (obrigatório) ex.: "semi-final"
      arquivo  (obrigatório) um .dem OU um .zip contendo uma ou mais .dem
      forcar   (opcional, "true"/"false") recarrega mesmo se o match_id já
               existir na bronze — mesmo efeito da flag --forcar da CLI

    Responde 202 com 1 job_id na hora — o parse (e, se for .zip, a
    extração) rodam em background, ver tasks.py. Consultar o andamento em
    GET /api/demos/status/<job_id>/. Se for .zip com mais de uma partida,
    o resultado desse job único traz o resumo de todas elas (ver
    tasks.processar_upload_zip).
    """

    parser_classes = [MultiPartParser]

    def post(self, request):
        evento = request.data.get("evento", "").strip()
        fase = request.data.get("fase", "").strip()
        arquivo = request.FILES.get("arquivo")
        forcar = str(request.data.get("forcar", "false")).lower() == "true"

        erros = self._validar_campos(evento, fase, arquivo)
        if erros:
            return Response({"erros": erros}, status=400)

        # API_UPLOADS_DIR, não settings.DEMOS_DIR -- nunca escrever na mesma
        # árvore que o usuário usa pra guardar demos manualmente (ver
        # settings.py: já aconteceu de sobrescrever e depois apagar um
        # arquivo real do usuário por colisão de evento/fase/nome).
        pasta_destino = os.path.join(settings.API_UPLOADS_DIR, evento, fase)
        os.makedirs(pasta_destino, exist_ok=True)
        caminho_destino = os.path.join(pasta_destino, arquivo.name)

        with open(caminho_destino, "wb") as destino:
            for pedaco in arquivo.chunks():
                destino.write(pedaco)

        eh_zip = arquivo.name.lower().endswith(".zip")
        if eh_zip:
            job = processar_upload_zip.delay(caminho_destino, pasta_destino, forcar)
        else:
            job = processar_upload_demo.delay(caminho_destino, forcar)

        return Response(
            {
                "job_id": job.id,
                "tipo": "zip" if eh_zip else "dem",
                "status": "enfileirado",
                "consultar_status_em": f"/api/demos/status/{job.id}/",
                "aviso": (
                    "este POST carrega só até a camada bronze. Pra aparecer nos "
                    "endpoints GET (que leem gold exportada em Parquet), ainda é "
                    "preciso rodar manualmente 'dbt build' e "
                    "'ingestion/exportar_gold_parquet.py' depois do job terminar "
                    "(ver api/README.md)."
                ),
            },
            status=202,
        )

    @staticmethod
    def _validar_campos(evento, fase, arquivo):
        erros = {}
        if not evento:
            erros["evento"] = "obrigatório."
        elif not NOME_PASTA_VALIDO.match(evento):
            erros["evento"] = "só letras, números, hífen e underscore."

        if not fase:
            erros["fase"] = "obrigatório."
        elif not NOME_PASTA_VALIDO.match(fase):
            erros["fase"] = "só letras, números, hífen e underscore."

        if not arquivo:
            erros["arquivo"] = "obrigatório (.dem ou .zip)."
        elif not (arquivo.name.lower().endswith(".zip") or NOME_ARQUIVO_VALIDO.match(arquivo.name)):
            erros["arquivo"] = (
                "esperado *.dem (nome só com letras/números/hífen/underscore) ou *.zip."
            )

        return erros


class StatusJobView(APIView):
    """GET /api/demos/status/<job_id>/ — status de um job enfileirado por UploadDemoView."""

    def get(self, request, job_id):
        resultado = AsyncResult(job_id)
        payload = {"job_id": job_id, "status": resultado.status}
        if resultado.status == "SUCCESS":
            payload["resultado"] = resultado.result
            payload["aviso"] = (
                "carregado na bronze. Rode 'dbt build' e "
                "'ingestion/exportar_gold_parquet.py' pra aparecer nos GETs."
            )
        elif resultado.status == "FAILURE":
            payload["erro"] = str(resultado.result)
        return Response(payload)
