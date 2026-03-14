#!/usr/bin/env bash
# docker_validate.sh – Run Terraform fmt, init, validate, and tfsec using Docker.
# No local Terraform installation required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

TF_IMAGE="hashicorp/terraform:1.7"
TFSEC_IMAGE="aquasec/tfsec:latest"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}✅ $1${RESET}"; }
fail() { echo -e "  ${RED}❌ $1${RESET}"; }
info() { echo -e "  ${CYAN}ℹ  $1${RESET}"; }

ERRORS=0

echo ""
echo -e "${BOLD}============================================${RESET}"
echo -e "${BOLD}  Terraform Validation (Docker-based)${RESET}"
echo -e "${BOLD}============================================${RESET}"
echo ""

# ── 1. terraform fmt ──────────────────────────────────────────
echo -e "${BOLD}[1/4] terraform fmt -check -recursive${RESET}"
if docker run --rm -v "$ROOT_DIR:/workspace" -w /workspace "$TF_IMAGE" fmt -check -recursive; then
  pass "Formatting OK"
else
  fail "Formatting issues detected"
  info "Auto-fix: docker run --rm -v \"$ROOT_DIR:/workspace\" -w /workspace $TF_IMAGE fmt -recursive"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# ── 2. terraform init ────────────────────────────────────────
echo -e "${BOLD}[2/4] terraform init -backend=false${RESET}"
if docker run --rm -v "$ROOT_DIR:/workspace" -w /workspace "$TF_IMAGE" init -backend=false -input=false 2>&1 | tail -5; then
  pass "Init OK"
else
  fail "Init failed"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# ── 3. terraform validate ────────────────────────────────────
echo -e "${BOLD}[3/4] terraform validate${RESET}"
VALIDATE_OUTPUT=$(docker run --rm -v "$ROOT_DIR:/workspace" -w /workspace "$TF_IMAGE" validate 2>&1)
VALIDATE_EXIT=$?
echo "$VALIDATE_OUTPUT"
if [ $VALIDATE_EXIT -eq 0 ]; then
  pass "Validation OK"
else
  fail "Validation failed"
  ERRORS=$((ERRORS + 1))
fi

echo ""

# ── 4. tfsec security scan ───────────────────────────────────
echo -e "${BOLD}[4/4] tfsec security scan${RESET}"
if docker run --rm -v "$ROOT_DIR:/workspace" "$TFSEC_IMAGE" /workspace --soft-fail 2>&1 | tail -30; then
  pass "Security scan complete"
else
  info "tfsec scan completed with findings (soft-fail)"
fi

echo ""
echo -e "${BOLD}============================================${RESET}"
if [ $ERRORS -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}All checks passed!${RESET}"
else
  echo -e "  ${RED}${BOLD}$ERRORS check(s) failed.${RESET}"
fi
echo -e "${BOLD}============================================${RESET}"
echo ""

exit $ERRORS
