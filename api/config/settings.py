"""
Configuração do projeto Django. Só usa Django/DRF como framework de API
(rotas, serializers, validação) — não existe ORM pros dados de CS2 (gold é
lida via consultas diretas no DuckDB contra os Parquet exportados, ver
cs2api/duckdb_consulta.py). Por isso não há apps de ORM instalados
(auth/admin/sessions) nem se roda `migrate` — ver CLAUDE.md, seção "API de
consumo".
"""

import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
PROJECT_ROOT = BASE_DIR.parent

load_dotenv(BASE_DIR / ".env")

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-only-nao-usar-em-producao")
DEBUG = os.environ.get("DJANGO_DEBUG", "true").lower() == "true"
ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "*").split(",")

INSTALLED_APPS = [
    "django.contrib.staticfiles",  # necessário só pra servir o CSS da browsable API do DRF
    "rest_framework",
    "cs2api",
]

MIDDLEWARE = [
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {"context_processors": []},
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# Não usado por nenhum app instalado (sem ORM pros dados de CS2) — existe só
# porque Django exige a chave DATABASES em settings.py. Nunca se roda
# `manage.py migrate`.
DATABASES = {}

USE_TZ = True
STATIC_URL = "static/"

REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ],
    # Sem auth/contenttypes instalados (não há ORM pros dados de CS2 — ver
    # topo do arquivo), então a autenticação por sessão do DRF (que resolve
    # request.user via django.contrib.auth) não pode ser usada aqui.
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.AllowAny"],
    "UNAUTHENTICATED_USER": None,
}

# --- Caminhos do lado do pipeline de dados (fora da pasta api/) ---
# API_UPLOADS_DIR (não DEMOS_DIR!) é onde o upload via API grava e depois
# descarta o(s) .dem — pasta isolada de propósito, nunca demos/. Já
# aconteceu de um upload de teste usar o mesmo evento/fase/nome de arquivo
# de uma demo real que o usuário já tinha em demos/, sobrescrevendo e
# depois apagando o arquivo original dele (a task só sabe "descartar o que
# processei", não sabe distinguir "vim eu" de "já existia aqui"). Mantendo
# os uploads da API numa árvore própria, essa colisão nunca mais acontece,
# estruturalmente — não depende de convenção de nome.
DEMOS_DIR = str(PROJECT_ROOT / "demos")
API_UPLOADS_DIR = str(PROJECT_ROOT / "api_uploads")
PARQUET_GOLD_DIR = str(PROJECT_ROOT / "output" / "parquet" / "gold")
INGESTION_DIR = str(PROJECT_ROOT / "ingestion")

# --- Redis: cache (TTL simples, sem invalidação ativa — decisão registrada
# no CLAUDE.md) e broker/result-backend do Celery (upload assíncrono de demo) ---
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
CACHE_TTL_SEGUNDOS = int(os.environ.get("CACHE_TTL_SEGUNDOS", "1800"))  # 30min

CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": REDIS_URL,
        "OPTIONS": {"CLIENT_CLASS": "django_redis.client.DefaultClient"},
        "TIMEOUT": CACHE_TTL_SEGUNDOS,
    }
}

CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", REDIS_URL)
CELERY_RESULT_BACKEND = os.environ.get("CELERY_RESULT_BACKEND", REDIS_URL)
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]
