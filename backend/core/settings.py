from pathlib import Path
import os
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / '.env')

SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
DEBUG = os.getenv('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '127.0.0.1,localhost').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # PostgreSQL extensions
    'django.contrib.postgres',
    # Third party
    'rest_framework',
    'django_filters',
    'django_celery_beat',
    # Local
    'receipt_scanner',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'core.wsgi.application'

# =============================================================================
# DATABASE
# =============================================================================

DB_ENGINE = os.getenv('DB_ENGINE', 'django.db.backends.sqlite3')
DB_NAME = os.getenv('DB_NAME', 'db.sqlite3')

if DB_ENGINE == 'django.db.backends.sqlite3':
    DATABASES = {
        'default': {
            'ENGINE': DB_ENGINE,
            'NAME': BASE_DIR / DB_NAME,
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': DB_ENGINE,
            'NAME': DB_NAME,
            'USER': os.getenv('DB_USER', ''),
            'PASSWORD': os.getenv('DB_PASSWORD', ''),
            'HOST': os.getenv('DB_HOST', ''),
            'PORT': os.getenv('DB_PORT', ''),
        }
    }

# Optional: Add grocery_saving database for replica models
# When merging into main Grocery app, this can be removed
GROCERY_SAVING_DB_NAME = os.getenv('GROCERY_SAVING_DB_NAME')
if GROCERY_SAVING_DB_NAME:
    DATABASES['grocery_saving'] = {
        'ENGINE': os.getenv('GROCERY_SAVING_DB_ENGINE', DB_ENGINE),
        'NAME': GROCERY_SAVING_DB_NAME,
        'USER': os.getenv('GROCERY_SAVING_DB_USER', os.getenv('DB_USER', '')),
        'PASSWORD': os.getenv('GROCERY_SAVING_DB_PASSWORD', os.getenv('DB_PASSWORD', '')),
        'HOST': os.getenv('GROCERY_SAVING_DB_HOST', os.getenv('DB_HOST', '')),
        'PORT': os.getenv('GROCERY_SAVING_DB_PORT', os.getenv('DB_PORT', '')),
    }

# Database routers for multi-database support
# Routes replica models (Product, Deal, Store, Category) to grocery_saving
DATABASE_ROUTERS = ['core.db_router.GrocerySavingRouter']

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = os.getenv('MEDIA_URL', '/media/')
MEDIA_ROOT = BASE_DIR / os.getenv('MEDIA_ROOT', 'media/')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# =============================================================================
# REST FRAMEWORK
# =============================================================================

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.AllowAny',
    ),
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
    ),
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/hour',
        'receipt_upload': '3/hour',
    },
}

# =============================================================================
# CELERY
# =============================================================================

CELERY_BROKER_URL = os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0')
CELERY_RESULT_BACKEND = os.getenv('CELERY_RESULT_BACKEND', CELERY_BROKER_URL)

# Celery Beat schedule for periodic tasks
CELERY_BEAT_SCHEDULE = {
    'check-price-drops-daily': {
        'task': 'receipt_scanner.tasks.check_price_drops_task',
        'schedule': 60 * 60 * 24,  # Every 24 hours (or use crontab)
    },
    'send-pending-notifications': {
        'task': 'receipt_scanner.tasks.send_pending_notifications_task',
        'schedule': 60 * 30,  # Every 30 minutes
    },
    'cleanup-expired-watches': {
        'task': 'receipt_scanner.tasks.cleanup_expired_price_watches_task',
        'schedule': 60 * 60 * 24,  # Every 24 hours
    },
}

# Use django-celery-beat for database-backed scheduling
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'

# =============================================================================
# GEMINI AI
# =============================================================================

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

# =============================================================================
# FIREBASE
# =============================================================================

# Path to Firebase Admin SDK credentials JSON file
FIREBASE_CREDENTIALS_PATH = os.getenv('FIREBASE_CREDENTIALS_PATH')

# =============================================================================
# LOGGING
# =============================================================================

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'receipt_scanner': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}
