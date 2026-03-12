# Generated migration for Receipt Scanner models and trigram indexes

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # ReceiptScan model
        migrations.CreateModel(
            name='ReceiptScan',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('receipt_image', models.ImageField(upload_to='receipt_scanner/raw/')),
                ('merchant_name', models.CharField(blank=True, max_length=255)),
                ('purchase_date', models.DateField(blank=True, null=True)),
                ('subtotal', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('tax', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('total', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('currency', models.CharField(default='CAD', max_length=8)),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('processing', 'Processing'), ('matching', 'Matching Products'), ('completed', 'Completed'), ('failed', 'Failed')], default='pending', max_length=20)),
                ('extracted_payload', models.JSONField(blank=True, default=dict)),
                ('error_message', models.TextField(blank=True)),
                ('total_savings', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('total_missed_promos', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('matched_items_count', models.PositiveIntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='receipt_scans', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        # ReceiptItem model
        migrations.CreateModel(
            name='ReceiptItem',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('line_number', models.PositiveIntegerField(default=1)),
                ('description', models.CharField(max_length=255)),
                ('normalized_description', models.CharField(blank=True, max_length=255)),
                ('quantity', models.DecimalField(decimal_places=2, default=1, max_digits=8)),
                ('unit_price', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('total_price', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('matched_product_id', models.CharField(blank=True, db_index=True, max_length=36, null=True)),
                ('matched_product_name', models.CharField(blank=True, max_length=255)),
                ('match_confidence', models.CharField(choices=[('high', 'High (>0.8)'), ('medium', 'Medium (0.5-0.8)'), ('low', 'Low (<0.5)'), ('no_match', 'No Match')], default='no_match', max_length=20)),
                ('confidence_score', models.DecimalField(blank=True, decimal_places=4, max_digits=5, null=True)),
                ('database_price', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('saving_per_unit', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('total_saving', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('was_on_promo', models.BooleanField(default=False)),
                ('promo_price', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('missed_savings', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('promo_deal_id', models.CharField(blank=True, max_length=36, null=True)),
                ('scan', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='items', to='receipt_scanner.receiptscan')),
            ],
            options={
                'ordering': ['line_number'],
            },
        ),
        # PriceWatch model
        migrations.CreateModel(
            name='PriceWatch',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('product_id', models.CharField(db_index=True, max_length=36)),
                ('product_name', models.CharField(max_length=255)),
                ('watched_price', models.DecimalField(decimal_places=2, max_digits=10)),
                ('lowest_seen_price', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('is_active', models.BooleanField(default=True)),
                ('notified_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('expires_at', models.DateTimeField()),
                ('receipt_item', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='price_watches', to='receipt_scanner.receiptitem')),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='price_watches', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
                'unique_together': {('user', 'product_id', 'receipt_item')},
            },
        ),
        # UserDevice model
        migrations.CreateModel(
            name='UserDevice',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('fcm_token', models.TextField(unique=True)),
                ('device_type', models.CharField(choices=[('ios', 'iOS'), ('android', 'Android'), ('web', 'Web')], max_length=10)),
                ('device_name', models.CharField(blank=True, max_length=100)),
                ('is_active', models.BooleanField(default=True)),
                ('last_used', models.DateTimeField(auto_now=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='devices', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-last_used'],
            },
        ),
        # Notification model
        migrations.CreateModel(
            name='Notification',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('notification_type', models.CharField(choices=[('price_drop', 'Price Drop Alert'), ('missed_promo', 'Missed Promo Alert'), ('scan_complete', 'Scan Complete'), ('weekly_summary', 'Weekly Summary')], max_length=20)),
                ('title', models.CharField(max_length=255)),
                ('body', models.TextField()),
                ('data', models.JSONField(blank=True, default=dict)),
                ('is_sent', models.BooleanField(default=False)),
                ('sent_at', models.DateTimeField(blank=True, null=True)),
                ('fcm_message_id', models.CharField(blank=True, max_length=255)),
                ('read_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('scheduled_for', models.DateTimeField(blank=True, null=True)),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='notifications', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        # NotificationPreference model
        migrations.CreateModel(
            name='NotificationPreference',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('price_drop_enabled', models.BooleanField(default=True)),
                ('missed_promo_enabled', models.BooleanField(default=True)),
                ('scan_complete_enabled', models.BooleanField(default=True)),
                ('weekly_summary_enabled', models.BooleanField(default=False)),
                ('max_daily_notifications', models.PositiveIntegerField(default=1)),
                ('quiet_start', models.TimeField(blank=True, null=True)),
                ('quiet_end', models.TimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='notification_preferences', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name_plural': 'Notification preferences',
            },
        ),
        # Indexes
        migrations.AddIndex(
            model_name='receiptscan',
            index=models.Index(fields=['user', '-created_at'], name='receipt_sca_user_id_7c8d3e_idx'),
        ),
        migrations.AddIndex(
            model_name='receiptscan',
            index=models.Index(fields=['status'], name='receipt_sca_status_e7b9f2_idx'),
        ),
        migrations.AddIndex(
            model_name='receiptitem',
            index=models.Index(fields=['matched_product_id'], name='receipt_sca_matched_5e4a1f_idx'),
        ),
        migrations.AddIndex(
            model_name='receiptitem',
            index=models.Index(fields=['scan', 'was_on_promo'], name='receipt_sca_scan_id_8f3c2d_idx'),
        ),
        migrations.AddIndex(
            model_name='pricewatch',
            index=models.Index(fields=['user', 'is_active'], name='receipt_sca_user_id_a1b2c3_idx'),
        ),
        migrations.AddIndex(
            model_name='pricewatch',
            index=models.Index(fields=['product_id', 'is_active'], name='receipt_sca_product_d4e5f6_idx'),
        ),
        migrations.AddIndex(
            model_name='pricewatch',
            index=models.Index(fields=['expires_at'], name='receipt_sca_expires_g7h8i9_idx'),
        ),
        migrations.AddIndex(
            model_name='userdevice',
            index=models.Index(fields=['user', 'is_active'], name='receipt_sca_user_id_j1k2l3_idx'),
        ),
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(fields=['user', '-created_at'], name='receipt_sca_user_id_m4n5o6_idx'),
        ),
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(fields=['user', 'is_sent', 'scheduled_for'], name='receipt_sca_user_id_p7q8r9_idx'),
        ),
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(fields=['notification_type'], name='receipt_sca_notific_s1t2u3_idx'),
        ),
    ]
