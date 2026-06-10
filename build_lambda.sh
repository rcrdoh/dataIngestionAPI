#!/bin/bash
set -e
echo "=== Building Lambda deployment packages ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDA_DIR="$SCRIPT_DIR/modules/crud/lambda_code"
echo $LAMBDA_DIR
cd "$LAMBDA_DIR"

echo "Starting Docker container (python:3.12 – Amazon Linux 2023)..."
CONTAINER_ID=$(docker run --rm -d \
  --entrypoint /bin/bash \
  public.ecr.aws/lambda/python:3.12 \
  -c "sleep 300")

# ── Phase 1: Build dependencies.zip (base layer — all functions) ──
echo "=== Phase 1: Building base dependencies layer ==="

docker cp "$LAMBDA_DIR/requirements.txt" \
  "$CONTAINER_ID:/var/task/requirements.txt"

docker exec "$CONTAINER_ID" /bin/bash -c "
  python -m pip install --upgrade pip &&
  python -m pip install \
    -r /var/task/requirements.txt \
    -t /output_base/python \
    --no-cache-dir
"

BASE_TEMP=$(mktemp -d)
docker cp "$CONTAINER_ID:/output_base/." "$BASE_TEMP/"

echo "Packaging dependencies.zip..."
(
  cd "$BASE_TEMP"
  find python -type d -name "tests" -prune -exec rm -rf {} + 2>/dev/null || true
  find python -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
  find python -name "*.pyc" -delete 2>/dev/null || true
  zip -rq "${LAMBDA_DIR}/dependencies.zip" . \
    -x "*.pyc" \
    -x "__pycache__/*" \
    -x "*.dist-info/*" \
    -x "*.egg-info/*"
)
rm -rf "$BASE_TEMP"
echo "Base layer built: $(du -h ${LAMBDA_DIR}/dependencies.zip | cut -f1)"

# ── Phase 1b: Build dependencies_pandas.zip (pandas layer — report functions only) ──
echo "=== Phase 1b: Building pandas layer ==="

docker exec "$CONTAINER_ID" /bin/bash -c "
  python -m pip install \
    'pandas==2.2.3' \
    -t /output_pandas/python \
    --no-cache-dir
"

PANDAS_TEMP=$(mktemp -d)
docker cp "$CONTAINER_ID:/output_pandas/." "$PANDAS_TEMP/"

echo "Stripping pandas layer (before: $(du -sh $PANDAS_TEMP | cut -f1))..."
(
  cd "$PANDAS_TEMP"
  find python -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
  find python -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
  find python -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
  find python -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
  find python -type d -name "docs" -exec rm -rf {} + 2>/dev/null || true
  find python -type d -name "benchmarks" -exec rm -rf {} + 2>/dev/null || true
  find python -type d -name "include" -exec rm -rf {} + 2>/dev/null || true
  find python -name "*.pyc" -delete 2>/dev/null || true
  find python -name "*.pyo" -delete 2>/dev/null || true
  find python -name "README*" -delete 2>/dev/null || true
  find python -name "LICENSE*" -delete 2>/dev/null || true
  find python -name "MANIFEST*" -delete 2>/dev/null || true
  echo "After stripping: $(du -sh . | cut -f1)"
)

echo "Packaging dependencies_pandas.zip..."
(
  cd "$PANDAS_TEMP"
  zip -rq "${LAMBDA_DIR}/dependencies_pandas.zip" .
)
rm -rf "$PANDAS_TEMP"
echo "Pandas layer built: $(du -h ${LAMBDA_DIR}/dependencies_pandas.zip | cut -f1)"

# ── Phase 2: Build slim function ZIPs (code only, no pip packages) ─
echo "=== Phase 2: Building function packages (code only) ==="

docker stop "$CONTAINER_ID"

FUNC_TEMP=$(mktemp -d)
cp common.py csv_upload.py backup_common.py "$FUNC_TEMP/"

for func in \
  auth \
  departments_upload \
  jobs_upload \
  hired_employees_upload \
  backup \
  restore \
  hiring_quarterly \
  top_departments
do
  echo "Packaging ${func}.zip..."
  cp "${func}.py" "$FUNC_TEMP/"
  (
    cd "$FUNC_TEMP"
    zip -rq "${LAMBDA_DIR}/${func}.zip" . \
      -x "*.pyc" \
      -x "__pycache__/*"
  )
  rm -f "$FUNC_TEMP/${func}.py"
  echo "  $(du -h ${LAMBDA_DIR}/${func}.zip | cut -f1)"
done

rm -rf "$FUNC_TEMP"
echo "=== Lambda packages built successfully ==="