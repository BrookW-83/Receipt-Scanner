# Migration to add GIN indexes for trigram search on products table
# These indexes improve performance of fuzzy product matching

from django.db import migrations


class Migration(migrations.Migration):
    """
    Add GIN trigram indexes to products_product table for improved
    fuzzy matching performance.

    These indexes are created on the grocery_saving database tables
    (replica models). They significantly speed up LIKE and similarity
    queries used in product matching.

    Note: Requires pg_trgm extension to be enabled on the database.
    The indexes are created conditionally to avoid errors if the
    extension is not available.
    """

    dependencies = [
        ('receipt_scanner', '0001_initial'),
    ]

    operations = [
        # Create GIN index on product name (lowercase) for trigram similarity
        migrations.RunSQL(
            sql="""
            DO $$
            BEGIN
                -- Check if pg_trgm extension exists
                IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm') THEN
                    -- Create GIN index on name column for fuzzy matching
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_indexes
                        WHERE indexname = 'products_product_name_trgm_idx'
                    ) THEN
                        CREATE INDEX CONCURRENTLY products_product_name_trgm_idx
                        ON products_product USING GIN (LOWER(name) gin_trgm_ops);
                        RAISE NOTICE 'Created index: products_product_name_trgm_idx';
                    END IF;

                    -- Create GIN index on productname column for fuzzy matching
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_indexes
                        WHERE indexname = 'products_product_productname_trgm_idx'
                    ) THEN
                        CREATE INDEX CONCURRENTLY products_product_productname_trgm_idx
                        ON products_product USING GIN (LOWER(productname) gin_trgm_ops);
                        RAISE NOTICE 'Created index: products_product_productname_trgm_idx';
                    END IF;

                    -- Create GIN index on brand column for fuzzy matching
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_indexes
                        WHERE indexname = 'products_product_brand_trgm_idx'
                    ) THEN
                        CREATE INDEX CONCURRENTLY products_product_brand_trgm_idx
                        ON products_product USING GIN (LOWER(COALESCE(brand, '')) gin_trgm_ops);
                        RAISE NOTICE 'Created index: products_product_brand_trgm_idx';
                    END IF;
                ELSE
                    RAISE NOTICE 'pg_trgm extension not found. Skipping trigram index creation.';
                END IF;
            END $$;
            """,
            reverse_sql="""
            DROP INDEX IF EXISTS products_product_name_trgm_idx;
            DROP INDEX IF EXISTS products_product_productname_trgm_idx;
            DROP INDEX IF EXISTS products_product_brand_trgm_idx;
            """,
        ),
    ]
