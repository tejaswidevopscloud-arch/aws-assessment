# Unleash Live – AWS Multi-Region Assessment

Multi-region AWS infrastructure provisioned with **Terraform**, featuring
Cognito authentication, API Gateway, Lambda, DynamoDB, and ECS Fargate
deployed identically across `us-east-1` and `eu-west-1`.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        us-east-1                                 │
│  ┌─────────────┐   ┌──────────┐   ┌──────────┐   ┌───────────┐ │
│  │   Cognito    │   │  API GW  │──▶│  Lambda   │──▶│ DynamoDB  │ │
│  │  User Pool   │   │ /greet   │   │ (Greeter) │   │ Greeting  │ │
│  │  + Client    │   │ /dispatch│   │           │──▶│ Logs      │ │
│  └─────────────┘   └──────────┘   ├───────────┤   └───────────┘ │
│        │  JWT          │          │ (Dispatch) │                  │
│        │  Auth         │          └─────┬──────┘                  │
│        │               │                │ ecs:RunTask             │
│        │               │          ┌─────▼──────┐                  │
│        │               │          │ ECS Fargate │──▶ SNS (verify) │
│        │               │          └────────────┘                  │
├────────┼───────────────┼────────────────────────────────────────-─┤
│        │          eu-west-1  (identical stack)                    │
│        │               │                                          │
│  (JWT validated   ┌──────────┐   ┌──────────┐   ┌───────────┐   │
│   cross-region)   │  API GW  │──▶│  Lambda   │──▶│ DynamoDB  │   │
│                   │ /greet   │   │ (Greeter) │   │ Greeting  │   │
│                   │ /dispatch│   │           │──▶│ Logs      │   │
│                   └──────────┘   ├───────────┤   └───────────┘   │
│                                  │ (Dispatch) │                   │
│                                  └─────┬──────┘                   │
│                                        │ ecs:RunTask              │
│                                  ┌─────▼──────┐                   │
│                                  │ ECS Fargate │──▶ SNS (verify)  │
│                                  └────────────┘                   │
└──────────────────────────────────────────────────────────────────┘
```

## Multi-Region Provider Strategy

Terraform providers are configured in `providers.tf`:

| Provider | Alias | Region | Purpose |
|----------|-------|--------|---------|
| Default `aws` | *(none)* | `us-east-1` | Cognito module + us-east-1 regional stack |
| `aws.eu_west_1` | `eu_west_1` | `eu-west-1` | eu-west-1 regional stack |

The **`modules/regional-stack`** module is instantiated twice in `main.tf` —
once with the default provider and once with `providers = { aws = aws.eu_west_1 }`.
The module itself is provider-agnostic; it simply uses the injected `aws` provider.

The Cognito JWT authorizer in both regions points to the **same User Pool in
`us-east-1`** — HTTP API Gateway validates JWTs from any issuer URL, so no
cross-region Cognito replication is needed.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.5 |
| AWS CLI | v2 |
| Python | >= 3.9 |
| pip packages | `boto3`, `requests` |

```bash
pip install -r test/requirements.txt
```

---

## Quick Start – Manual Deployment

```bash
# 1. Clone
git clone https://github.com/tejaswidevopscloud-arch/aws-assessment.git
cd aws-assessment

# 2. Initialise Terraform
terraform init

# 3. Review the plan
terraform plan -var-file=terraform.tfvars

# 4. Deploy
terraform apply -var-file=terraform.tfvars

# 5. Run integration tests
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh

# 6. IMPORTANT – Tear down to avoid charges
terraform destroy -var-file=terraform.tfvars
```

### Overriding Variables

You can override values at deploy time:

```bash
terraform apply \
  -var 'email=your@email.com' \
  -var 'github_repo=https://github.com/you/repo' \
  -var 'cognito_user_password=MyP@ssw0rd!'
```

---

## Running the Test Script Manually

If you prefer to set environment variables yourself instead of using `run_tests.sh`:

```bash
export COGNITO_USER_POOL_ID="<from terraform output>"
export COGNITO_CLIENT_ID="<from terraform output>"
export API_URL_US_EAST_1="<from terraform output>"
export API_URL_EU_WEST_1="<from terraform output>"
export COGNITO_USERNAME="tejaswi.devopscloud@gmail.com"
export COGNITO_PASSWORD="Assessment@2024!"

python3 test/test_deployment.py
```

The script will:
1. Authenticate with Cognito and retrieve a JWT.
2. Concurrently call `GET /greet` in both regions.
3. Concurrently call `POST /dispatch` in both regions (triggers ECS tasks).
4. Assert the response `region` matches the requested region.
5. Print latency for each call and a colour-coded PASS/FAIL summary.

---

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy.yml`) runs on every
push/PR to `main` and supports manual triggers via `workflow_dispatch`.

| Stage | What it does |
|-------|-------------|
| **Lint & Validate** | `terraform fmt -check`, `terraform validate` |
| **Security Scan** | `tfsec` + `checkov` static analysis |
| **Plan** | `terraform plan` – uploaded as artifact |
| **Deploy** | `terraform apply` (on push to main or manual) |
| **Test** | Runs `test/test_deployment.py` post-deploy |
| **Destroy** | Manual trigger only (`workflow_dispatch` → destroy) |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `COGNITO_USERNAME` | Test user email |
| `COGNITO_PASSWORD` | Test user password |

---

## Project Structure

```
aws-assessment/
├── .github/workflows/deploy.yml   # CI/CD pipeline
├── .gitignore
├── README.md
├── providers.tf                    # AWS provider config (multi-region)
├── variables.tf                    # Root input variables
├── outputs.tf                      # Root outputs
├── main.tf                         # Wires modules together
├── terraform.tfvars                # Default values
├── modules/
│   ├── cognito/                    # Cognito User Pool + Client + test user
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── regional-stack/             # Identical per-region infrastructure
│       ├── variables.tf
│       ├── outputs.tf
│       ├── vpc.tf                  # VPC (public-only, no NAT)
│       ├── dynamodb.tf             # GreetingLogs table
│       ├── iam.tf                  # IAM roles & policies
│       ├── lambda.tf               # Greeter + Dispatcher Lambdas
│       ├── api_gateway.tf          # HTTP API + Cognito JWT authorizer
│       └── ecs.tf                  # ECS Fargate cluster + task
├── lambdas/
│   ├── greeter/index.py            # GET /greet handler
│   └── dispatcher/index.py         # POST /dispatch handler
├── test/
│   ├── test_deployment.py          # Integration test script
│   └── requirements.txt
└── scripts/
    ├── validate.sh                 # Local lint/validate helper
    └── run_tests.sh                # Extract TF outputs & run tests
```

---

## Cost Optimisation Notes

- **No NAT Gateway** – Fargate tasks run in public subnets with `assignPublicIp = ENABLED`.
- **DynamoDB PAY_PER_REQUEST** – zero idle cost.
- **Fargate 0.25 vCPU / 512 MB** – minimum task size.
- **Container Insights disabled** – avoids extra CloudWatch charges.
- **CloudWatch log retention = 7 days**.

---

## Teardown

```bash
terraform destroy -var-file=terraform.tfvars
```

> **Remember:** Destroy immediately after running your tests to avoid ongoing AWS charges.
