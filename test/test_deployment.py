#!/usr/bin/env python3
"""
Automated Integration Test Script – Unleash Live AWS Assessment
================================================================
1. Authenticates with Cognito (us-east-1) to retrieve a JWT.
2. Concurrently calls GET /greet in both regions.
3. Concurrently calls POST /dispatch in both regions.
4. Asserts payload region matches requested region and prints latency.

Usage (after terraform apply):
    # Auto-detect from terraform output
    ./scripts/run_tests.sh

    # Or set env vars manually
    export COGNITO_USER_POOL_ID="..."
    export COGNITO_CLIENT_ID="..."
    export COGNITO_USERNAME="tejaswi.devopscloud@gmail.com"
    export COGNITO_PASSWORD="Assessment@2024!"
    export API_URL_US_EAST_1="https://xxx.execute-api.us-east-1.amazonaws.com"
    export API_URL_EU_WEST_1="https://xxx.execute-api.eu-west-1.amazonaws.com"
    python3 test/test_deployment.py
"""

import json
import os
import sys
import time
import concurrent.futures

import boto3
import requests

# ── Colour helpers (ANSI) ────────────────────────────────────────
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

PASS = f"{GREEN}PASS{RESET}"
FAIL = f"{RED}FAIL{RESET}"
CHECK = f"{GREEN}\u2714{RESET}"
CROSS = f"{RED}\u2718{RESET}"

# ── Configuration from environment ───────────────────────────────
COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID")
COGNITO_CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID")
USERNAME = os.environ.get("COGNITO_USERNAME", "tejaswi.devopscloud@gmail.com")
PASSWORD = os.environ.get("COGNITO_PASSWORD", "Assessment@2024!")
API_URL_US_EAST_1 = os.environ.get("API_URL_US_EAST_1", "").rstrip("/")
API_URL_EU_WEST_1 = os.environ.get("API_URL_EU_WEST_1", "").rstrip("/")


def _require_env():
    """Ensure mandatory environment variables are set."""
    missing = []
    for name in (
        "COGNITO_USER_POOL_ID",
        "COGNITO_CLIENT_ID",
        "API_URL_US_EAST_1",
        "API_URL_EU_WEST_1",
    ):
        if not os.environ.get(name):
            missing.append(name)
    if missing:
        print(f"{CROSS} Missing environment variables: {', '.join(missing)}")
        print("   Set them or run via scripts/run_tests.sh after terraform apply.")
        sys.exit(1)


def authenticate() -> str:
    """Authenticate against the Cognito User Pool and return an ID token (JWT)."""
    client = boto3.client("cognito-idp", region_name="us-east-1")
    resp = client.initiate_auth(
        ClientId=COGNITO_CLIENT_ID,
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME": USERNAME,
            "PASSWORD": PASSWORD,
        },
    )
    return resp["AuthenticationResult"]["IdToken"]


def call_endpoint(base_url: str, region: str, endpoint: str, token: str) -> dict:
    """Call an API Gateway endpoint, return result dict with status, body, latency."""
    headers = {"Authorization": token}
    url = f"{base_url}{endpoint}"
    method = "GET" if endpoint == "/greet" else "POST"

    start = time.perf_counter()
    if method == "GET":
        resp = requests.get(url, headers=headers, timeout=30)
    else:
        resp = requests.post(url, headers=headers, timeout=30)
    latency_ms = round((time.perf_counter() - start) * 1000, 2)

    try:
        body = resp.json()
    except ValueError:
        body = resp.text

    return {
        "region": region,
        "endpoint": endpoint,
        "status_code": resp.status_code,
        "body": body,
        "latency_ms": latency_ms,
    }


def _print_result(result: dict) -> bool:
    """Pretty-print a single endpoint result; return True if assertion passed."""
    region = result["region"]
    endpoint = result["endpoint"]
    status = result["status_code"]
    latency = result["latency_ms"]
    body = result["body"]

    ok = status == 200
    icon = CHECK if ok else CROSS
    print(f"    {icon} {BOLD}{region}{RESET}  {endpoint}  status={status}  latency={CYAN}{latency}ms{RESET}")

    if ok and isinstance(body, dict):
        resp_region = body.get("region", "N/A")
        match = resp_region == region
        tag = f"{GREEN}MATCH{RESET}" if match else f"{RED}MISMATCH{RESET}"
        print(f"       Region assertion: expected={region}  got={resp_region}  -> {tag}")
        return match
    elif not ok:
        print(f"       Response: {body}")
        return False
    return True


# ── Main ─────────────────────────────────────────────────────────
def main():
    _require_env()

    regions = {
        "us-east-1": API_URL_US_EAST_1,
        "eu-west-1": API_URL_EU_WEST_1,
    }

    separator = "=" * 64
    print(f"\n{separator}")
    print(f"{BOLD}  Unleash Live – Integration Test Suite{RESET}")
    print(separator)

    # ── Step 1: Authenticate ──────────────────────────────────────
    print(f"\n{BOLD}[1] Authenticating with Cognito (us-east-1)...{RESET}")
    try:
        token = authenticate()
        print(f"    {CHECK} JWT retrieved successfully")
    except Exception as exc:
        print(f"    {CROSS} Authentication failed: {exc}")
        sys.exit(1)

    all_results = []

    # ── Step 2: GET /greet concurrently ───────────────────────────
    print(f"\n{BOLD}[2] Calling GET /greet in both regions (concurrent)...{RESET}")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = {
            pool.submit(call_endpoint, url, rgn, "/greet", token): rgn
            for rgn, url in regions.items()
        }
        for f in concurrent.futures.as_completed(futures):
            result = f.result()
            all_results.append(result)
            _print_result(result)

    # ── Step 3: POST /dispatch concurrently ───────────────────────
    print(f"\n{BOLD}[3] Calling POST /dispatch in both regions (concurrent)...{RESET}")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = {
            pool.submit(call_endpoint, url, rgn, "/dispatch", token): rgn
            for rgn, url in regions.items()
        }
        for f in concurrent.futures.as_completed(futures):
            result = f.result()
            all_results.append(result)
            _print_result(result)

    # ── Step 4: Summary ───────────────────────────────────────────
    print(f"\n{separator}")
    print(f"{BOLD}  Test Summary{RESET}")
    print(separator)

    passed = 0
    failed = 0
    for r in all_results:
        ok = r["status_code"] == 200
        if ok and isinstance(r["body"], dict):
            ok = r["body"].get("region") == r["region"]
        label = PASS if ok else FAIL
        if ok:
            passed += 1
        else:
            failed += 1
        print(
            f"  [{label}]  {r['region']:12s}  {r['endpoint']:12s}  "
            f"{CYAN}{r['latency_ms']}ms{RESET}"
        )

    print(separator)
    if failed == 0:
        print(f"\n  {CHECK} {GREEN}{BOLD}All {passed} tests passed!{RESET}\n")
    else:
        print(
            f"\n  {CROSS} {RED}{BOLD}{failed} test(s) failed{RESET}, "
            f"{passed} passed.\n"
        )

    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
