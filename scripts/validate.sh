#!/usr/bin/env bash
# validate.sh – Run Terraform format, init, and validate checks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

echo "============================================"
echo "  Terraform Validation Suite"
echo "============================================"

echo ""
echo "[1/3] terraform fmt -check -recursive"
if terraform fmt -check -recursive; then
  echo "  ✅ Formatting OK"
else
  echo "  ❌ Formatting issues detected. Run: terraform fmt -recursive"
  exit 1
fi

echo ""
echo "[2/3] terraform init -backend=false"
terraform init -backend=false -input=false > /dev/null 2>&1
echo "  ✅ Init OK"

echo ""
echo "[3/3] terraform validate"
if terraform validate; then
  echo "  ✅ Validation OK"
else
  echo "  ❌ Validation failed"
  exit 1
fi

echo ""
echo "============================================"
echo "  All checks passed!"
echo "============================================"
