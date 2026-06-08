# Simple CRUD — AWS Serverless CSV Upload & Backup

A serverless web application for uploading CSV files into **PostgreSQL (RDS)**, with
**AVRO backup/restore** to S3 — all deployed on AWS via Terraform.

The stack includes API Gateway (REST), Lambda (Python 3.11), Cognito
authentication, DynamoDB (for the legacy CRUD table), an S3-hosted static
frontend, and an S3 backup bucket.

## Stack

| Component | Technology |
|-----------|------------|
| API | API Gateway REST API with Lambda proxy integration |
| Auth | Cognito User Pool + client (`ADMIN_USER_PASSWORD_AUTH`) |
| Upload backend | Python Lambda → PostgreSQL (RDS) via `psycopg2` |
| Backup / Restore | PostgreSQL → AVRO (fastavro) → S3 and back |
| Frontend | Static HTML/CSS/JS hosted on S3 website |
| Infrastructure | Terraform ≥ 1.0 with S3 backend + DynamoDB lock |

## API Endpoints

| Method | Path | Auth | Handler |
|--------|------|------|---------|
| `POST` | `/login` | None | `auth.py` — Cognito `admin_initiate_auth` |
| `POST` | `/upload/departments` | Cognito | `departments_upload.py` |
| `POST` | `/upload/jobs` | Cognito | `jobs_upload.py` |
| `POST` | `/upload/hired_employees` | Cognito | `hired_employees_upload.py` |
| `POST` | `/backup` | Cognito | `backup.py` — AVRO export to S3 |
| `POST` | `/restore` | Cognito | `restore.py` — AVRO import from S3 |
| `POST` | `/items` | Cognito | DynamoDB create (legacy) |
| `GET` | `/items/{id}` | Cognito | DynamoDB read (legacy) |
| `PUT` | `/items/{id}` | Cognito | DynamoDB update (legacy) |
| `DELETE` | `/items/{id}` | Cognito | DynamoDB delete (legacy) |

### PostgreSQL tables (CSV upload target)

```
departments       (id INT PK,  department VARCHAR)
jobs              (id INT PK,  job VARCHAR)
hired_employees   (id INT PK,  name VARCHAR, datetime TIMESTAMP,
                   department_id INT FK→departments, job_id INT FK→jobs)
```

The DDL is in `sampleData/init.sql`.

### CSV upload rules

- First row must be a **header** matching the schema column names
- Maximum **1 000 data rows** per upload
- Schema validation: column count, column names, and type coercion (`int`,
  `str`, `datetime`) are enforced server-side
- Rows that fail validation are skipped; the response includes error details
- Duplicate primary keys are skipped (`ON CONFLICT DO NOTHING`)

### Backup / Restore

- **Backup** serialises the three PostgreSQL tables to AVRO binary and stores
  them under `s3://<bucket>/backups/<backup_id>/<table>.avro`
- **Restore** downloads the latest AVRO backup, truncates all tables (children
  first to respect FK constraints), then repopulates from AVRO
- You can optionally pass `{"backup_id": "20250101T120000Z"}` to restore a
  specific backup

## Project Structure

```
crud/
├── bootstrap/                    # Stage 1 — S3 state bucket + DynamoDB lock
│   ├── main.tf / variables.tf / output.tf / terraform.tfvars
├── modules/crud/                 # Stage 2 — All infrastructure sub-modules
│   ├── apigatewayv2/             #   REST API (routes, integrations, CORS, authorizer)
│   ├── cognito/                  #   User pool + client
│   ├── dynamodb/                 #   Legacy CRUD table
│   ├── lambda/                   #   Functions, IAM role, backup S3 bucket
│   ├── lambda_code/              #   Python source + .zip packages
│   │   ├── auth.py               #   Cognito login / password-reset Lambda
│   │   ├── csv_upload.py         #   Shared CSV parsing + PostgreSQL insert
│   │   ├── departments_upload.py #   /upload/departments
│   │   ├── jobs_upload.py        #   /upload/jobs
│   │   ├── hired_employees_upload.py  # /upload/hired_employees
│   │   ├── backup.py             #   PostgreSQL → AVRO → S3
│   │   ├── restore.py            #   S3 → AVRO → PostgreSQL
│   │   ├── backup_common.py      #   Shared AVRO schemas & S3 helpers
│   │   ├── common.py             #   psycopg2 connection helper
│   │   └── requirements.txt      #   psycopg2-binary, fastavro, boto3
│   ├── s3/                       #   Frontend website bucket
│   ├── main.tf                   #   Wires sub-modules together
│   └── variables.tf / output.tf
├── static/                       # Frontend (uploaded to S3)
│   ├── index.html
│   ├── app.css / app.js
│   ├── config.js                 # Auto-generated API URL after deploy
│   └── error.html
├── main.tf                       # Root — provider + S3 backend + crud module
├── variables.tf / output.tf
├── terraform.tfvars              # Your configuration (DO NOT commit secrets)
├── terraform.tfvars.example      # Template to copy from
├── backend.hcl                   # Backend config for terraform init
├── build_lambda.sh               # Rebuilds Lambda .zip packages
└── .gitignore
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.0 | Infrastructure provisioning |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | AWS credentials |
| Python | ≥ 3.11 | Lambda packaging |
| pip | any | Python dependencies |
| zip | any | Lambda zip creation |

Make sure your AWS credentials are configured:

```bash
aws configure
# or use environment variables:
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

---

## Stage 1 — Deploy Bootstrap

The bootstrap provisions the **Terraform remote state backend**: an S3 bucket
(versioned, KMS-encrypted, public-access-blocked) and a DynamoDB lock table.

### 1.1 Configure

Edit `bootstrap/terraform.tfvars` — the **state bucket name must be globally
unique** across all AWS accounts:

```hcl
aws_region            = "us-east-1"
project_name          = "SimpleCrud"
state_bucket_name     = "mycompany-crud-terraform-state"   # CHANGE THIS
state_lock_table_name = "terraform-state-lock"
```

### 1.2 Apply

```bash
cd bootstrap
terraform init
terraform apply
```

Note the outputs — you will need them in Stage 2:

```bash
terraform output
```

---

## Stage 2 — Deploy CRUD Infrastructure

### 2.1 Configure variables

Copy the example and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Required variables:

| Variable | Description |
|----------|-------------|
| `aws_region` | AWS region (default `us-east-1`) |
| `environment` | Environment name (`dev`/`qa`/`prod`) |
| `project_name` | Project name for resource naming |
| `db_host` | PostgreSQL RDS endpoint |
| `db_port` | PostgreSQL port (default `5432`) |
| `db_name` | Database name |
| `db_user` | Database username |
| `db_password` | Database password |

### 2.2 Set up PostgreSQL schema

Before uploading data, run `sampleData/init.sql` against your RDS instance to
create the three required tables and indexes.

### 2.3 Build Lambda packages

```bash
./build_lambda.sh
```

This installs pip dependencies (`psycopg2-binary`, `fastavro`, `boto3`) and
creates `.zip` files in `modules/crud/lambda_code/` for each function.

### 2.4 Initialize with S3 backend

```bash
terraform init -migrate-state \
  -backend-config="bucket=$(cd bootstrap && terraform output -raw state_bucket_name)" \
  -backend-config="region=$(cd bootstrap && terraform output -raw aws_region)" \
  -backend-config="dynamodb_table=$(cd bootstrap && terraform output -raw state_lock_table_name)"
```

Or use the `backend.hcl` file (edit it first with your bootstrap values):

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

### 2.5 Plan and apply

```bash
terraform plan
terraform apply
```

This provisions:

- **DynamoDB** table (legacy CRUD)
- **Cognito** user pool + app client
- **Lambda** functions (auth, 3× CSV upload, backup, restore + legacy CRUD)
- **API Gateway** REST API with Cognito authorizer and CORS
- **S3** website bucket with public-read policy (frontend)
- **S3** backup bucket (versioned, KMS-encrypted, private)

### 2.6 Generate frontend config

```bash
API_URL=$(terraform output -raw api_endpoint)

cat > static/config.js <<EOF
// Auto-generated
const APP_CONFIG = {
  API_BASE_URL: "$API_URL"
};
EOF
```

### 2.7 Re-apply to upload updated `config.js`

The S3 module uses `etag` (MD5) for change detection:

```bash
terraform apply
```

### 2.8 View outputs

```bash
terraform output
```

Key outputs:

| Output | Description |
|--------|-------------|
| `api_endpoint` | API Gateway invoke URL (`https://...amazonaws.com/prod`) |
| `cognito_user_pool_id` | Cognito User Pool ID |
| `cognito_client_id` | Cognito App Client ID |
| `s3_website_url` | Frontend URL (`http://...s3-website-...amazonaws.com`) |
| `backup_bucket_name` | S3 bucket for AVRO backups |
| `dynamodb_table_name` | Legacy DynamoDB CRUD table |
