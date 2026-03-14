#!/usr/bin/env bash
# ============================================================================
# TESTING GUIDE – Unleash Live AWS Assessment
# ============================================================================
# This script prints step-by-step instructions for testing the full deployment.
# Run:  ./scripts/testing_guide.sh
# ============================================================================

cat << 'GUIDE'

================================================================
  DETAILED TESTING INSTRUCTIONS
  Unleash Live – AWS Multi-Region Assessment
================================================================

PREREQUISITES
─────────────
  • Docker Desktop (or Colima on Mac) — running
  • An AWS account with admin or broad permissions
  • AWS credentials (Access Key ID + Secret Access Key)

  No Terraform, Python, or AWS CLI installation needed on your Mac —
  everything runs inside Docker containers.


================================================================
STEP 1 — GET AWS CREDENTIALS
================================================================

Option A: IAM User (simplest)
  1. Log into AWS Console → IAM → Users → Create user
  2. Attach policy: "AdministratorAccess" (for this assessment only!)
  3. Create Access Key → choose "CLI" use case
  4. Note down: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

Option B: AWS SSO / Temporary credentials
  1. Run: aws sso login --profile your-profile
  2. Export:
       eval $(aws configure export-credentials --profile your-profile --format env)


================================================================
STEP 2 — SET ENVIRONMENT VARIABLES
================================================================

  export AWS_ACCESS_KEY_ID="AKIA..."
  export AWS_SECRET_ACCESS_KEY="wJalr..."

  # Verify they're set:
  echo $AWS_ACCESS_KEY_ID


================================================================
STEP 3 — VALIDATE (no AWS account needed)
================================================================

  cd ~/aws-assessment
  ./scripts/docker_validate.sh

  This runs inside Docker:
    ✅ terraform fmt -check -recursive
    ✅ terraform init -backend=false
    ✅ terraform validate
    ✅ tfsec security scan

  Expected output:
    [1/4] terraform fmt -check -recursive
      ✅ Formatting OK
    [2/4] terraform init -backend=false
      ✅ Init OK
    [3/4] terraform validate
      Success! The configuration is valid.
      ✅ Validation OK
    [4/4] tfsec security scan
      ✅ Security scan complete
    ============================================
      All checks passed!
    ============================================


================================================================
STEP 4 — PLAN (review what will be created)
================================================================

  ./scripts/docker_deploy_and_test.sh plan

  This will show everything Terraform plans to create (~30+ resources).
  Review the plan. No resources are created yet.


================================================================
STEP 5 — DEPLOY + AUTOMATED TESTS
================================================================

  ./scripts/docker_deploy_and_test.sh apply

  This does ALL of the following automatically:
    1. terraform init
    2. terraform plan
    3. terraform apply (creates all AWS resources)
    4. Extracts API URLs and Cognito IDs
    5. Runs the integration test script

  EXPECTED CLI OUTPUT:
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │  [1] terraform init                                      │
  │  Terraform has been successfully initialized!             │
  │                                                          │
  │  [2] terraform plan                                      │
  │  Plan: 42 to add, 0 to change, 0 to destroy.            │
  │                                                          │
  │  [3] terraform apply                                     │
  │  Apply complete! Resources: 42 added, 0 changed, 0 destroyed. │
  │                                                          │
  │  [4] Extracting outputs...                               │
  │    COGNITO_USER_POOL_ID = us-east-1_xxxxxxxx             │
  │    COGNITO_CLIENT_ID    = xxxxxxxxxxxxxxxxxxxxxxxxx      │
  │    API_URL_US_EAST_1    = https://xxx.execute-api.us-east-1.amazonaws.com │
  │    API_URL_EU_WEST_1    = https://xxx.execute-api.eu-west-1.amazonaws.com │
  │                                                          │
  │  [5] Running integration tests...                        │
  │  ================================================================ │
  │    Unleash Live – Integration Test Suite                  │
  │  ================================================================ │
  │                                                          │
  │  [1] Authenticating with Cognito (us-east-1)...          │
  │      ✔ JWT retrieved successfully                        │
  │                                                          │
  │  [2] Calling GET /greet in both regions (concurrent)...  │
  │      ✔ us-east-1  /greet  status=200  latency=253ms     │
  │         Region assertion: expected=us-east-1  got=us-east-1  -> MATCH │
  │      ✔ eu-west-1  /greet  status=200  latency=412ms     │
  │         Region assertion: expected=eu-west-1  got=eu-west-1  -> MATCH │
  │                                                          │
  │  [3] Calling POST /dispatch in both regions (concurrent)...│
  │      ✔ us-east-1  /dispatch  status=200  latency=1856ms │
  │         Region assertion: expected=us-east-1  got=us-east-1  -> MATCH │
  │      ✔ eu-west-1  /dispatch  status=200  latency=2134ms │
  │         Region assertion: expected=eu-west-1  got=eu-west-1  -> MATCH │
  │                                                          │
  │  ================================================================ │
  │    Test Summary                                          │
  │  ================================================================ │
  │    [PASS]  us-east-1     /greet        253ms             │
  │    [PASS]  eu-west-1     /greet        412ms             │
  │    [PASS]  us-east-1     /dispatch     1856ms            │
  │    [PASS]  eu-west-1     /dispatch     2134ms            │
  │  ================================================================ │
  │                                                          │
  │    ✔ All 4 tests passed!                                 │
  │                                                          │
  └──────────────────────────────────────────────────────────┘


================================================================
STEP 6 — RE-RUN TESTS ONLY (infrastructure already deployed)
================================================================

  ./scripts/docker_deploy_and_test.sh test-only


================================================================
STEP 7 — DESTROY (IMPORTANT — avoid charges!)
================================================================

  ./scripts/docker_deploy_and_test.sh destroy

  This runs: terraform destroy -auto-approve
  Expected output:
    Destroy complete! Resources: 42 destroyed.


================================================================
WHAT THE TESTS VERIFY (printed on CLI)
================================================================

  1. JWT Authentication
     → Programmatically authenticates with Cognito (us-east-1)
     → Prints: "✔ JWT retrieved successfully" or "✘ Authentication failed"

  2. GET /greet (both regions, concurrent)
     → Calls the Greeter Lambda in us-east-1 AND eu-west-1
     → Lambda writes to DynamoDB + publishes to Unleash SNS topic
     → ASSERTS: response "region" matches requested region
     → Prints: latency per request + MATCH/MISMATCH

  3. POST /dispatch (both regions, concurrent)
     → Calls the Dispatcher Lambda in us-east-1 AND eu-west-1
     → Lambda runs a Fargate task that publishes to Unleash SNS topic
     → ASSERTS: response "region" matches requested region
     → Prints: latency per request + MATCH/MISMATCH

  4. Summary
     → Colour-coded PASS/FAIL per test
     → Exit code 0 = all pass, exit code 1 = failures


================================================================
SNS PAYLOADS SENT TO UNLEASH LIVE
================================================================

  The /greet endpoint Lambda publishes:
    {
      "email": "tejaswi.devopscloud@gmail.com",
      "source": "Lambda",
      "region": "us-east-1",    (or "eu-west-1")
      "repo": "https://github.com/tejaswidevopscloud-arch/aws-assessment"
    }

  The ECS Fargate task (triggered by /dispatch) publishes:
    {
      "email": "tejaswi.devopscloud@gmail.com",
      "source": "ECS",
      "region": "us-east-1",    (or "eu-west-1")
      "repo": "https://github.com/tejaswidevopscloud-arch/aws-assessment"
    }

  Both are sent to:
    arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic


================================================================
TROUBLESHOOTING
================================================================

  Q: Docker says "Cannot connect to the Docker daemon"
  A: Start Docker Desktop, or if using Colima:  colima start

  Q: "AccessDeniedException" during apply
  A: Your IAM user needs broader permissions. Use AdministratorAccess
     for this assessment.

  Q: "An error occurred (NotAuthorizedException)"
  A: Wrong Cognito password. Default is: Assessment@2024!

  Q: /dispatch returns "failures" in the response
  A: The Fargate task may need a moment to register. Wait 30s and
     re-run: ./scripts/docker_deploy_and_test.sh test-only

  Q: tfsec shows CRITICAL/HIGH findings
  A: These are informational. Key intentional decisions:
     - Public subnets for Fargate (avoids NAT Gateway cost)
     - Egress 0.0.0.0/0 for ECS (required to reach AWS APIs)

GUIDE
