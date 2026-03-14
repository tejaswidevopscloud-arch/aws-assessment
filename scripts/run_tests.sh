#!/usr/bin/env bash
# run_tests.sh – Extract Terraform outputs and run the integration test suite.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

echo "Extracting Terraform outputs..."

export COGNITO_USER_POOL_ID
COGNITO_USER_POOL_ID="$(terraform output -raw cognito_user_pool_id)"

export COGNITO_CLIENT_ID
COGNITO_CLIENT_ID="$(terraform output -raw cognito_client_id)"

export API_URL_US_EAST_1
API_URL_US_EAST_1="$(terraform output -raw api_url_us_east_1)"

export API_URL_EU_WEST_1
API_URL_EU_WEST_1="$(terraform output -raw api_url_eu_west_1)"

export COGNITO_USERNAME="${COGNITO_USERNAME:-tejaswi.devopscloud@gmail.com}"
export COGNITO_PASSWORD="${COGNITO_PASSWORD:-Assessment@2024!}"

echo "  COGNITO_USER_POOL_ID = $COGNITO_USER_POOL_ID"
echo "  COGNITO_CLIENT_ID    = $COGNITO_CLIENT_ID"
echo "  API_URL_US_EAST_1    = $API_URL_US_EAST_1"
echo "  API_URL_EU_WEST_1    = $API_URL_EU_WEST_1"
echo ""

python3 test/test_deployment.py
