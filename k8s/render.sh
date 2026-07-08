#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE_URI:?IMAGE_URI is required}"
: "${MONGO_PRIVATE_IP:?MONGO_PRIVATE_IP is required}"
: "${MONGO_APP_USER:?MONGO_APP_USER is required}"
: "${MONGO_APP_PASSWORD:?MONGO_APP_PASSWORD is required}"
: "${WAF_ACL_ARN:?WAF_ACL_ARN is required}"

mkdir -p rendered
cp namespace.yaml rbac.yaml service.yaml rendered/

export MONGO_URI="mongodb://${MONGO_APP_USER}:${MONGO_APP_PASSWORD}@${MONGO_PRIVATE_IP}:27017/wizexercise?authSource=wizexercise"

envsubst < secret.yaml.tpl > rendered/secret.yaml
envsubst < deployment.yaml.tpl > rendered/deployment.yaml
envsubst < ingress.yaml.tpl > rendered/ingress.yaml

echo "Rendered manifests written to k8s/rendered/"
