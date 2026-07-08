# DevSecOps / VCS / SCM Runbook

This runbook adds the DevSecOps proof points required by the exercise.

## 1. VCS / SCM evidence

Use GitHub as the source control platform.

```bash
git init
git add .
git commit -m "Initial Wiz exercise AWS EKS MongoDB lab"
git branch -M main
git remote add origin git@github.com:<your-user-or-org>/aws-wiz-exercise.git
git push -u origin main
```

Evidence to show in the demo:

- GitHub repository with Terraform, Kubernetes manifests, Dockerfile, application code, and GitHub Actions workflows.
- Commit history showing infrastructure and application changes.
- Pull request showing security scans and Terraform plan before merge.

## 2. GitHub repository security controls

Enable these in GitHub repository settings:

- Require pull request before merging to `main`.
- Require status checks: `infra-iac`, `app-build-scan-push-deploy`, and `codeql-sast`.
- Enable branch protection for `main`.
- Enable secret scanning and push protection.
- Enable Dependabot alerts and Dependabot security updates.
- Enable CodeQL code scanning.

## 3. GitHub repository variables

Add these under Settings → Secrets and variables → Actions → Variables:

| Variable | Example |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY` | `732088327045.dkr.ecr.us-east-1.amazonaws.com/wizexercise-vamshi/todo-app` |
| `EKS_CLUSTER_NAME` | `wizexercise-vamshi-eks` |
| `MONGO_PRIVATE_IP` | Terraform output `mongodb_private_ip` |
| `WAF_ACL_ARN` | Terraform output `waf_web_acl_arn` |

Commands to collect values:

```bash
cd terraform
terraform output -raw aws_region
terraform output -raw ecr_repository_url
terraform output -raw eks_cluster_name
terraform output -raw mongodb_private_ip
terraform output -raw waf_web_acl_arn
```

## 4. GitHub repository secrets

Add these under Settings → Secrets and variables → Actions → Secrets:

| Secret | Source |
|---|---|
| `AWS_GITHUB_OIDC_ROLE_ARN` | Output from the optional OIDC role stack |
| `TF_VAR_SSH_PUBLIC_KEY` | `cat ~/.ssh/wizexercise.pub` |
| `MONGO_APP_USER` | `appuser` |
| `MONGO_APP_PASSWORD` | `terraform output -raw mongo_app_password` |

If the lab account blocks IAM/OIDC, do not add long-lived AWS access keys unless the recruiter explicitly permits it. Instead, run the deploy from your lab terminal and still use GitHub Actions for scans.

## 5. CI/CD pipeline 1: Infrastructure as Code

Workflow: `.github/workflows/infra.yml`

Controls included:

- OIDC federation to AWS instead of static cloud keys.
- Terraform fmt, init, validate, plan, and apply.
- TFLint for Terraform linting.
- Checkov for IaC misconfiguration scanning.
- Scan findings uploaded as SARIF to GitHub code scanning.
- Apply allowed only on push to `main`; pull requests run validation and plan only.

## 6. CI/CD pipeline 2: Application build and deployment

Workflow: `.github/workflows/app.yml`

Controls included:

- Builds a Linux AMD64 image with Docker Buildx.
- Tags image with immutable Git commit SHA and `latest`.
- Scans the image with Trivy before push/deploy.
- Uploads Trivy SARIF to GitHub code scanning.
- Pushes to Amazon ECR only from `main`.
- Updates Kubernetes deployment using rendered manifests.

## 7. Code scanning pipeline

Workflow: `.github/workflows/codeql.yml`

Controls included:

- CodeQL static analysis for the JavaScript/Node.js application.
- Findings visible in GitHub Security → Code scanning alerts.

## 8. How to demonstrate DevSecOps

Demo sequence:

1. Open the GitHub repository and show source-controlled Terraform, Dockerfile, Kubernetes manifests, and workflows.
2. Open branch protection settings for `main`.
3. Open a pull request and show required checks.
4. Show Checkov/TFLint output in the infrastructure workflow.
5. Show Trivy SARIF results in the application workflow.
6. Show CodeQL code scanning alerts or a clean result.
7. Show the container image in ECR with the Git SHA tag.
8. Show `kubectl -n wizexercise get deploy,pods,ingress` proving the pipeline deployed to EKS.

## 9. Suggested presentation wording

"The DevSecOps workflow uses GitHub as the VCS/SCM system. Infrastructure, application code, Docker build logic, Kubernetes manifests, and pipeline definitions are all version-controlled. The IaC pipeline validates Terraform and performs IaC security scanning before deployment. The application pipeline builds a Linux AMD64 image, scans it for vulnerabilities, pushes it to ECR, and deploys it to EKS. Repository controls such as branch protection, pull request approval, CodeQL, secret scanning, Dependabot, and SARIF upload provide shift-left governance before changes reach the cloud environment."
