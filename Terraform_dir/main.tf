
# Let AZs be shuffled when more than 1 AZ is needed.
resource "random_shuffle" "az" {
  input = var.availability_zones
  result_count = length(var.availability_zones)
}


############# Network Creation ###############################

#create new vpc with 10.0.0.0/16  cidr block

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Demo VPC"
  }
}

# Private Subnet.
resource "aws_subnet" "private_subnet" {  
  count = 2
  cidr_block = var.subnet_cidr_blocks.ec2[count.index] 
  vpc_id = aws_vpc.main.id 
  availability_zone = random_shuffle.az.result[count.index % length( random_shuffle.az.result)]
   tags = {
    Name = "EC2-Subnet"
  }
  
}

# Public Subnet  w/ NAT Gateway.
resource "aws_subnet" "public_subnet" {  
  count = 2
  cidr_block = var.subnet_cidr_blocks.elb[count.index] 
  vpc_id = aws_vpc.main.id  
  availability_zone = random_shuffle.az.result[count.index % length( random_shuffle.az.result)]
  tags = {
    Name = "ELB-Subnet"
  }  
}

# NAT Gatway w/ EIP.
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = {
    Name = "nat-eip"
  } 
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet[0].id
  
}

# IGW w
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Internate-Gateway"
  } 
}

resource "aws_route_table" "igw_public_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public-route-table"
  } 
}

# Route table for NAT.
resource "aws_route_table" "nat_private_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private-route-table"
  } 
}



########### route creation ####################
resource "aws_route" "route_to_internet" {
  route_table_id = aws_route_table.igw_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route" "route_to_nat" {
  route_table_id = aws_route_table.nat_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}
######################################




# Add routing associations to subnet
resource "aws_route_table_association" "association_for_route_to_igw" { 
  count = 2
  route_table_id = aws_route_table.igw_public_route_table.id
  subnet_id = aws_subnet.public_subnet[count.index].id
}

resource "aws_route_table_association" "association_for_route_to_nat" {  
  count = 2
  route_table_id = aws_route_table.nat_private_route_table.id
  subnet_id = aws_subnet.private_subnet[count.index].id
}




################# creating security group ###########

resource "aws_security_group" "elb_sg" {
  name        = "elb-app-sg"
  description = "allow app"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "elb-app-sg"
  }
 }

############### ELB SG rules #############

resource "aws_security_group_rule" "r1" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb_sg.id
}

resource "aws_security_group_rule" "r2" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb_sg.id
}


resource "aws_security_group_rule" "r4" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb_sg.id
}

############### EC2 SG rules #############

resource "aws_security_group_rule" "r5" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  source_security_group_id = aws_security_group.elb_sg.id
  security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "r6" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  source_security_group_id = aws_security_group.elb_sg.id
  security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "r8" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  source_security_group_id = aws_security_group.elb_sg.id
  security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "r7" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "ec2 security group"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "ec2-sg"
  }
}

# Public Subnet NACL
resource "aws_network_acl" "elb_nacl" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "elb_nacl"
  }
}
############### Public ELB NACL rules #############

resource "aws_network_acl_rule" "elb_http_inbound" {
  network_acl_id = aws_network_acl.elb_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "elb_https_inbound" {
  network_acl_id = aws_network_acl.elb_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_ssh_inbound" {
  network_acl_id = aws_network_acl.elb_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0" #give your vpn cidr for better security
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "elb_all_outbound" {
  network_acl_id = aws_network_acl.elb_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}


# Private Subnet NACL
resource "aws_network_acl" "ec2_nacl" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "ec2_nacl"
  }
}

############### Private EC2 NACL rules #############

resource "aws_network_acl_rule" "ec2_http_inbound" {
  network_acl_id = aws_network_acl.ec2_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "ec2_https_inbound" {
  network_acl_id = aws_network_acl.ec2_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "ec2_ssh_inbound" {
  network_acl_id = aws_network_acl.ec2_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "private_all_outbound" {
  network_acl_id = aws_network_acl.ec2_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# Associate Public NACL with Public Subnets
resource "aws_network_acl_association" "public_nacl_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  network_acl_id = aws_network_acl.elb_nacl.id
}

# Associate Private NACL with Private Subnets
resource "aws_network_acl_association" "private_nacl_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private_subnet[count.index].id
  network_acl_id = aws_network_acl.ec2_nacl.id
}

# ALB Creation
resource "aws_lb" "main" {
  name               = "lb-3"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = aws_subnet.public_subnet[*].id

  tags = {
    Name = "elb-3"
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name        = "tg-3"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    protocol            = "HTTP"
    path                = "/"
    interval            = 30
  }
}

# Listener for HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Listener for HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:989233163663:certificate/6b16fb4a-6ddc-4514-b5aa-f3e39765b1c9" 

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ECR Repository
resource "aws_ecr_repository" "ecs_repo" {
  name                 = "ecs-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "My ECR Repository"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs-cluster-fg" {
  name               = "ecs-cluster-fg"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy Attachment for ECS Task Execution Role
resource "aws_iam_policy_attachment" "ecs_task_execution_policy_attachment" {
  name       = "ecs-task-execution-policy-attachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#################################################################################



