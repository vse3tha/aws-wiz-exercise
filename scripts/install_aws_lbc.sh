#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"

AWS_REGION="${AWS_REGION:-$(cd "$TF_DIR" && terraform output -raw aws_region)}"
CLUSTER_NAME="${CLUSTER_NAME:-$(cd "$TF_DIR" && terraform output -raw eks_cluster_name)}"
LBC_ROLE_ARN="${LBC_ROLE_ARN:-$(cd "$TF_DIR" && terraform output -raw aws_load_balancer_controller_role_arn)}"
VPC_ID="${VPC_ID:-$(cd "$TF_DIR" && terraform output -raw vpc_id 2>/dev/null || true)}"

if [[ -z "${VPC_ID}" ]]; then
  VPC_ID="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.vpcId' --output text)"
fi

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

kubectl -n kube-system create serviceaccount aws-load-balancer-controller \
  --dry-run=client -o yaml \
  | kubectl apply -f -

kubectl -n kube-system annotate serviceaccount aws-load-balancer-controller \
  "eks.amazonaws.com/role-arn=${LBC_ROLE_ARN}" \
  --overwrite

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=5m
kubectl -n kube-system get deployment aws-load-balancer-controller
