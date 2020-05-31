provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "kubernetes-the-hard-way"
  cidr = "10.240.0.0/22"

  azs             = ["us-east-1a"]
  private_subnets = ["10.240.0.0/24"]
  public_subnets  = ["10.240.1.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Terraform = "true"
  }
}

module "elb" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 2.0"

  name = "kubernetes-the-hard-way"

  subnets         = module.vpc.public_subnets
  security_groups = [module.sg_allow_external.this_security_group_id]

  listener = [
    {
      instance_port     = "6443"
      instance_protocol = "TCP"
      lb_port           = "6443"
      lb_protocol       = "TCP"
    }
  ]

  health_check = {
    target              = "TCP:6443"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  number_of_instances = module.k8s_controllers.instance_count
  instances           = module.k8s_controllers.id

  tags = {
    Terraform = "true"
  }
}

data "http" "my_ip" {
  url = "http://ifconfig.me/ip"
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
    "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
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

data "aws_eip" "this" {
  filter {
    name   = "tag:Name"
    values = ["kubernetes-the-hard-way-*"]
  }
}

module "sg_allow_external" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "kubernetes-the-hard-way-allow-external"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["${data.http.my_ip.body}/32", "${data.aws_eip.this.public_ip}/32"]
  ingress_rules       = ["kubernetes-api-tcp"]
  egress_rules        = ["all-all"]
}

data "template_file" "user_data" {
  template = "${file("user-data.tpl")}"
}

module "k8s_controllers" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name           = "controller"
  instance_count = 3

  ami                    = "ami-05801d0a3c8e4c443"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.sg_allow_internal.this_security_group_id]
  subnet_ids             = module.vpc.private_subnets
  private_ips            = ["10.240.0.10", "10.240.0.11", "10.240.0.12"]
  iam_instance_profile   = module.k8s_role.this_iam_instance_profile_name
  key_name               = aws_key_pair.this.key_name
  user_data              = data.template_file.user_data.rendered

  tags = {
    Terraform = "true"
  }
}

module "sg_allow_internal" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "kubernetes-the-hard-way-allow-internal"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_rules       = ["all-udp", "all-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "k8s_workers" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name           = "worker"
  instance_count = 3

  ami                    = "ami-05801d0a3c8e4c443"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [module.sg_allow_internal.this_security_group_id]
  subnet_ids             = module.vpc.private_subnets
  private_ips            = ["10.240.0.20", "10.240.0.21", "10.240.0.22"]
  iam_instance_profile   = module.k8s_role.this_iam_instance_profile_name
  key_name               = aws_key_pair.this.key_name
  user_data              = data.template_file.user_data.rendered

  tags = {
    Terraform = "true"
  }
}
