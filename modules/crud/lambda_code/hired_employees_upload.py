from csv_upload import handle_csv_upload

HIRED_EMPLOYEES_SCHEMA = [
    {'name': 'id',            'type': 'int',      'nullable': False},
    {'name': 'name',          'type': 'str',      'nullable': False},
    {'name': 'datetime',      'type': 'datetime', 'nullable': False},
    {'name': 'department_id', 'type': 'int',      'nullable': False},
    {'name': 'job_id',        'type': 'int',      'nullable': False},
]


def lambda_handler(event, context):
    return handle_csv_upload(event, 'hired_employees', HIRED_EMPLOYEES_SCHEMA)
