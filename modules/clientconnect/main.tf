# Specify the provider and access details
provider "aws" {
    region  = var.aws_region
    version = "~> 2.22"
}

# Create backend with state and lockfile
terraform{
    backend "s3" {
        bucket         = "default-operations"
        key            = "terraform/fluentclient01/fluentclient01.tfstate"
        region         = "us-east-2"
        dynamodb_table = "terraform_locks"
        encrypt        = true
    }
}

# Connect target(s) to security group
resource "aws_security_group_rule" "client_access" {
    count = length(var.target_ip_list)
    type = "ingress"
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["${var.target_ip_list[count.index]}/32"]
    description = "Fluent-bit client access"
    
    security_group_id = var.aws_security_group_id  
}

# Provision and start fluent-bit services on target(s)
resource "null_resource" "bitinstall" {
    count = length(var.target_ip_list)
    connection {
        host = var.target_ip_list[count.index]
        type = "ssh"
        user = var.target_user_list[count.index]
        private_key = "${file(var.target_key_list[count.index])}"
    }
    
    provisioner "file" {
        source = "../../modules/clientconnect/clientconnect-docker"
        destination = "~/"
    }
    
    provisioner "remote-exec" {
        inline = [
            "cd clientconnect-docker",
            "sudo yum update -y",
            "sudo amazon-linux-extras install -y docker",
            "sudo usermod -a -G docker ec2-user",
            "sudo curl -L https://github.com/docker/compose/releases/download/1.24.0/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose",
            "sudo chmod +x /usr/local/bin/docker-compose",
            "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose",
            "sudo service docker start",
            "sudo echo '${var.listener_endpoints[count.index%3]}' >> ./client/td-agent-bit.conf",
            "sudo echo '    Port 24226\n    Match *\n\n[OUTPUT]\n    Name stdout\n    Match **' >> ./client/td-agent-bit.conf",
            "sudo docker-compose build",
            "sudo docker-compose up -d"
        ]
    }
}