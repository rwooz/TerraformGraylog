variable "aws_region" {
    description = "AWS region in which to launch servers"
    default = "us-east-2"
}

variable "aws_key_pair" {
    default = ""
}

variable "aws_security_group_id" {
    default = ""
}

variable "aws_subnet_ids" {
    type = "list"
    default = []
}

variable "aws_instance_masterglog_public_dns" {
    default = ""
}

variable "aws_instance_masterglog_private_ip" {
    default = ""
}

variable "aws_alb_arn" {
    default = ""
}

variable "aws_nlb_arn" {
    default = ""
}

variable "environment_type" {
    default = "Nonproduction"
}

variable "environment_global_name" {
    default = ""
}

variable "cluster_global_name" {
    default = ""
}

variable "es_domain_name" {
    default = ""
}

variable "class_global_name" {
    default = "Nonproduction"
}

variable "billing_global_name" {
    default = "Nonproduction"
}

variable "environment_domain_name" {
    default = ""
}

variable "environment_certificate_arn" {
    default = ""
}

variable "created_by" {
    default = "https://github.com/rwooz"
}

variable "vpc_cidr_block" {
    default = "10.0.0.0/22"
}

#Graylog requires at least 4(or 2?)GB of memory to work properly
variable "worker_instance_type" {
    default = ""
}

#Should have at least one instance per availability zone
variable "worker_instances_num" {
    default = ""
}

variable "azs" {
  description = "Run the EC2 Instances in these Availability Zones"
  type        = "list"
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "amis" {
    type = "map"
    default = {
        "us-east-1" = "ami-0c6b1d09930fac512" #Amazon Linux 2 AMI (HVM), SSD Volume Type
        "us-east-2" = "ami-0ebbf2179e615c338" #Amazon Linux 2 AMI (HVM), SSD Volume Type
    }
}