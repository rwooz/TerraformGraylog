variable "aws_security_group_id" {
    default = "sg-03f59fdc5eb599ae4"
}
variable "target_user_list" {
    type = "list"
    default = ["ec2-user", "ec2-user", "ec2-user"]
}

variable "target_ip_list" {
    type = "list"
    default = ["3.17.59.38", "3.14.10.198", "3.15.173.232"]
}

variable "target_key_list" {
    type = "list"
    default = ["../../test1.pem", "../../test1.pem", "../../test1.pem"]
}

variable "listener_endpoints" {
    type = "list"
    default = ["3.15.10.118", "18.218.57.208", "18.219.76.221"]
}

variable "created_by" {
    default = "https://github.com/rwooz"
}

variable "aws_region" {
    description = "AWS region in which to launch servers"
    default = "us-east-2"
}

