"""Shared helpers for backup / restore Lambdas.

Defines AVRO schemas (matching the PostgreSQL tables) and S3 path
conventions for storing backup files.
"""

import os
from datetime import datetime, timezone

import boto3

S3_BACKUP_BUCKET = os.environ.get('BACKUP_BUCKET', '')
S3_PREFIX = 'backups'  # top-level key prefix inside the bucket

s3_client = boto3.client('s3')

# ── AVRO schemas ─────────────────────────────────────────────────────────────
# Each schema mirrors the PostgreSQL table definition from sampleData/init.sql.

AVRO_SCHEMAS = {
    'departments': {
        'type': 'record',
        'name': 'Department',
        'namespace': 'com.crud.backup',
        'fields': [
            {'name': 'id',         'type': 'int'},
            {'name': 'department', 'type': 'string'},
        ],
    },
    'jobs': {
        'type': 'record',
        'name': 'Job',
        'namespace': 'com.crud.backup',
        'fields': [
            {'name': 'id',  'type': 'int'},
            {'name': 'job', 'type': 'string'},
        ],
    },
    'hired_employees': {
        'type': 'record',
        'name': 'HiredEmployee',
        'namespace': 'com.crud.backup',
        'fields': [
            {'name': 'id',            'type': 'int'},
            {'name': 'name',          'type': 'string'},
            {'name': 'datetime',      'type': 'string'},
            {'name': 'department_id', 'type': 'int'},
            {'name': 'job_id',        'type': 'int'},
        ],
    },
}

# Ordered so that FK parents are processed before children.
TABLE_ORDER = ['departments', 'jobs', 'hired_employees']


# ── S3 path helpers ──────────────────────────────────────────────────────────

def generate_backup_id():
    """Return a backup identifier based on the current UTC timestamp."""
    return datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')


def s3_key(backup_id, table_name):
    """Return the S3 object key for a given backup + table."""
    return f'{S3_PREFIX}/{backup_id}/{table_name}.avro'


def list_backup_ids():
    """Return a sorted list (newest first) of backup IDs found in S3."""
    paginator = s3_client.get_paginator('list_objects_v2')
    ids = set()
    for page in paginator.paginate(Bucket=S3_BACKUP_BUCKET, Prefix=f'{S3_PREFIX}/', Delimiter='/'):
        for prefix in page.get('CommonPrefixes', []):
            # prefix['Prefix'] looks like "backups/20250101T120000Z/"
            parts = prefix['Prefix'].rstrip('/').split('/')
            if len(parts) >= 2:
                ids.add(parts[-1])
    return sorted(ids, reverse=True)


def latest_backup_id():
    """Return the most recent backup ID, or None."""
    ids = list_backup_ids()
    return ids[0] if ids else None
