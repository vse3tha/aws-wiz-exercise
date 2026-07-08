#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"
export AWS_REGION=$(terraform output -raw aws_region)
export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export BACKUP_BUCKET=$(terraform output -raw backup_bucket_name)
export MONGO_PUBLIC_IP=$(terraform output -raw mongodb_public_ip)

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

kubectl get nodes -o wide
kubectl get pods -n wizexercise -o wide
kubectl get svc,ingress -n wizexercise

POD=$(kubectl -n wizexercise get pod -l app=wizexercise-todo -o jsonpath='{.items[0].metadata.name}')
kubectl -n wizexercise exec "$POD" -- cat /app/wizexercise.txt

APP_URL="http://$(kubectl -n wizexercise get ingress wizexercise-todo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Application URL: $APP_URL"
curl -s "$APP_URL/healthz" | jq
curl -s -X POST "$APP_URL/api/todos" -H 'Content-Type: application/json' -d '{"text":"demo item from API"}' | jq
curl -s "$APP_URL/api/todos" | jq

aws s3 ls "s3://${BACKUP_BUCKET}/mongo-backups/"
curl "https://${BACKUP_BUCKET}.s3.amazonaws.com/?list-type=2" || true

aws configservice describe-compliance-by-config-rule | jq '.ComplianceByConfigRules[] | {rule: .ConfigRuleName, compliance: .Compliance.ComplianceType}'
aws guardduty list-detectors
