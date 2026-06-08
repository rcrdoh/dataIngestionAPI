# Simple CRUD — Terraform Deployment Guide

A serverless CRUD API deployed on AWS with Terraform. The stack includes API Gateway, Lambda (Python), DynamoDB, Cognito authentication, and an S3-hosted static frontend.

## Project Structure

```
crud/
├── bootstrap/               # Stage 1 — S3 state bucket + DynamoDB lock table
│   ├── main.tf
│   ├── variables.tf
│   ├── output.tf
│   └── terraform.tfvars
├── modules/crud/            # Stage 2 — All CRUD infrastructure sub-modules
│   ├── apigatewayv2/        #   REST API, methods, integrations, CORS
│   ├── cognito/             #   User pool + client
│   ├── dynamodb/            #   Table
│   ├── lambda/              #   Functions + IAM role
│   ├── lambda_code/         #   Python source + zip packages
│   ├── s3/                  #   Static website bucket
│   ├── main.tf              #   Wires sub-modules together
│   ├── variables.tf
│   └── output.tf
├── static/                  # Frontend files (uploaded to S3)
│   ├── index.html
│   ├── app.css
│   ├── app.js
│   ├── config.js            # Auto-generated with API URL after deploy
│   └── error.html
├── main.tf                  # Root — provider + S3 backend + crud module
├── variables.tf
├── terraform.tfvars
├── output.tf
├── build_lambda.sh          # Rebuilds Lambda zip packages
└── .gitignore
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.0 | Infrastructure provisioning |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | AWS credentials |
| Python | >= 3.8 | Lambda packaging |
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

The bootstrap provisions the remote state backend: an **S3 bucket** (versioned, KMS-encrypted, public-access-blocked) and a **DynamoDB lock table**. This must run once before the main infrastructure.

### 1.1 Configure bootstrap variables

Edit `bootstrap/terraform.tfvars` — the **state bucket name must be globally unique** across all AWS accounts:

```hcl
aws_region            = "us-east-1"
project_name          = "SimpleCrud"
state_bucket_name     = "mycompany-crud-terraform-state"   # change this
state_lock_table_name = "terraform-state-lock"
```

### 1.2 Initialize and apply

```bash
cd bootstrap
terraform init
terraform apply
```

Review the plan and type `yes` to confirm.

### 1.3 Note the outputs

After apply, capture the output values — you will need them for Stage 2:

```bash
terraform output
```

Expected output:

```
aws_region          = "us-east-1"
state_bucket_arn    = "arn:aws:s3:::mycompany-crud-terraform-state"
state_bucket_name   = "mycompany-crud-terraform-state"
state_lock_table_arn = "arn:aws:dynamodb:us-east-1:123456789:table/terraform-state-lock"
state_lock_table_name = "terraform-state-lock"
```

---

## Stage 2 — Deploy CRUD Infrastructure

### 2.1 Build Lambda packages

Before deploying, rebuild the Lambda zip files (includes pip dependencies):

```bash
cd ..    # back to project root
./build_lambda.sh
```

This creates `.zip` files in `modules/crud/lambda_code/` for each function.

### 2.2 Configure variables

Edit `terraform.tfvars` at the project root:

```hcl
aws_region     = "us-east-1"
environment    = "dev"
project_name   = "SimpleCrud"
table_name     = "CrudTable"
user_pool_name = "SimpleCrudUserPool"

common_tags = {
  Owner = "DevTeam"
}
```

### 2.3 Initialize with S3 backend

Run `terraform init` passing the bootstrap outputs as backend configuration:

```bash
terraform init -migrate-state \
  -backend-config="bucket=$(cd bootstrap && terraform output -raw state_bucket_name)" \
  -backend-config="region=$(cd bootstrap && terraform output -raw aws_region)" \
  -backend-config="dynamodb_table=$(cd bootstrap && terraform output -raw state_lock_table_name)"
```

> **Tip:** If you prefer, you can create a `backend.hcl` file instead:
> ```hcl
> bucket         = "mycompany-crud-terraform-state"
> region         = "us-east-1"
> dynamodb_table = "terraform-state-lock"
> ```
> Then run: `terraform init -migrate-state -backend-config=backend.hcl`

### 2.4 Plan and apply

```bash
terraform plan
terraform apply
```

This provisions all CRUD resources:
- **DynamoDB** table for CRUD data
- **Cognito** user pool + client for authentication
- **Lambda** functions (create, read, update, delete, auth, products_upload, customers_upload, orders_upload)
- **API Gateway** REST API with routes, CORS, and Cognito authorizer
- **S3** bucket with static website hosting for the frontend

### 2.5 Generate frontend config

After apply, write the API Gateway URL into the frontend config:

```bash
API_URL=$(terraform output -raw api_endpoint)

cat > static/config.js <<EOF
// Auto-generated
const APP_CONFIG = {
  API_BASE_URL: "$API_URL"
};
EOF
```

### 2.6 Re-apply to upload updated config

The S3 module uses `etag` (MD5) for change detection, so re-applying will upload only the changed `config.js`:

```bash
terraform apply
```

### 2.7 View outputs

```bash
terraform output
```

Key outputs:

| Output | Description |
|--------|-------------|
| `api_endpoint` | Base URL for all API calls |
| `cognito_user_pool_id` | Cognito User Pool ID |
| `cognito_client_id` | Cognito App Client ID |
| `s3_website_url` | URL of the hosted frontend |

---

## Create a Test User

The Cognito user pool starts empty. Create a user to test login and CSV uploads:

```bash
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(terraform output -raw cognito_client_id)

aws cognito-idp admin-create-user \
  --user-pool-id "$USER_POOL_ID" \
  --username testuser \
  --temporary-password "TempPass123!"

# Set a permanent password (clears the NEW_PASSWORD_REQUIRED flag)
aws cognito-idp admin-set-user-password \
  --user-pool-id "$USER_POOL_ID" \
  --username testuser \
  --password "MyPassword123!" \
  --permanent
```

---

## Using the Frontend

1. Open the `s3_website_url` output in your browser
2. Sign in with the credentials created above
3. Use the three upload cards to upload CSV files:
   - **Products** → `POST /upload/products`
   - **Customers** → `POST /upload/customers`
   - **Orders** → `POST /upload/orders`

### CSV Format Requirements

- First row must be a **header**
- First column becomes the `id` (partition key)
- Maximum **1 000 data rows** per upload
- Send as `text/csv` content type

Example `products.csv`:

```csv
id,name,price,category
P001,Widget A,9.99,gadgets
P002,Widget B,19.99,gadgets
P003,Gizmo C,4.50,tools
```

---

## Destroy

### Destroy CRUD infrastructure

```bash
terraform destroy
```

Type `yes` to confirm. This removes all CRUD resources but keeps the state bucket.

### Destroy bootstrap (state bucket + lock table)

```bash
cd bootstrap
terraform destroy
```

> **Warning:** The state bucket has `prevent_destroy = true`. To destroy it, first remove that lifecycle rule from `bootstrap/main.tf`, re-apply, then destroy.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `terraform init` fails with "no such bucket" | Run the bootstrap first (Stage 1) |
| Lambda zip files missing | Run `./build_lambda.sh` before applying |
| 403 on API calls | Check that you are sending a valid Cognito token in the `Authorization: Bearer <token>` header |
| S3 website returns Access Denied | The S3 bucket public access block must allow public reads for website hosting |
| `config.js` still has placeholder URL | Re-run steps 2.5 and 2.6 |
| `backend-config` error | Make sure bootstrap outputs are available: `cd bootstrap && terraform output` |
