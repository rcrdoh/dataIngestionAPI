"""Restore Lambda — repopulate PostgreSQL tables from the latest AVRO backup.

Accepts an optional JSON body:
    { "backup_id": "20250101T120000Z" }   — restore a specific backup
    {}                                      — restore the latest backup

For each table (in FK-safe order: departments → jobs → hired_employees):
  1. Download the AVRO file from S3.
  2. DELETE all rows from the table.
  3. INSERT rows from the AVRO file.

Children tables (hired_employees) are cleared BEFORE parents to avoid
FK constraint violations during the truncate phase.
"""

import io
import logging

import fastavro

from common import json_response, get_db_connection
from backup_common import (
    AVRO_SCHEMAS,
    TABLE_ORDER,
    S3_BACKUP_BUCKET,
    s3_client,
    latest_backup_id,
    s3_key,
)

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def _download_avro(backup_id, table_name):
    """Download an AVRO file from S3 and return parsed records."""
    key = s3_key(backup_id, table_name)
    resp = s3_client.get_object(Bucket=S3_BACKUP_BUCKET, Key=key)
    buf = io.BytesIO(resp['Body'].read())
    reader = fastavro.reader(buf)
    return list(reader)


def lambda_handler(event, context):
    conn = None
    try:
        # Determine which backup to restore
        body = {}
        if event.get('body'):
            import json
            body = json.loads(event['body'])

        backup_id = body.get('backup_id') or latest_backup_id()
        if not backup_id:
            return json_response(404, {'error': 'No backups found in S3'})

        logger.info(f'Restoring from backup {backup_id}')

        conn = get_db_connection()
        cur = conn.cursor()

        results = {}

        # DELETE in reverse FK order (children first), INSERT in forward order.
        delete_order = list(reversed(TABLE_ORDER))

        # Phase 1 — truncate all tables (children first)
        for table_name in delete_order:
            try:
                cur.execute(f'DELETE FROM {table_name}')
                logger.info(f'Truncated {table_name}')
            except Exception as del_err:
                logger.warning(f'Could not truncate {table_name}: {del_err}')
                conn.rollback()

        conn.commit()

        # Phase 2 — insert from AVRO (parents first)
        restored = 0
        for table_name in TABLE_ORDER:
            try:
                records = _download_avro(backup_id, table_name)
            except s3_client.exceptions.NoSuchKey:
                results[table_name] = {'status': 'skipped', 'reason': 'no AVRO file in this backup'}
                logger.info(f'No AVRO file for {table_name} in backup {backup_id} — skipped')
                continue
            except Exception as dl_err:
                results[table_name] = {'status': 'error', 'reason': str(dl_err)}
                logger.error(f'Error downloading AVRO for {table_name}: {dl_err}')
                continue

            if not records:
                results[table_name] = {'status': 'skipped', 'reason': 'AVRO file is empty'}
                continue

            # Build INSERT from the AVRO record fields
            columns = list(records[0].keys())
            placeholders = ', '.join(['%s'] * len(columns))
            col_list = ', '.join(columns)
            insert_sql = f'INSERT INTO {table_name} ({col_list}) VALUES ({placeholders})'

            for record in records:
                values = [record[c] for c in columns]
                cur.execute(insert_sql, values)

            conn.commit()
            results[table_name] = {'status': 'restored', 'rows': len(records)}
            restored += 1
            logger.info(f'Table {table_name}: {len(records)} rows restored')

        return json_response(200, {
            'message': f'Restore completed from backup {backup_id} — {restored} table(s) restored',
            'backup_id': backup_id,
            'tables': results,
        })

    except Exception as exc:
        logger.error(f'Restore failed: {exc}')
        if conn:
            conn.rollback()
        return json_response(500, {'error': f'Restore failed: {exc}'})
    finally:
        if conn:
            conn.close()
