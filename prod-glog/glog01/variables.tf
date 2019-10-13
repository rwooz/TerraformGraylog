variable "aws_region" {
    description = "AWS region in which to launch servers"
    default = "us-east-2"
}

variable "aws_key_pair" {
    default = "test1"
}

variable "environment_type" {
    default = "Production"
}

variable "environment_global_name" {
    default = "glog01"
}

variable "cluster_global_name" {
    default = "glog01-cluster"
}

variable "es_domain_name" {
    default = "es-glog"
}

variable "es_instance_type" {
    default = "r5.large.elasticsearch"
}

variable "es_instances_num" {
    default = 3
}

variable "es_master_type" {
    default = "r5.large.elasticsearch"
}

variable "es_master_instances_num" {
    default = 3
}

variable "es_vol_size" {
    default = 10
}

variable "class_global_name" {
    default = "Production"
}

variable "billing_global_name" {
    default = "Production"
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
variable "master_instance_type" {
    default = "t3a.large"
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

variable "pod_subnet" {
    description = "The subnets to use when creating a podded VPC"
    type        = "list"
    default     = ["1.0/27", "2.0/27", "3.0/27"]
}