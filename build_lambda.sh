#!/bin/bash
set -e

echo "=== Building Lambda deployment packages ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="$SCRIPT_DIR/modules/crud/lambda_code"

cd "$LAMBDA_DIR"

# Install dependencies into a temp directory
TEMP_DIR=$(mktemp -d)
python3.11 -m pip install -r requirements.txt -t "$TEMP_DIR" --quiet

# Copy shared modules
cp common.py csv_upload.py backup_common.py "$TEMP_DIR/"

# Package each Lambda function
for func in auth departments_upload jobs_upload hired_employees_upload backup restore hiring_quarterly top_departments; do
    echo "Packaging ${func}.zip..."
    cp "${func}.py" "$TEMP_DIR/"
    cd "$TEMP_DIR"
    zip -r "${LAMBDA_DIR}/${func}.zip" . -x "*.pyc" "__pycache__/*" > /dev/null
    rm -f "${func}.py"
    cd "$LAMBDA_DIR"
done

# Cleanup
rm -rf "$TEMP_DIR"

echo "=== Lambda packages built successfully ==="
