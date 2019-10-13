# Start instance for fluentd listener(s)
resource "aws_instance" "fluentd" {
    ami                         = "${lookup(var.amis, var.aws_region)}"
    #Should have at least one instance per availability zone
    count                       = var.listener_instances_num
    instance_type               = var.listener_instance_type
    key_name                    = var.aws_key_pair
    subnet_id                   = var.aws_subnet_ids[count.index%3]
    vpc_security_group_ids      = [var.aws_security_group_id]
    associate_public_ip_address = "true"
    ebs_optimized               = "true"

    connection {
        host        = self.public_ip
        type        = "ssh"
        user        = "ec2-user"
        private_key = "${file("../../${var.aws_key_pair}.pem")}"
    }
    
    # Provision docker files
    provisioner "file" {
        source = "../../modules/fluentlistener/fluentlistener-docker/"
        destination = "~/"
    }
  
    # Install docker/-compose, connect to swarm as worker, then run fluentd listener
    provisioner "remote-exec" {
        inline = [
            "sudo yum update -y",
            "sudo amazon-linux-extras install -y docker",
            "sudo usermod -a -G docker ec2-user",
            "sudo curl -L https://github.com/docker/compose/releases/download/1.24.0/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose",
            "sudo chmod +x /usr/local/bin/docker-compose",
            "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose",
            "sudo service docker start",
            "sudo echo '${var.aws_nlb_endpoint}' >> ./fluentd/fluent.conf",
            "sudo echo '  port 53\n  flush_interval 5s\n</match>' >> ./fluentd/fluent.conf",
            "sudo docker-compose build",
            "sudo docker-compose up -d"
        ]
    } 
  
    tags = {
        Name        = "${var.environment_global_name}-fluentlistener${count.index}"
        Environment = var.environment_type
        Cluster     = var.cluster_global_name
        Class       = var.class_global_name
        Billing     = var.billing_global_name
        CreatedBy   = var.created_by
    }
}

# Add listener IP to security group
resource "aws_security_group_rule" "listener_access" {
    count = length(aws_instance.fluentd)
    type = "ingress"
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["${aws_instance.fluentd[count.index].public_ip}/32"]
    description = "Fluentd listener access"
    
    security_group_id = var.aws_security_group_id
}