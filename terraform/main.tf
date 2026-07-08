locals {
  cluster_name = "${var.project_name}-eks"
  bucket_name  = "${var.project_name}-mongo-backups-${random_id.suffix.hex}"

  tags = {
    Project     = var.project_name
    Environment = "lab"
    Owner       = "Vamshidhar Seetha"
    Purpose     = "WizExercise"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_password" "mongo_root" {
  length  = 20
  special = false
}

resource "random_password" "mongo_app" {
  length  = 20
  special = false
}
