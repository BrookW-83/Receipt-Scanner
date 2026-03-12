"""
Management command to enable PostgreSQL pg_trgm extension.

This extension is required for trigram similarity matching
used in product matching.

Usage:
    python manage.py enable_pg_trgm
"""

from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = 'Enable the PostgreSQL pg_trgm extension for trigram similarity matching'

    def handle(self, *args, **options):
        with connection.cursor() as cursor:
            # Check if extension exists
            cursor.execute("""
                SELECT EXISTS(
                    SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'
                );
            """)
            exists = cursor.fetchone()[0]

            if exists:
                self.stdout.write(
                    self.style.SUCCESS('pg_trgm extension is already enabled')
                )
                return

            # Try to create extension
            try:
                cursor.execute('CREATE EXTENSION IF NOT EXISTS pg_trgm;')
                self.stdout.write(
                    self.style.SUCCESS('Successfully enabled pg_trgm extension')
                )
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Failed to enable pg_trgm extension: {e}')
                )
                self.stdout.write(
                    self.style.WARNING(
                        'You may need superuser privileges. '
                        'Try running as database admin:\n'
                        '  psql -d your_database -c "CREATE EXTENSION pg_trgm;"'
                    )
                )
