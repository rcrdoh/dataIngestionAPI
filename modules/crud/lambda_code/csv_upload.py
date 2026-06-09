import csv
import io
import base64
import logging
from common import json_response, get_db_connection

logger = logging.getLogger()
logger.setLevel(logging.INFO)

MAX_ROWS = 1000

# Supported schema field types for validation/coercion
TYPE_COERCERS = {
    'str':      lambda v: str(v),
    'int':      lambda v: int(v),
    'float':    lambda v: float(v),
    'date':     lambda v: str(v),   # stored as-is (YYYY-MM-DD)
    'datetime': lambda v: str(v),   # stored as-is (ISO 8601: YYYY-MM-DDTHH:MM:SS)
}


def validate_schema(csv_headers, schema):
    """Validate that the CSV headers match the expected schema.

    Returns (is_valid: bool, error_message: str|None).
    """
    expected = [col['name'] for col in schema]

    if len(csv_headers) != len(expected):
        return False, (
            f'Expected {len(expected)} columns {expected}, '
            f'got {len(csv_headers)}: {csv_headers}'
        )

    for i, (got, want) in enumerate(zip(csv_headers, expected)):
        if got.strip().lower() != want.lower():
            return False, (
                f'Column {i+1} mismatch: expected "{want}", got "{got}". '
                f'Full expected: {expected}'
            )

    return True, None


def coerce_row(row_values, schema):
    """Coerce a list of string values to the types defined in schema.

    Returns (coerced_values: list, error: str|None).
    """
    coerced = []
    for i, (value, col) in enumerate(zip(row_values, schema)):
        col_name = col['name']
        col_type = col.get('type', 'str')
        value = value.strip()

        # Allow empty strings for nullable columns
        if value == '' and col.get('nullable', True):
            coerced.append(None)
            continue

        try:
            coerced.append(TYPE_COERCERS[col_type](value))
        except (ValueError, TypeError) as e:
            return None, f'Row value error at column "{col_name}": {value!r} is not a valid {col_type} ({e})'

    return coerced, None


def handle_csv_upload(event, pg_table, schema):
    """Parse CSV from the request body, validate against schema, and
    insert rows into a PostgreSQL table.

    Args:
        event:     API Gateway proxy event
        pg_table:  PostgreSQL table name (str)
        schema:    list of dicts, e.g. [{'name': 'col', 'type': 'str', 'nullable': True}, ...]

    Returns a standard API Gateway proxy response via ``json_response``.
    """

    # Validate content type
    headers_map = {k.lower(): v for k, v in (event.get('headers') or {}).items()}
    content_type = headers_map.get('content-type', '')
    if 'text/csv' not in content_type and 'multipart/form-data' not in content_type:
        return json_response(
            400,
            {'error': 'Content-Type must be text/csv or multipart/form-data'},
        )

    # Decode body (API Gateway may base64-encode binary payloads)
    body = event.get('body', '')
    if event.get('isBase64Encoded', False) and body:
        body = base64.b64decode(body).decode('utf-8')

    if not body:
        return json_response(400, {'error': 'Empty body — no CSV data received'})

    # Parse CSV
    reader = csv.reader(io.StringIO(body))

    try:
        csv_headers = next(reader)
    except StopIteration:
        return json_response(400, {'error': 'CSV file is empty — no header row found'})

    # Clean headers
    csv_headers = [h.strip() for h in csv_headers]

    # Validate schema
    is_valid, schema_error = validate_schema(csv_headers, schema)
    if not is_valid:
        return json_response(400, {'error': f'Schema validation failed: {schema_error}'})

    rows = list(reader)

    if len(rows) == 0:
        return json_response(400, {'error': 'CSV contains a header but no data rows'})

    if len(rows) > MAX_ROWS:
        return json_response(
            400,
            {
                'error': f'CSV exceeds the maximum of {MAX_ROWS} rows',
                'rows_received': len(rows),
                'max_allowed': MAX_ROWS,
            },
        )

    # Build the INSERT statement from schema
    col_names = [col['name'] for col in schema]
    placeholders = ', '.join(['%s'] * len(col_names))
    col_list = ', '.join(col_names)
    insert_sql = f'INSERT INTO {pg_table} ({col_list}) VALUES ({placeholders}) ON CONFLICT DO NOTHING'

    # Insert rows into PostgreSQL
    conn = None
    saved = 0
    errors = []
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        for row_num, row in enumerate(rows, start=2):  # row 1 = header
            if not row or all(cell.strip() == '' for cell in row):
                continue  # skip blank lines

            coerced, coerce_error = coerce_row(row, schema)
            if coerce_error:
                errors.append(f'Row {row_num}: {coerce_error}')
                continue

            try:
                cur.execute(insert_sql, coerced)
                saved += 1
            except Exception as db_err:
                errors.append(f'Row {row_num}: DB error — {db_err}')
                conn.rollback()
                continue

        conn.commit()
        logger.info(f'Inserted {saved} rows into {pg_table}, {len(errors)} errors')

    except Exception as conn_err:
        logger.error(f'Database connection/operation error: {conn_err}')
        return json_response(500, {'error': f'Database error: {conn_err}'})
    finally:
        if conn:
            conn.close()

    result = {
        'message': f'Successfully uploaded {saved} rows to {pg_table}',
        'rows_processed': saved,
    }
    if errors:
        result['errors'] = errors[:10]  # limit to first 10 errors
        result['total_errors'] = len(errors)

    return json_response(200, result)
