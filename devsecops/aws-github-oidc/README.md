# GitHub Actions to AWS OIDC Role

Use this only if the AWS lab account allows IAM/OIDC changes. Some lab accounts block these actions using AWS Organizations Service Control Policies.

## Deploy

```bash
aws cloudformation deploy \
  --stack-name wizexercise-github-oidc \
  --template-file devsecops/aws-github-oidc/github-oidc-role-cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubOrgOrUser=<your-github-user-or-org> \
    GitHubRepo=aws-wiz-exercise
```

## Get role ARN

```bash
aws cloudformation describe-stacks \
  --stack-name wizexercise-github-oidc \
  --query "Stacks[0].Outputs[?OutputKey=='GitHubActionsRoleArn'].OutputValue" \
  --output text
```

Add the returned ARN as GitHub repository secret `AWS_GITHUB_OIDC_ROLE_ARN`.

## If IAM/OIDC is blocked

Use GitHub Actions for code scanning, IaC scanning, and image scanning only, then perform Terraform apply and kubectl deploy manually from your lab terminal.
