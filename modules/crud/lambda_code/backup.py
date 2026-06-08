"""Backup Lambda — export PostgreSQL tables to AVRO files in S3.

For each table (departments, jobs, hired_employees):
  1. Check if the table has at least one row.
  2. If empty, skip and report.
  3. Otherwise SELECT all rows, write to AVRO, upload to S3.

Returns a JSON response with the backup_id and per-table status.
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
    generate_backup_id,
    s3_key,
)

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def _table_has_rows(cur, table_name):
    cur.execute(f'SELECT EXISTS(SELECT 1 FROM {table_name} LIMIT 1)')
    return cur.fetchone()[0]


def _fetch_all(cur, table_name):
    cur.execute(f'SELECT * FROM {table_name}')
    columns = [desc[0] for desc in cur.description]
    return columns, cur.fetchall()


def _rows_to_avro_bytes(schema, columns, rows):
    """Serialize rows (list of tuples) into AVRO binary bytes."""
    records = []
    for row in rows:
        record = {}
        for col, val in zip(columns, row):
            # Convert non-serializable types to string
            if val is not None and not isinstance(val, (int, float, str, bool)):
                val = str(val)
            record[col] = val
        records.append(record)

    buf = io.BytesIO()
    fastavro.writer(buf, schema, records)
    return buf.getvalue()


def lambda_handler(event, context):
    conn = None
    try:
        backup_id = generate_backup_id()
        logger.info(f'Starting backup {backup_id}')

        conn = get_db_connection()
        cur = conn.cursor()

        results = {}
        backed_up = 0

        for table_name in TABLE_ORDER:
            if not _table_has_rows(cur, table_name):
                results[table_name] = {'status': 'skipped', 'reason': 'table is empty'}
                logger.info(f'Table {table_name} is empty — skipped')
                continue

            columns, rows = _fetch_all(cur, table_name)
            schema = AVRO_SCHEMAS[table_name]
            avro_bytes = _rows_to_avro_bytes(schema, columns, rows)

            key = s3_key(backup_id, table_name)
            s3_client.put_object(
                Bucket=S3_BACKUP_BUCKET,
                Key=key,
                Body=avro_bytes,
                ContentType='application/avro-binary',
            )

            results[table_name] = {
                'status': 'backed_up',
                'rows': len(rows),
                's3_key': key,
            }
            backed_up += 1
            logger.info(f'Table {table_name}: {len(rows)} rows → s3://{S3_BACKUP_BUCKET}/{key}')

        return json_response(200, {
            'message': f'Backup completed — {backed_up} table(s) backed up',
            'backup_id': backup_id,
            'tables': results,
        })

    except Exception as exc:
        logger.error(f'Backup failed: {exc}')
        return json_response(500, {'error': f'Backup failed: {exc}'})
    finally:
        if conn:
            conn.close()
