provider "aws" {
  region  = "us-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "kubernetes-the-hard-way"
  cidr = "10.240.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.240.1.0/24"]
  public_subnets  = ["10.240.101.0/24", "10.240.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

data "http" "my_ip" {
  url = "http://ifconfig.me/ip"
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "kubernetes"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${data.http.my_ip.body}/32"]
  ingress_rules       = ["ssh-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "k8s_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  trusted_role_services = [
    "ec2.amazonaws.com"
  ]

  create_role             = true
  create_instance_profile = true

  role_name         = "k8s-cluster"
  role_requires_mfa = false

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
  ]
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "kubernetes"
  public_key = tls_private_key.this.public_key_openssh
}

module "k8s_controllers" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name           = "controller"
  instance_count = 3

  ami                    = "ami-05801d0a3c8e4c443"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.security_group.this_security_group_id]
  subnet_ids             = module.vpc.private_subnets
  private_ips            = ["10.240.1.10", "10.240.1.11", "10.240.1.12"]
  iam_instance_profile   = module.k8s_role.this_iam_instance_profile_name
  key_name               = aws_key_pair.this.key_name

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "k8s_workers" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name           = "worker"
  instance_count = 3

  ami                    = "ami-05801d0a3c8e4c443"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.security_group.this_security_group_id]
  subnet_ids             = module.vpc.private_subnets
  private_ips            = ["10.240.1.20", "10.240.1.21", "10.240.1.22"]
  iam_instance_profile   = module.k8s_role.this_iam_instance_profile_name
  key_name               = aws_key_pair.this.key_name

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
