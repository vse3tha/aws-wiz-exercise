# Presentation Outline

## 1. Objective and scope
- Build a two-tier AWS application with intentional cloud, Kubernetes, and DevOps weaknesses.
- Demonstrate secure engineering discipline through IaC, CI/CD, audit logging, detection, and preventative controls.

## 2. Architecture
- Public ALB created by Kubernetes Ingress.
- EKS worker nodes deployed in private subnets.
- Node.js todo container uses MongoDB via `MONGO_URI` Kubernetes environment variable.
- MongoDB 5.0 runs on Amazon Linux 2 EC2 in a public subnet.
- MongoDB backup runs daily to a public/listable S3 bucket.

## 3. Intentional weaknesses
- Public SSH to MongoDB VM.
- Outdated Linux baseline: Amazon Linux 2.
- Outdated MongoDB version: MongoDB 5.0.
- EC2 instance profile has AmazonEC2FullAccess.
- S3 backup bucket allows public read and public list.
- Application service account is bound to cluster-admin.

## 4. DevOps/IaC approach
- Terraform provisions AWS infrastructure.
- Kubernetes manifests are rendered from templates.
- Docker builds the application image and embeds `wizexercise.txt`.
- GitHub Actions pipelines handle Terraform and application deployment.

## 5. Security controls
- EKS control plane logging enabled, including audit logs.
- GuardDuty enabled with EKS audit log monitoring.
- AWS Config rules flag public S3 read/list and public SSH.
- ECR scan-on-push and Trivy scan in CI.
- AWS WAFv2 attached to the public ALB through Ingress annotation.

## 6. Demo flow
1. Show Terraform outputs and architecture.
2. Show `kubectl get nodes` and pods in private subnets.
3. Open the app through ALB and add a todo item.
4. Query MongoDB to prove persistence.
5. Exec into pod and cat `/app/wizexercise.txt`.
6. Show S3 backup object and public listing.
7. Show AWS Config non-compliance and GuardDuty/EKS audit logging.
8. Show CI/CD pipeline and scan results.

## 7. Production remediation view
- Remove public SSH; use SSM Session Manager or bastion with just-in-time access.
- Replace EC2 MongoDB with DocumentDB, Atlas, or a hardened MongoDB deployment.
- Upgrade OS and MongoDB.
- Make S3 private, encrypted with CMK, lifecycle-managed, and access-logged.
- Replace cluster-admin RBAC with least privilege.
- Use Secrets Manager/External Secrets rather than plaintext Kubernetes Secret templates.

## DevSecOps / VCS / SCM evidence slide

- GitHub repository stores Terraform, Kubernetes manifests, Dockerfile, app source, and pipeline-as-code.
- Infrastructure pipeline: Terraform fmt/validate/plan/apply, TFLint, Checkov IaC scanning, SARIF upload.
- Application pipeline: AMD64 Docker Buildx image, Trivy scan, ECR push, EKS deployment through kubectl.
- Code scanning: CodeQL for Node.js application source.
- Repository controls: branch protection, PR approvals, required checks, secret scanning, Dependabot.
- AWS access pattern: GitHub OIDC role preferred; manual deployment fallback where lab SCP blocks IAM/OIDC.
