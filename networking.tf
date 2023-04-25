data "aws_availability_zones" "available" {}

resource "aws_vpc" "my-vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cloud_env}_${var.vpc_tag_name}"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "my_IGW" {
  vpc_id   = aws_vpc.my-vpc.id

  tags = {
    Name = "${var.cloud_env}_test_igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id     = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_IGW.id
  }

  tags = {
    Name = "${var.cloud_env}_public_test_rt"
  }
}

resource "aws_default_route_table" "private_rt" {
  default_route_table_id  = aws_vpc.my-vpc.default_route_table_id

  tags = {
    Name = "${var.cloud_env}_private_test_rt"
  }
}

resource "aws_subnet" "public_subnet" {
  count               = 2
  vpc_id              = aws_vpc.my-vpc.id
  cidr_block          = var.public_cidrs[count.index]
  map_public_ip_on_launch  = true
  availability_zone        = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.cloud_env}_public_test_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  count               = 2
  vpc_id              = aws_vpc.my-vpc.id
  cidr_block          = var.private_cidrs[count.index]
  map_public_ip_on_launch  = false
  availability_zone        = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.cloud_env}_private_test_subnet"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet.*.id[count.index]
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.private_subnet.*.id[count.index]
  route_table_id = aws_default_route_table.private_rt.id
}

resource "aws_security_group" "public_sg" {
  name        = "${var.cloud_env}_public_sg"
  description = "Security group for public instance"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description  = "SSH"
    from_port    = 22
    to_port      = 22
    protocol     = "tcp"
    cidr_blocks  = [var.access_ip]
  }

  ingress {
    description  = "HTTP"
    from_port    = 80
    to_port      = 80
    protocol     = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  egress {
    from_port    = 0
    to_port      = 0
    protocol     = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cloud_env}_public_sg"
  }
}
resource "aws_security_group" "rds_sg" {
  name        = "${var.cloud_env}_rds_sg"
  description = "Security group for db instance"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description       = "sql"
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_groups   = [ "${aws_security_group.public_sg.id}"]

  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]

  }
  tags = {
    Name = "${var.cloud_env}_rds_sg"
  }
}
