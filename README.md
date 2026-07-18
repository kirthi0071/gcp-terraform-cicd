In this article, we will be creating an automated CI/CD pipeline for a Terraform project on Google Cloud Platform, with a focus on adhering to security and coding best practices. The pipeline is built using GitHub Actions and is designed to trigger automatically on every push to GitHub, encompassing code analysis (TFLint), security analysis (tfsec), infrastructure testing (Terratest), and the typical Terraform workflow stages - initialization, planning, and applying changes. Authentication to GCP is handled through Workload Identity Federation rather than static service account keys, so the pipeline never depends on a long-lived secret.

***Let's understand the purpose of all these tools within our CI/CD pipeline.***

**TFLint** is a popular open-source static analysis tool designed for Terraform. It performs automated checks on Terraform configurations to identify potential issues, errors, and violations of best practices. TFLint helps maintain code quality, consistency, and reliability in Terraform projects.

**Tfsec** is a static analysis tool used to scan Terraform code to identify security gaps in IaC. It analyzes Terraform codebases to identify potential security issues such as misconfigurations, insecure settings, and other issues that might expose infrastructure to risks.

**Terratest** is an open source testing framework for infrastructure defined using Terraform. It performs unit tests, integration tests, and end-to-end tests for the cloud-based infrastructure and helps identify security vulnerabilities early on.

# The Problem: Before This Pipeline

Without an automated CI/CD pipeline, managing Terraform infrastructure on GCP typically looks like this:

- **Manual `terraform apply` from a laptop** - someone runs Terraform commands locally, with no consistent record of who applied what, or when
- **No automated code review for infrastructure** - bad Terraform syntax, unused variables, or bad practices only get caught when `terraform apply` fails, or worse, after resources are already misconfigured in production
- **No security gate** - misconfigurations like a firewall rule open to `0.0.0.0/0`, a VM with a public IP it doesn't need, or disabled disk encryption go unnoticed until an actual security review - which might be too late
- **No proof the infrastructure actually works** - a `terraform plan` succeeding doesn't mean the infrastructure functions correctly once deployed; without automated testing, that's only found out by manually checking after every change
- **Credentials risk** - the common shortcut is a downloadable service account JSON key, stored as a secret somewhere, which is a long-lived credential that can leak, get committed by accident, or outlive its need.

In short: infrastructure changes were slow to validate, inconsistent, and dependent on someone remembering to run the right checks by hand.

# What We Achieved

By building this pipeline, every one of those gaps is closed automatically, on every push:

- **Push-triggered automation** - any change to `main` triggers the full pipeline with zero manual steps
- **Automated code quality checks** - TFLint catches bad Terraform syntax and undeclared variables before anything is planned
- **Automated security scanning** - tfsec inspects every resource for real security issues (public ingress, missing encryption, exposed instances) and fails the pipeline if something's wrong, forcing a fix before merge
- **Validated, safe planning** -`terraform plan` runs in CI to confirm the configuration is deployable, without touching real infrastructure
- **Proof the infrastructure works, not just plans** - Terratest actually deploys the infrastructure, checks it produces the correct outputs, and tears it down again automatically - so a passing pipeline means the infrastructure genuinely functions, not just that the code is syntactically valid
- **No long-lived credentials anywhere** - Workload Identity Federation lets GitHub Actions authenticate to GCP using short-lived tokens tied to the specific repository, so there's no static key to leak or manage
- **Repeatable and safe to run often** - because Terratest always destroys what it creates (even on failure), the pipeline can run on every single push without accumulating cost or orphaned resources

# Step 1: Install Terraform on your Mac

Use Homebrew  - it's the cleanest way and handles upgrades well.

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

!Screen Shot 2026-07-18 at 10.02.51 AM.png

Then verify:

brew --version

brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform -version

While we're at it, since you'll be on GCP, also grab the `gcloud` CLI if you don't have it yet:

brew install --cask google-cloud-sdk
gcloud init
gcloud auth application-default login

!Screen Shot 2026-07-18 at 10.11.38 AM.png

# Step 2: Project structure (modules-based)

<aside>
🗂️

**Repository layout (Terraform modules + environment root)**

```
gcp-terraform-cicd/
├── modules/
│   ├── vpc/                 # network primitives (VPC, subnets, routes)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── firewall-rules/      # ingress/egress rules
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── vm/                  # compute resources (instances, templates)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   └── dev/                 # env root that composes modules
│       ├── main.tf          # calls modules
│       ├── variables.tf
│       ├── terraform.tfvars # env-specific values
│       ├── outputs.tf
│       └── backend.tf       # GCS backend for Terraform state
├── test/
│   └── main_test.go         # Terratest (GCP)
├── .tflint.hcl              # lint config
├── Jenkinsfile              # CI pipeline
└── .gitignore
```

</aside>

# Step 3: GCP authentication and project setup

Before Terraform can talk to GCP, you need credentials on your machine.

gcloud auth login
gcloud auth application-default login

# Step 4: Create the GCS backend for remote state

!Screen Shot 2026-07-18 at 6.29.25 PM.png

# Step 5: Harden the Terraform config with tfsec

Running `tfsec` locally (or in CI) against a first-draft config typically surfaces real findings — public firewall ingress, VMs with public IPs, missing Shielded VM settings, disk encryption, VPC flow logs. Rather than suppress them blindly, fix the underlying resources:

- Scope SSH `source_ranges` to a specific IP, not `0.0.0.0/0`
- Drop the `access_config {}` block on the VM to remove its public IP
- Add `shielded_instance_config` with `enable_vtpm` and `enable_integrity_monitoring`
- Add `block-project-ssh-keys` to instance metadata
- Add `log_config` to the subnet for VPC flow logs

# Step 6: Wire up GitHub Actions with Workload Identity Federation (no long-lived keys)

Rather than generating a downloadable service account JSON key, use WIF so GitHub's OIDC tokens authenticate directly:

gcloud iam workload-identity-pools create "github-pool" \
--project="YOUR_PROJECT_ID" --location="global"

gcloud iam workload-identity-pools providers create-oidc "github-provider" \
--project="YOUR_PROJECT_ID" --location="global" \
--workload-identity-pool="github-pool" \
--attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
--attribute-condition="assertion.repository=='YOUR_GH_USER/YOUR_REPO'" \
--issuer-uri="https://token.actions.githubusercontent.com"

gcloud iam service-accounts create github-actions-tf

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
--member="serviceAccount:github-actions-tf@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
--role="roles/editor"

gcloud iam service-accounts add-iam-policy-binding \
"github-actions-tf@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
--role="roles/iam.workloadIdentityUser" \
--member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GH_USER/YOUR_REPO"

Note the `--attribute-condition` flag — recent GCP versions require this explicitly, restricting which repos can impersonate the service account.

# Step 7: The pipeline — lint, scan, plan, test

The GitHub Actions workflow (`.github/workflows/terraform.yml`) runs four jobs in sequence: static lint, a security scan, a Terraform plan (validation only, no real resources), and finally Terratest, which is the only job that actually creates and destroys infrastructure.

name: Terraform CI/CD

on:
push:
branches: [main]
pull_request:
branches: [main]

env:
TF_WORKING_DIR: environments/dev
GCP_PROJECT_ID: YOUR_PROJECT_ID
WIF_PROVIDER: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
WIF_SERVICE_ACCOUNT: 'github-actions-tf@YOUR_PROJECT_ID.iam.gserviceaccount.com'

jobs:
lint:
name: TFLint
runs-on: ubuntu-latest
steps:
- uses: actions/checkout@v4
- uses: terraform-linters/setup-tflint@v4
with:
tflint_version: latest
- name: Run TFLint
working-directory: ${{ env.TF_WORKING_DIR }}
run: |
tflint --init
tflint

tfsec:
name: tfsec Security Scan
runs-on: ubuntu-latest
steps:
- uses: actions/checkout@v4
- name: Install tfsec
run: |
curl -L https://github.com/aquasecurity/tfsec/releases/download/v1.28.10/tfsec-linux-amd64 -o tfsec
chmod +x tfsec
sudo mv tfsec /usr/local/bin/tfsec
- name: Run tfsec
run: tfsec ${{ env.TF_WORKING_DIR }} --no-color

terraform:
name: Terraform Plan
needs: [lint, tfsec]
runs-on: ubuntu-latest
permissions:
contents: read
id-token: write
defaults:
run:
working-directory: ${{ env.TF_WORKING_DIR }}
steps:
- uses: actions/checkout@v4

```
  - name: Authenticate to GCP
    uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: ${{ env.WIF_PROVIDER }}
      service_account: ${{ env.WIF_SERVICE_ACCOUNT }}

  - name: Set up Terraform
    uses: hashicorp/setup-terraform@v3

  - name: Terraform Init
    run: terraform init

  - name: Terraform Plan
    run: terraform plan
```

terratest:
name: Terratest
needs: terraform
runs-on: ubuntu-latest
permissions:
contents: read
id-token: write
steps:
- uses: actions/checkout@v4

```
  - name: Authenticate to GCP
    uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: ${{ env.WIF_PROVIDER }}
      service_account: ${{ env.WIF_SERVICE_ACCOUNT }}

  - name: Set up Go
    uses: actions/setup-go@v5
    with:
      go-version: '1.23'

  - name: Set up Terraform
    uses: hashicorp/setup-terraform@v3

  - name: Run Terratest
    working-directory: test
    run: go test -v -timeout 30m
```

A few decisions worth calling out:

- **tfsec runs as a pinned binary, not the marketplace action.** The `aquasecurity/tfsec-action` wrapper depends on GitHub's release API and `jq` under the hood — pinning a direct binary download sidesteps that entirely and gives cleaner, unfiltered scan output.
- **`terraform` only runs `plan`, never `apply`.** This job exists purely to validate the configuration is syntactically and semantically deployable. No real resources get created here.
- **`terratest` is the only job that touches real infrastructure.** It runs `InitAndApply`, asserts against the outputs, then always destroys — win or lose — via a deferred cleanup call in the Go test itself.
- **Authentication uses Workload Identity Federation**, not a static JSON key — no long-lived secret sits in GitHub at all.

# Step 8: Terratest — pin your Go dependencies

The Terratest file itself (`test/main_test.go`) is straightforward — it applies the Terraform config, checks a couple of outputs, then tears everything down:

package test

import (
"testing"

```
"github.com/gruntwork-io/terratest/modules/terraform"
"github.com/stretchr/testify/assert"
```

)

func TestTerraformGCPInfra(t *testing.T) {
terraformOptions := &terraform.Options{
TerraformDir: "../environments/dev",
}

```
defer terraform.Destroy(t, terraformOptions)

terraform.InitAndApply(t, terraformOptions)

vmName := terraform.Output(t, terraformOptions, "vm_name")
assert.Equal(t, "test-instance", vmName)

vpcID := terraform.Output(t, terraformOptions, "vpc_id")
assert.NotEmpty(t, vpcID)
```

}

Github Code Link : https://github.com/kirthi0071/gcp-terraform-cicd.git
