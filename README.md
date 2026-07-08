# AWS Wiz Exercise Lab - Two-Tier Web App with Intentional Weaknesses

## Restricted AWS lab / SCP-safe deployment

Some AWS training accounts centrally manage GuardDuty and AWS Config through AWS Organizations. If you see an error such as `explicit deny in a service control policy` for `guardduty:ListDetectors`, do not run `aws guardduty list-detectors` and do not try to import or create GuardDuty. Use the restricted lab profile below.

```bash
cd terraform
cp lab-restricted.auto.tfvars.example lab-restricted.auto.tfvars
terraform plan -out tfplan
terraform apply tfplan
```

This skips GuardDuty API calls entirely while still deploying the lab workload, EKS audit logging, AWS WAF, and AWS Config managed rules when Config rule creation is permitted. If Config rule creation is also denied by SCP, edit `lab-restricted.auto.tfvars` and set:

```hcl
enable_config_rules = false
```

Then rerun `terraform plan` and `terraform apply`.


This starter repository builds a disposable AWS lab environment for the requested exercise:

- Public internet-facing AWS ALB -> EKS private-node Kubernetes app
- Containerized Node.js todo application using MongoDB
- MongoDB 5.0 running on an EC2 VM with Amazon Linux 2
- Public SSH on the MongoDB VM as an intentional weakness
- Publicly readable/listable S3 bucket for MongoDB backups as an intentional weakness
- EC2 instance profile with EC2FullAccess as an intentional over-permission weakness
- Kubernetes service account bound to cluster-admin as an intentional weakness
- EKS control plane audit logging, GuardDuty, AWS Config rules, and AWS WAFv2 as controls

> Use only in an isolated lab account/VPC. Do not deploy this in production or a shared corporate account.

## Architecture

```text
Internet
  |
  | HTTP :80
  v
AWS Application Load Balancer, created by AWS Load Balancer Controller
  |
  v
EKS worker nodes in private subnets
  |
  v
Node.js todo container, ServiceAccount intentionally bound to cluster-admin
  |
  | MONGO_URI environment variable
  v
MongoDB 5.0 on EC2 in public subnet
  |  - SSH open to 0.0.0.0/0 intentionally
  |  - MongoDB 27017 restricted to EKS node security group
  |  - EC2 role intentionally has AmazonEC2FullAccess
  v
Daily mongodump backup -> public/listable S3 bucket intentionally
```

## Prerequisites

Install:

- Terraform >= 1.6
- AWS CLI v2
- kubectl
- Docker
- GitHub account if using CI/CD

Create an SSH key for the EC2 VM:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/wizexercise -C wizexercise
export TF_VAR_ssh_public_key="$(cat ~/.ssh/wizexercise.pub)"
```

Configure AWS credentials for your lab account:

```bash
aws configure
aws sts get-caller-identity
```

## Deploy infrastructure

```bash
cd terraform
terraform init
terraform plan -out tfplan
terraform apply tfplan

# If the lab account already has GuardDuty and AWS Config enabled, use:
# DETECTOR_ID=$(aws guardduty list-detectors --query "DetectorIds[0]" --output text)
# terraform plan -out tfplan \
#   -var="create_guardduty_detector=false" \
#   -var="existing_guardduty_detector_id=${DETECTOR_ID}" \
#   -var="create_config_recorder=false"
# terraform apply tfplan
```

Capture outputs:

```bash
terraform output
export AWS_REGION=$(terraform output -raw aws_region)
export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export ECR_REPO=$(terraform output -raw ecr_repository_url)
export MONGO_PRIVATE_IP=$(terraform output -raw mongodb_private_ip)
export WAF_ACL_ARN=$(terraform output -raw waf_web_acl_arn)
```

Update kubeconfig and install the AWS Load Balancer Controller:

```bash
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl get nodes -o wide
../scripts/install_aws_lbc.sh
```

The AWS Load Balancer Controller is intentionally installed after the cluster is reachable. This avoids a common one-pass Terraform failure where the Kubernetes provider tries to create service accounts before the new EKS cluster has authorized the caller. If you prefer Terraform to manage the Helm release, run a second apply after kubeconfig works with `-var="manage_aws_load_balancer_controller_with_terraform=true"`.

## Build and push application image

```bash
cd ../app
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${ECR_REPO%/*}"
docker build -t wizexercise-todo:local .
docker tag wizexercise-todo:local "${ECR_REPO}:$(git rev-parse --short HEAD 2>/dev/null || echo local)"
docker tag wizexercise-todo:local "${ECR_REPO}:latest"
docker push "${ECR_REPO}:latest"
```

## Deploy Kubernetes app

Create the app secret and apply manifests:

```bash
cd ../k8s
export MONGO_APP_USER="appuser"
export MONGO_APP_PASSWORD="$(cd ../terraform && terraform output -raw mongo_app_password)"
export IMAGE_URI="${ECR_REPO}:latest"

./render.sh
kubectl apply -f rendered/
kubectl -n wizexercise rollout status deployment/wizexercise-todo
kubectl -n wizexercise get ingress
```

Get the ALB DNS name:

```bash
export APP_URL="http://$(kubectl -n wizexercise get ingress wizexercise-todo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "$APP_URL"
curl "$APP_URL/healthz"
```

## Validation commands for the demo

### 1. Show EKS and kubectl access

```bash
kubectl get nodes -o wide
kubectl get pods -n wizexercise -o wide
kubectl describe ingress -n wizexercise wizexercise-todo
```

### 2. Validate `wizexercise.txt` inside the running container

```bash
POD=$(kubectl -n wizexercise get pod -l app=wizexercise-todo -o jsonpath='{.items[0].metadata.name}')
kubectl -n wizexercise exec "$POD" -- cat /app/wizexercise.txt
```

Expected output:

```text
Vamshidhar’s Seetha
```

### 3. Prove the app writes to MongoDB

```bash
curl -s -X POST "$APP_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -d '{"text":"demo item from API"}' | jq
curl -s "$APP_URL/api/todos" | jq
```

### 4. Prove MongoDB contains the data

```bash
cd ../terraform
export MONGO_EC2_PUBLIC_IP=$(terraform output -raw mongodb_public_ip)
ssh -i ~/.ssh/wizexercise ec2-user@$MONGO_EC2_PUBLIC_IP
sudo docker exec -it mongo mongosh -u root -p '<root password from terraform output>' --authenticationDatabase admin
use wizexercise
db.todos.find().pretty()
```

### 5. Prove daily backup and public listing/read weakness

```bash
cd terraform
export BACKUP_BUCKET=$(terraform output -raw backup_bucket_name)
aws s3 ls "s3://${BACKUP_BUCKET}/mongo-backups/"

# Public listing weakness demo. This works only if lab account-level S3 Block Public Access is not blocking public policies.
curl "https://${BACKUP_BUCKET}.s3.amazonaws.com/?list-type=2"
```

### 6. Show intentional weak configurations

```bash
aws ec2 describe-security-groups --group-ids $(terraform output -raw mongodb_security_group_id) \
  --query 'SecurityGroups[0].IpPermissions'

aws iam list-attached-role-policies --role-name $(terraform output -raw mongodb_role_name)

kubectl get clusterrolebinding wizexercise-todo-cluster-admin -o yaml
```

### 7. Show security controls

```bash
# EKS control plane logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/${CLUSTER_NAME}/cluster"

# AWS Config flags the public S3 and public SSH conditions as NON_COMPLIANT
aws configservice describe-compliance-by-config-rule

# GuardDuty detector
aws guardduty list-detectors
```

## GitHub CI/CD setup

Create an AWS IAM role trusted by GitHub OIDC with permissions for Terraform deploy and ECR/EKS deploy.
Then add these GitHub repository variables/secrets:

Repository variables:

- `AWS_REGION`
- `EKS_CLUSTER_NAME`
- `ECR_REPOSITORY`
- `MONGO_PRIVATE_IP`
- `WAF_ACL_ARN`

Repository secrets:

- `AWS_GITHUB_OIDC_ROLE_ARN`
- `TF_VAR_ssh_public_key`
- `MONGO_APP_USER`
- `MONGO_APP_PASSWORD`

Pipelines included:

- `.github/workflows/infra.yml` - validates/scans/applies Terraform
- `.github/workflows/app.yml` - scans/builds/pushes container and deploys Kubernetes manifests

## Teardown

Delete Kubernetes resources before destroying Terraform, so the ALB is removed cleanly:

```bash
kubectl delete -f k8s/rendered/ || true
cd terraform
terraform destroy
```

If Terraform fails because the ALB still exists, wait 3-5 minutes and rerun `terraform destroy`.
