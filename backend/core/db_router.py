"""
Database Router for Receipt Scanner

Handles routing for replica models (Product, Deal, Store, Category) that
read from the grocery_saving database.

When merged into the main Grocery app, this router can be removed or
updated to route all models to the same database.
"""


class GrocerySavingRouter:
    """
    Router for handling replica models from grocery_saving database.

    Replica models (managed=False) are routed to 'grocery_saving' database
    if it exists in DATABASES, otherwise fall back to 'default'.

    This ensures compatibility when:
    1. Running standalone with separate databases
    2. Merged into main Grocery app (single database)
    """

    # Models that should read from grocery_saving database
    REPLICA_MODELS = {'category', 'store', 'product', 'deal'}

    # App label for receipt scanner
    RECEIPT_SCANNER_APP = 'receipt_scanner'

    def _is_replica_model(self, model):
        """Check if model is a replica model from grocery_saving."""
        if model._meta.app_label != self.RECEIPT_SCANNER_APP:
            return False
        return model._meta.model_name in self.REPLICA_MODELS

    def _get_grocery_db(self, using):
        """Get the appropriate database for grocery_saving models."""
        from django.conf import settings

        # If explicitly specified, use that
        if using:
            return using

        # Use grocery_saving if configured, else default
        if 'grocery_saving' in settings.DATABASES:
            return 'grocery_saving'
        return 'default'

    def db_for_read(self, model, **hints):
        """Route reads for replica models to grocery_saving database."""
        if self._is_replica_model(model):
            return self._get_grocery_db(hints.get('using'))
        return None

    def db_for_write(self, model, **hints):
        """
        Route writes for replica models.

        Note: Replica models are managed=False, so writes shouldn't happen
        through Django ORM. This is just a safety measure.
        """
        if self._is_replica_model(model):
            return self._get_grocery_db(hints.get('using'))
        return None

    def allow_relation(self, obj1, obj2, **hints):
        """
        Allow relations between receipt_scanner models.

        Since replica models use string IDs (not ForeignKeys), this
        shouldn't be triggered for cross-database relations.
        """
        app1 = obj1._meta.app_label
        app2 = obj2._meta.app_label

        # Allow relations within receipt_scanner app
        if app1 == self.RECEIPT_SCANNER_APP and app2 == self.RECEIPT_SCANNER_APP:
            return True
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        """
        Control migration behavior.

        - Replica models (managed=False) don't migrate anywhere
        - Other receipt_scanner models migrate to default
        """
        if app_label != self.RECEIPT_SCANNER_APP:
            return None

        # Replica models don't get migrations (managed=False)
        if model_name and model_name.lower() in self.REPLICA_MODELS:
            return False

        # Other models go to default database
        return db == 'default'


def get_grocery_saving_connection():
    """
    Get database connection for raw SQL queries against grocery_saving.

    Use this helper in services that need raw SQL:
        from core.db_router import get_grocery_saving_connection
        with get_grocery_saving_connection().cursor() as cursor:
            cursor.execute(...)

    Returns:
        Database connection for grocery_saving (or default if not configured)
    """
    from django.db import connections
    from django.conf import settings

    db_alias = 'grocery_saving' if 'grocery_saving' in settings.DATABASES else 'default'
    return connections[db_alias]
