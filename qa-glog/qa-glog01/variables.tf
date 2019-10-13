variable "aws_region" {
    description = "AWS region in which to launch servers"
    default = "us-east-2"
}

variable "aws_key_pair" {
    default = "test1"
}

variable "environment_type" {
    default = "Nonproduction"
}

variable "environment_global_name" {
    default = "qa-glog01"
}

variable "cluster_global_name" {
    default = "qa-glog01-cluster"
}

variable "es_domain_name" {
    default = "qa-es-glog"
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
    default = "ryan.woo@modmed.com"
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

variable "modmed_office_ips" {
    description = "list of office IPs to whitelist for a resource"
    type        = list(string)

    default = [
        "170.55.9.200/29",
        "12.239.166.88/29",
        "199.27.240.88/29",
        "170.55.31.88/29",
        "170.55.15.128/27",
        "12.244.206.16/28",
        "12.97.63.32/29",
        "45.73.148.208/29",
        "50.235.138.160/29",
        "199.189.197.88/29",
        "45.73.146.216/29",
        "50.234.77.0/29",
        "54.82.252.213/32",
        "52.23.97.91/32",
    ]
}

variable "management_ips" {
    description = "list of management host IPs to whitelist for a resource. devops-east, devops-west, ansible"
    type        = list(string)

    default = [
        "52.5.41.47/32",
        "54.84.24.5/32",
        "52.43.154.159/32",
    ]
}

variable "monitoring_ips" {
    description = "list of monitoring IPs to whitelist for a resource. Opsview6 East and West collector"
    type        = list(string)

    default = [
        "50.19.185.230/32",
        "52.27.8.196/32",
    ] 
}