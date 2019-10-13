# Specify the provider and access details
provider "aws" {
    region  = var.aws_region
    version = "~> 2.22"
}

# Create backend with state and lockfile
terraform{
    backend "s3" {
        bucket         = "default-operations"
        key            = "terraform/qa-glog01/qa-glog01.tfstate"
        region         = "us-east-2"
        dynamodb_table = "terraform_locks"
        encrypt        = true
    }
}

# Create a VPC to launch our instances into
resource "aws_vpc" "glog-VPC" {
    cidr_block           = var.vpc_cidr_block
    instance_tenancy     = "default"
    enable_dns_hostnames = true
  
    tags = {
        Name        = "${var.environment_global_name}-VPC"
        Environment = var.environment_type
        Cluster     = var.cluster_global_name
        Class       = var.class_global_name
        Billing     = var.billing_global_name
        CreatedBy   = var.created_by
    }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
    vpc_id = aws_vpc.glog-VPC.id
    
    tags = {
        Name        = "${var.environment_global_name}-IG"
        Environment = var.environment_type
        Cluster     = var.cluster_global_name
        Class       = var.class_global_name
        Billing     = var.billing_global_name
        CreatedBy   = var.created_by
    }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access"{
    route_table_id         = aws_vpc.glog-VPC.main_route_table_id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.default.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
    vpc_id                  = aws_vpc.glog-VPC.id
    count                   = 3
    cidr_block              = "10.0.${element(var.pod_subnet, count.index)}"
    availability_zone       = element(var.azs, count.index)
    map_public_ip_on_launch = true

    tags = {
        Name        = "${var.environment_global_name}-subnet-0${count.index + 1}"
        Environment = var.environment_type
        Cluster     = var.cluster_global_name
        Class       = var.class_global_name
        Billing     = var.billing_global_name
        CreatedBy   = var.created_by
    }
}

# Grant access between AWS services and office IPs
resource "aws_security_group" "glog" {
    name   = "${var.environment_global_name}_sg"
    vpc_id = aws_vpc.glog-VPC.id

    # Internal access between all nodes
    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = [var.vpc_cidr_block]
        description = "VPC Internal Acccess"
    }

    # outbound internet access
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "outbound access"
    }
  
    tags = {
        Name = "${var.environment_global_name}-sg"
        Description = "Security group for ${var.environment_global_name} [Graylog Cluster]"
    }
}

# Create elasticsearch domain
resource "aws_elasticsearch_domain" "es-glog" {
    domain_name           = var.es_domain_name
    elasticsearch_version = "6.7"
  
    cluster_config {
        instance_type             = var.es_instance_type
        instance_count            = var.es_instances_num
        dedicated_master_enabled  = "true"
        dedicated_master_type     = var.es_master_type
        dedicated_master_count    = var.es_master_instances_num
        zone_awareness_enabled    = true
        zone_awareness_config {
            availability_zone_count = 3
        }
    }
  
    vpc_options {
        subnet_ids = [
            aws_subnet.default[0].id,
            aws_subnet.default[1].id,
            aws_subnet.default[2].id
        ]
    
        security_group_ids = [aws_security_group.glog.id]
    }
  
    advanced_options = {
        "rest.action.multi.allow_explicit_index" = "true"
    }
  
    ebs_options {
        ebs_enabled = true
        volume_size = var.es_vol_size
    }
    
    # Enable for use with HTTPS
    #node_to_node_encryption {
    #   enabled = true
    #}
  
    encrypt_at_rest {
        enabled = true
    }
  
    access_policies = <<CONFIG
    {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "es:*",
            "Resource": "arn:aws:es:us-east-2:862683271180:domain/${var.es_domain_name}/*"
        }]
    }
    CONFIG
}

# Create instance for master graylog service
resource "aws_instance" "masterglog" {
    ami                         = "${lookup(var.amis, var.aws_region)}"
    instance_type               = var.master_instance_type
    key_name                    = var.aws_key_pair
    subnet_id                   = aws_subnet.default[0].id
    vpc_security_group_ids      = [aws_security_group.glog.id]
    associate_public_ip_address = "true"
    ebs_optimized               = "true"

    connection {
        host        = self.public_ip
        type        = "ssh"
        user        = "ec2-user"
        private_key = "${file("../../${var.aws_key_pair}.pem")}"
    }
  
    # Provision docker-compose files to run on instance
    provisioner "file" {
        source      = "../../modules/dockerglog/"
        destination = "~/"
    }
  
    # Install docker/-compose and initialize swarm and swarm join tokens ([null] for worker, 1 for manager)
    provisioner "remote-exec" {
        inline = [
            "sudo yum update -y",
            "sudo amazon-linux-extras install -y docker",
            "sudo usermod -a -G docker ec2-user",
            "sudo curl -L https://github.com/docker/compose/releases/download/1.24.0/docker-compose-Linux-x86_64 -o /usr/local/bin/docker-compose",
            "sudo chmod +x /usr/local/bin/docker-compose",
            "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose",
            "sudo service docker start",
            "sudo docker swarm init",
            "sudo hostname master",
            "sudo echo -n '${self.public_ip}' >> ./configs/e.env",
            "sudo echo ':9000/' >> ./configs/e.env",
            "sudo echo -n 'GRAYLOG_REST_TRANSPORT_URI=http://' >> ./configs/e.env",
            "sudo echo -n '${self.public_ip}' >> ./configs/e.env",
            "sudo echo ':9000/api' >> ./configs/e.env",
            "sudo echo -n 'GRAYLOG_REST_LISTEN_URI=http://' >> ./configs/e.env",
            "sudo echo '${self.private_ip}:9000/api' >> ./configs/e.env",
            "sudo echo -n 'GRAYLOG_WEB_LISTEN_URI=https://' >> ./configs/e.env",
            "sudo echo -n '${self.private_ip}' >> ./configs/e.env",
            "sudo echo ':9000/' >> ./configs/e.env",
            "sudo echo -n 'GRAYLOG_ELASTICSEARCH_HOSTS=https://' >> ./configs/e.env",
            "sudo echo '${aws_elasticsearch_domain.es-glog.endpoint}:443, https://${aws_elasticsearch_domain.es-glog.endpoint}:80' >> ./configs/e.env",
            "sudo echo '${aws_elasticsearch_domain.es-glog.endpoint}:443, https://${aws_elasticsearch_domain.es-glog.endpoint}:80' >> ./configs/w.env",
            "sudo echo -n 'GRAYLOG_REST_LISTEN_URI=http://' >> ./configs/w.env",
            "sudo echo '${self.private_ip}:9000/api' >> ./configs/w.env",
            "sudo echo -n 'GRAYLOG_REST_TRANSPORT_URI=http://' >> ./configs/w.env",
            "sudo echo -n '${self.public_ip}' >> ./configs/w.env",
            "sudo echo ':9000/api' >> ./configs/w.env",
            "sudo echo 'GRAYLOG_HTTP_BIND_ADDRESS=0.0.0.0:9000' >> ./configs/w.env",
            "sudo docker swarm join-token -q worker >> ./scripts/swarmtoken.sh",
            "sudo docker swarm join-token -q manager >> ./scripts/swarmtoken1.sh"
        ]
    }
  
    tags = {
        Name        = "${var.environment_global_name}-master"
        Environment = var.environment_type
        Cluster     = var.cluster_global_name
        Class       = var.class_global_name
        Billing     = var.billing_global_name
        CreatedBy   = var.created_by
    }
}

# Create alb for aws instances
resource "aws_lb" "glogalb" {
    name               = "${var.environment_global_name}-alb"
    internal           = false
    load_balancer_type = "application"
    subnets            = [aws_subnet.default[0].id, aws_subnet.default[1].id, aws_subnet.default[2].id]
    security_groups    = [aws_security_group.glog.id]
}

# Create target group for alb to forward to
resource "aws_lb_target_group" "glog-alb-group" {
    name        = "${var.environment_global_name}-alb-group"
    port        = 9000
    protocol    = "HTTP"
    vpc_id      = aws_vpc.glog-VPC.id
    target_type = "instance"
  
    health_check{
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 10
        protocol            = "HTTP"
        path                = "/api/system/lbstatus"
    }
}

# Create listener for alb to pick up
resource "aws_lb_listener" "glog-alb-listener" {
    load_balancer_arn = aws_lb.glogalb.arn
    port              = "80"
    protocol          = "HTTP"
  
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.glog-alb-group.arn
    }
}

# Attach master instance to alb
resource "aws_lb_target_group_attachment" "glogm" {
    target_group_arn = aws_lb_target_group.glog-alb-group.arn
    target_id        = aws_instance.masterglog.id
}

# Create nlb for aws instances
resource "aws_lb" "glognlb" {
    name               = "${var.environment_global_name}-nlb"
    internal           = true
    load_balancer_type = "network"
    subnets            = [aws_subnet.default[0].id, aws_subnet.default[1].id, aws_subnet.default[2].id]
}

# Create target group for nlb to forward to
resource "aws_lb_target_group" "glog-nlb-group" {
    name        = "${var.environment_global_name}-nlb-group"
    port        = 12201
    protocol    = "UDP"
    vpc_id      = aws_vpc.glog-VPC.id
    target_type = "instance"
  
    health_check{
        healthy_threshold   = 2
        unhealthy_threshold = 2
        port                = 9000
        interval            = 10
        protocol            = "HTTP"
        path                = "/api/system/lbstatus"
    }
}

# Create listener for nlb to pick up
resource "aws_lb_listener" "glog-nlb-listener" {
    load_balancer_arn = aws_lb.glognlb.arn
    port              = "53"
    protocol          = "UDP"
  
    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.glog-nlb-group.arn
    }
}

# Attach master instance to nlb
resource "aws_lb_target_group_attachment" "glogmn" {
    target_group_arn = aws_lb_target_group.glog-nlb-group.arn
    target_id        = aws_instance.masterglog.id
}

# Spin up graylog and mongo cluster on docker swarm
resource "null_resource" "glogstart" {
    connection {
        host        = aws_instance.masterglog.public_ip
        type        = "ssh"
        user        = "ec2-user"
        private_key = "${file("../../${var.aws_key_pair}.pem")}"
    } 
  
    # Not sure why the process needs to run twice (up,down,up) in order to initialize the elasticsearch index. This seems to work for now.
    provisioner "remote-exec" {
        inline = [
            "sudo chmod 777 ./scripts/mongors.sh",
            "sudo chmod +x ./scripts/mongors.sh",
            "sudo docker stack deploy -c docker-compose.yml ${var.environment_global_name}",
            "sleep 30",
            "sudo ./scripts/mongors.sh",
            "sleep 90",
            "sudo docker stack rm ${var.environment_global_name}",
            "sleep 30",
            "sudo docker stack deploy -c docker-compose.yml ${var.environment_global_name}",
            "sleep 30",
            "sudo ./scripts/mongors.sh"
        ]
    }
  
    depends_on = [
        module.workerglog
    ]
}

module "workerglog" {
    source                             = "../../modules/workerglog"
    aws_key_pair                       = var.aws_key_pair
    aws_security_group_id              = aws_security_group.glog.id
    aws_subnet_ids                     = aws_subnet.default.*.id
    aws_instance_masterglog_public_dns = aws_instance.masterglog.public_dns
    aws_instance_masterglog_private_ip = aws_instance.masterglog.private_ip
    aws_alb_arn                        = aws_lb_target_group.glog-alb-group.arn
    aws_nlb_arn                        = aws_lb_target_group.glog-nlb-group.arn
    environment_global_name            = var.environment_global_name
    cluster_global_name                = var.cluster_global_name
    es_domain_name                     = var.es_domain_name
    worker_instance_type               = "t3a.large"
    worker_instances_num               = 3
}

module "fluentlistener" {
    source                             = "../../modules/fluentlistener"
    aws_key_pair                       = var.aws_key_pair
    aws_security_group_id              = aws_security_group.glog.id
    aws_subnet_ids                     = aws_subnet.default.*.id
    aws_nlb_endpoint                   = aws_lb.glognlb.dns_name
    environment_global_name            = var.environment_global_name
    cluster_global_name                = var.cluster_global_name
    listener_instance_type             = "t3a.small"
    listener_instances_num             = 3
}