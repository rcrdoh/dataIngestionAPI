from csv_upload import handle_csv_upload

DEPARTMENTS_SCHEMA = [
    {'name': 'id',         'type': 'int', 'nullable': False},
    {'name': 'department', 'type': 'str', 'nullable': False},
]


def lambda_handler(event, context):
    return handle_csv_upload(event, 'departments', DEPARTMENTS_SCHEMA)
