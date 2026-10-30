# One VPC per environment, with public subnets only. No NAT gateway: NAT costs
# ~$32/month per env even when idle, and nothing in this course needs it.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Public subnets across N AZs. /24 each, carved out of the VPC CIDR by index
# so the layout is the same in every env: 10.x.1.0/24, 10.x.2.0/24, ...
resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  # subnet_tags lets other stacks add their own discovery tags. Chapter 10's
  # EKS stack passes kubernetes.io/cluster/<name> and kubernetes.io/role/elb.
  tags = merge(
    { Name = "${var.name_prefix}-public-${count.index + 1}" },
    var.subnet_tags,
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
