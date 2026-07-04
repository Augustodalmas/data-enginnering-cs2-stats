import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

app = Celery("cs2api")
# Lê CELERY_* de settings.py (broker/backend Redis, ver settings.py).
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
