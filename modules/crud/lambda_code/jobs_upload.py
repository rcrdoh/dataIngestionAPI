from csv_upload import handle_csv_upload

JOBS_SCHEMA = [
    {'name': 'id',  'type': 'int', 'nullable': False},
    {'name': 'job', 'type': 'str', 'nullable': False},
]


def lambda_handler(event, context):
    return handle_csv_upload(event, 'jobs', JOBS_SCHEMA)
