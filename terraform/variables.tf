variable "aws_region" {
  description = "AWS region for the lab deployment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for resources."
  type        = string
  default     = "wizexercise-vamshi"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.60.0.0/16"
}

variable "eks_kubernetes_version" {
  description = "EKS Kubernetes version. Adjust to a version supported in your selected region."
  type        = string
  default     = "1.32"
}

variable "admin_cidr" {
  description = "CIDR allowed to reach EKS public API endpoint. Set to your public IP/32 for a tighter lab."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_ingress_cidr" {
  description = "Intentional weakness: SSH exposed publicly. Keep 0.0.0.0/0 only in the lab account."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key" {
  description = "Public SSH key material for the MongoDB EC2 VM. Example: contents of ~/.ssh/wizexercise.pub."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.ssh_public_key) > 20
    error_message = "Pass a valid SSH public key via TF_VAR_ssh_public_key."
  }
}

variable "app_port" {
  description = "Application container port."
  type        = number
  default     = 3000
}

variable "manage_aws_load_balancer_controller_with_terraform" {
  description = "Set true only after the EKS cluster is created and the Terraform identity has Kubernetes cluster-admin access. Default false avoids one-pass Kubernetes provider Unauthorized failures."
  type        = bool
  default     = false
}

variable "create_guardduty_detector" {
  description = "Create a new GuardDuty detector. Keep false in restricted lab accounts where GuardDuty APIs are blocked by SCP or already centrally managed."
  type        = bool
  default     = false
}

variable "existing_guardduty_detector_id" {
  description = "Existing GuardDuty detector ID to use when create_guardduty_detector=false. Leave empty to skip detector feature management."
  type        = string
  default     = ""
}

variable "enable_guardduty_eks_audit_feature" {
  description = "Enable GuardDuty EKS audit log monitoring on the detector Terraform manages or the detector ID supplied above. Keep false when GuardDuty APIs are blocked by SCP."
  type        = bool
  default     = false
}

variable "create_config_recorder" {
  description = "Create AWS Config recorder and delivery channel. Keep false in shared/restricted lab accounts because AWS Config allows only one recorder and delivery channel per account/region."
  type        = bool
  default     = false
}

variable "enable_config_rules" {
  description = "Create AWS Config managed rules used to detect the intentional public S3 and public SSH weaknesses. Requires AWS Config to be enabled in the region."
  type        = bool
  default     = true
}
