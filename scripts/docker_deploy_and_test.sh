#!/usr/bin/env bash
# docker_deploy_and_test.sh
# Full end-to-end: deploy with Terraform in Docker, run tests in Docker, print results.
# Requires: Docker, AWS credentials (~/.aws or env vars).
#
# Usage:
#   # Option A: Using AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars
#   export AWS_ACCESS_KEY_ID="AKIA..."
#   export AWS_SECRET_ACCESS_KEY="wJalr..."
#   ./scripts/docker_deploy_and_test.sh apply
#
#   # Option B: Using ~/.aws credentials (default profile)
#   ./scripts/docker_deploy_and_test.sh apply
#
#   # To destroy:
#   ./scripts/docker_deploy_and_test.sh destroy
#
#   # To only plan:
#   ./scripts/docker_deploy_and_test.sh plan
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

ACTION="${1:-plan}"  # plan | apply | destroy | test-only

TF_IMAGE="hashicorp/terraform:1.7"
PYTHON_IMAGE="python:3.11-slim"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Build AWS credentials docker args ─────────────────────────
AWS_DOCKER_ARGS=()
if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
  AWS_DOCKER_ARGS+=(-e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID")
  AWS_DOCKER_ARGS+=(-e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY")
  [ -n "${AWS_SESSION_TOKEN:-}" ] && AWS_DOCKER_ARGS+=(-e "AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN")
  AWS_DOCKER_ARGS+=(-e "AWS_DEFAULT_REGION=us-east-1")
elif [ -d "$HOME/.aws" ]; then
  AWS_DOCKER_ARGS+=(-v "$HOME/.aws:/root/.aws:ro")
  AWS_DOCKER_ARGS+=(-e "AWS_DEFAULT_REGION=us-east-1")
else
  echo -e "${RED}ERROR: No AWS credentials found.${RESET}"
  echo "  Set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY env vars"
  echo "  or configure ~/.aws/credentials"
  exit 1
fi

tf() {
  docker run --rm \
    -v "$ROOT_DIR:/workspace" \
    -w /workspace \
    "${AWS_DOCKER_ARGS[@]}" \
    "$TF_IMAGE" "$@"
}

echo ""
echo -e "${BOLD}================================================================${RESET}"
echo -e "${BOLD}  Unleash Live – AWS Assessment (Docker-based)${RESET}"
echo -e "${BOLD}================================================================${RESET}"
echo -e "  Action: ${CYAN}${ACTION}${RESET}"
echo ""

# ── Init ──────────────────────────────────────────────────────
echo -e "${BOLD}[1] terraform init${RESET}"
tf init -input=false
echo ""

case "$ACTION" in
  plan)
    echo -e "${BOLD}[2] terraform plan${RESET}"
    tf plan -var-file=terraform.tfvars
    echo ""
    echo -e "${GREEN}${BOLD}Plan complete. Review above and run with 'apply' when ready.${RESET}"
    ;;

  apply)
    echo -e "${BOLD}[2] terraform plan${RESET}"
    tf plan -var-file=terraform.tfvars -out=tfplan
    echo ""

    echo -e "${BOLD}[3] terraform apply${RESET}"
    tf apply -auto-approve tfplan
    echo ""

    # Extract outputs
    echo -e "${BOLD}[4] Extracting outputs...${RESET}"
    COGNITO_USER_POOL_ID=$(tf output -raw cognito_user_pool_id)
    COGNITO_CLIENT_ID=$(tf output -raw cognito_client_id)
    API_URL_US_EAST_1=$(tf output -raw api_url_us_east_1)
    API_URL_EU_WEST_1=$(tf output -raw api_url_eu_west_1)

    echo -e "  COGNITO_USER_POOL_ID = ${CYAN}$COGNITO_USER_POOL_ID${RESET}"
    echo -e "  COGNITO_CLIENT_ID    = ${CYAN}$COGNITO_CLIENT_ID${RESET}"
    echo -e "  API_URL_US_EAST_1    = ${CYAN}$API_URL_US_EAST_1${RESET}"
    echo -e "  API_URL_EU_WEST_1    = ${CYAN}$API_URL_EU_WEST_1${RESET}"
    echo ""

    # Run integration tests
    echo -e "${BOLD}[5] Running integration tests...${RESET}"
    docker run --rm \
      -v "$ROOT_DIR:/workspace" \
      -w /workspace \
      "${AWS_DOCKER_ARGS[@]}" \
      -e "COGNITO_USER_POOL_ID=$COGNITO_USER_POOL_ID" \
      -e "COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID" \
      -e "API_URL_US_EAST_1=$API_URL_US_EAST_1" \
      -e "API_URL_EU_WEST_1=$API_URL_EU_WEST_1" \
      -e "COGNITO_USERNAME=tejaswi.devopscloud@gmail.com" \
      -e "COGNITO_PASSWORD=Assessment@2024!" \
      "$PYTHON_IMAGE" bash -c "pip install -q -r test/requirements.txt && python test/test_deployment.py"
    echo ""

    echo -e "${YELLOW}${BOLD}⚠  IMPORTANT: Run './scripts/docker_deploy_and_test.sh destroy' to tear down and avoid charges!${RESET}"
    ;;

  test-only)
    echo -e "${BOLD}[2] Extracting outputs...${RESET}"
    COGNITO_USER_POOL_ID=$(tf output -raw cognito_user_pool_id)
    COGNITO_CLIENT_ID=$(tf output -raw cognito_client_id)
    API_URL_US_EAST_1=$(tf output -raw api_url_us_east_1)
    API_URL_EU_WEST_1=$(tf output -raw api_url_eu_west_1)
    echo ""

    echo -e "${BOLD}[3] Running integration tests...${RESET}"
    docker run --rm \
      -v "$ROOT_DIR:/workspace" \
      -w /workspace \
      "${AWS_DOCKER_ARGS[@]}" \
      -e "COGNITO_USER_POOL_ID=$COGNITO_USER_POOL_ID" \
      -e "COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID" \
      -e "API_URL_US_EAST_1=$API_URL_US_EAST_1" \
      -e "API_URL_EU_WEST_1=$API_URL_EU_WEST_1" \
      -e "COGNITO_USERNAME=tejaswi.devopscloud@gmail.com" \
      -e "COGNITO_PASSWORD=Assessment@2024!" \
      "$PYTHON_IMAGE" bash -c "pip install -q -r test/requirements.txt && python test/test_deployment.py"
    ;;

  destroy)
    echo -e "${BOLD}[2] terraform destroy${RESET}"
    tf destroy -auto-approve -var-file=terraform.tfvars
    echo ""
    echo -e "${GREEN}${BOLD}Infrastructure destroyed. No more charges.${RESET}"
    ;;

  *)
    echo -e "${RED}Unknown action: $ACTION${RESET}"
    echo "Usage: $0 {plan|apply|destroy|test-only}"
    exit 1
    ;;
esac

echo ""
echo -e "${BOLD}================================================================${RESET}"
echo -e "${BOLD}  Done!${RESET}"
echo -e "${BOLD}================================================================${RESET}"
