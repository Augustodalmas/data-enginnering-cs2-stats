# Imagem única usada tanto pelo serviço da API (gunicorn) quanto pelo worker
# Celery (docker-compose.yml só troca o CMD) — mais simples de manter que
# duas imagens pra um projeto deste porte.
#
# Build context é a raiz do repo (não api/), porque a imagem também precisa
# de ingestion/ (cs2api/tasks.py importa carregar_demo_duckdb pra processar
# o upload de demo, reusando a mesma função da CLI — ver CLAUDE.md).
FROM python:3.11-slim

WORKDIR /app

# build-essential: awpy/pyarrow podem precisar compilar extensões nativas
# dependendo da plataforma da imagem base.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY api/requirements.txt ./api/requirements.txt
RUN pip install --no-cache-dir -r api/requirements.txt

COPY api/ ./api/
COPY ingestion/ ./ingestion/

WORKDIR /app/api

EXPOSE 8000

# --timeout 300 (padrão do gunicorn é 30s): mesmo com o parse/extração de
# zip rodando no worker Celery (nunca na request, ver tasks.py), a própria
# leitura do corpo da request (o upload em si, escrito em disco na view)
# pode passar de 30s pra um .dem/.zip grande (centenas de MB) numa conexão
# lenta -- reproduzido na prática ("WORKER TIMEOUT", 500 pro cliente) antes
# dessa mudança.
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", \
     "--timeout", "300", "--access-logfile", "-", "--error-logfile", "-"]
