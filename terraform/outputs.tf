output "aws_region" {
  value = var.aws_region
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "mongodb_private_ip" {
  value = aws_instance.mongodb.private_ip
}

output "mongodb_public_ip" {
  value = aws_instance.mongodb.public_ip
}

output "mongodb_security_group_id" {
  value = aws_security_group.mongodb.id
}

output "mongodb_role_name" {
  value = aws_iam_role.mongodb.name
}

output "backup_bucket_name" {
  value = aws_s3_bucket.mongo_backups.bucket
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.app.arn
}

output "mongo_app_password" {
  value     = random_password.mongo_app.result
  sensitive = true
}

output "mongo_root_password" {
  value     = random_password.mongo_root.result
  sensitive = true
}

output "kubectl_update_kubeconfig" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "aws_load_balancer_controller_role_arn" {
  value = module.aws_load_balancer_controller_irsa.iam_role_arn
}

output "aws_load_balancer_controller_install" {
  value = "../scripts/install_aws_lbc.sh"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
