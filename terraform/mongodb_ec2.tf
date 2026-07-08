data "aws_ssm_parameter" "amazon_linux_2" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_key_pair" "mongo" {
  key_name   = "${var.project_name}-mongo-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongodb-sg"
  description = "MongoDB EC2 SG with intentional public SSH weakness; MongoDB restricted to EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Intentional weakness: public SSH exposure"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description     = "MongoDB restricted to Kubernetes node security group only"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Outbound internet for package/container pulls and S3 backup"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "mongodb" {
  name = "${var.project_name}-mongodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Intentional weakness: overly permissive CSP permissions; this role can create EC2 instances.
resource "aws_iam_role_policy_attachment" "mongodb_ec2full" {
  role       = aws_iam_role.mongodb.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "mongodb_ssm" {
  role       = aws_iam_role.mongodb.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "mongodb_s3_backup" {
  statement {
    sid    = "WriteBackupsToBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.mongo_backups.arn,
      "${aws_s3_bucket.mongo_backups.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "mongodb_s3_backup" {
  name   = "${var.project_name}-mongodb-s3-backup"
  policy = data.aws_iam_policy_document.mongodb_s3_backup.json
}

resource "aws_iam_role_policy_attachment" "mongodb_s3_backup" {
  role       = aws_iam_role.mongodb.name
  policy_arn = aws_iam_policy.mongodb_s3_backup.arn
}

resource "aws_iam_instance_profile" "mongodb" {
  name = "${var.project_name}-mongodb-profile"
  role = aws_iam_role.mongodb.name
}

resource "aws_instance" "mongodb" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2.value
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mongodb.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mongo.key_name
  iam_instance_profile        = aws_iam_instance_profile.mongodb.name

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/userdata_mongo.sh.tpl", {
    aws_region         = var.aws_region
    backup_bucket      = aws_s3_bucket.mongo_backups.bucket
    mongo_root_user    = "root"
    mongo_root_password = random_password.mongo_root.result
    mongo_app_user     = "appuser"
    mongo_app_password = random_password.mongo_app.result
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-mongodb-al2-mongo50"
  }

  depends_on = [aws_s3_bucket_policy.mongo_backups_public]
}
