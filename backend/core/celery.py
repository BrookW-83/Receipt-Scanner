import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

app = Celery('core')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

# Route receipt_scanner tasks to dedicated queue
app.conf.task_routes = {
    'receipt_scanner.tasks.*': {'queue': 'receipt_scanner'},
}
