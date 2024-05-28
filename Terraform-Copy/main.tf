
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
  cidr_block = var.subnet_cidr_blocks.db[count.index] 
  vpc_id = aws_vpc.main.id 
  availability_zone = random_shuffle.az.result[count.index % length( random_shuffle.az.result)]
   tags = {
    Name = "EC2-Subnet"
  }
  
}

# Public Subnet  w/ NAT Gateway.
resource "aws_subnet" "public_subnet" {  
  count = 2
  cidr_block = var.subnet_cidr_blocks.app[count.index] 
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
  subnet_id = aws_subnet.app_subnet[0].id
  
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

resource "aws_security_group_rule" "r5" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  source_security_group_id = aws_security_group.elb_sg.id
  security_group_id = aws_security_group.elb_sg.id
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "ec2 security group"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "ec2-sg"
  }
}

resource "aws_security_group_rule" "ec2_r1" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  source_security_group_id = aws_security_group.elb_sg.id
  security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "ec2_r2" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_sg.id
}
#################################################################################



