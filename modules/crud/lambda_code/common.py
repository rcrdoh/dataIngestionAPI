import json
import os
import boto3
import psycopg2


dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'CrudTable')
host_name = os.environ.get('DB_HOST','')
table = dynamodb.Table(table_name)


def get_db_connection():
    """Return a psycopg2 connection using environment variables for RDS."""
    auth_token = boto3.client('rds', region_name='us-east-1').generate_db_auth_token(DBHostname=host_name,Port=5432, DBUsername='postgres', Region='us-east-1')

    conn = None

    conn = psycopg2.connect(
        host=host_name,
        port=5432,
        database='postgres',
        user='postgres',
        password=auth_token,
        sslmode="require",
        sslrootcert="verify-null"
    )
    conn.autocommit = True
    
    return conn


def json_response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body)
    }