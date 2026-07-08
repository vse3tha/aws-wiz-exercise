module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name    = local.cluster_name
  cluster_version = var.eks_kubernetes_version

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = [var.admin_cidr]

  # Required cloud-native audit control.
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    app = {
      name           = "app-private-ng"
      subnet_ids     = module.vpc.private_subnets
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }
}

module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                              = "${local.cluster_name}-aws-lbc"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Optional. In a fresh one-pass apply, the EKS API may not yet authorize the Kubernetes provider.
# Default is false; install the controller with scripts/install_aws_lbc.sh after kubeconfig works.
resource "kubernetes_service_account" "aws_lbc" {
  count = var.manage_aws_load_balancer_controller_with_terraform ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.aws_load_balancer_controller_irsa.iam_role_arn
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "aws_lbc" {
  count = var.manage_aws_load_balancer_controller_with_terraform ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [kubernetes_service_account.aws_lbc]
}
