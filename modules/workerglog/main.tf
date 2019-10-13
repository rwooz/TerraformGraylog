# Create instances for worker graylog service
resource "aws_instance" "workerglog" {
    ami                         = "${lookup(var.amis, var.aws_region)}"
    #Should have at least one instance per availability zone
    count                       = var.worker_instances_num
    instance_type               = var.worker_instance_type
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
  
    # Provision .pem file for connecting to master
    provisioner "file" {
        source      = "../../${var.aws_key_pair}.pem"
        destination = "~/${var.aws_key_pair}.pem"
    }
  
    # Install docker/-compose, then join swarm as manager
    provisioner "remote-exec" {
        inline = [
            "sudo yum update -y",
            "sudo amazon-linux-extras install -y docker",
            "sudo usermod -a -G docker ec2-user",
            "sudo curl -L https://github.com/docker/compose/releases/download/1.24.0/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose",
            "sudo chmod +x /usr/local/bin/docker-compose",
            "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose",
            "sudo service docker start",
            "sudo hostname worker${count.index}",
            "sudo chmod 500 ${var.aws_key_pair}.pem",
            "sudo scp -i '${var.aws_key_pair}.pem' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@${var.aws_instance_masterglog_public_dns}:~/scripts/swarmtoken1.sh swarmtoken1.sh",
            "sudo chmod 777 ./swarmtoken1.sh",
            "sudo truncate --size -1 swarmtoken1.sh",
            "sudo echo -n ' ${var.aws_instance_masterglog_private_ip}' >> swarmtoken1.sh",
            "sudo echo ':2377' >> swarmtoken1.sh",
            "sudo chmod +x ./swarmtoken1.sh",
            "sudo ./swarmtoken1.sh"
        ]
    } 
  
    tags = {
        Name        = "${var.environment_global_name}-worker${count.index}"
        Environment = var.environment_type
        Cluster     = var.cluster_global_name
        Class       = var.class_global_name
        Billing     = var.billing_global_name
        CreatedBy   = var.created_by
    }
}

# Attach worker instances to alb
resource "aws_lb_target_group_attachment" "glogw" {
    count            = length(aws_instance.workerglog)
    target_group_arn = var.aws_alb_arn
    target_id        = element(aws_instance.workerglog.*.id, count.index)
}

# Attach worker instances to nlb
resource "aws_lb_target_group_attachment" "glogwn" {
    count            = length(aws_instance.workerglog)
    target_group_arn = var.aws_nlb_arn
    target_id        = element(aws_instance.workerglog.*.id, count.index)
}