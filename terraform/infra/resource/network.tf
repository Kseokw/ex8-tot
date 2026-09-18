# VPC 생성
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "${local.tag_header}-vpc"
  }
}

# ========================================================================================
# 퍼블릭 서브넷 생성
# kubernetes.io/role/elb = 1 : EKS 가 인터넷용 LoadBalancer 를 만들 서브넷
resource "aws_subnet" "public_1a_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  map_public_ip_on_launch                     = true # 퍼블릭 IPv4 주소 자동 할당
  enable_resource_name_dns_a_record_on_launch = true # 리소스 이름 DNS A 레코드

  tags = {
    Name                     = "${local.tag_header}-public-1a-subnet"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "public_1b_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"

  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true

  tags = {
    Name                     = "${local.tag_header}-public-1b-subnet"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "public_1c_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1c"

  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true

  tags = {
    Name                     = "${local.tag_header}-public-1c-subnet"
    "kubernetes.io/role/elb" = "1"
  }
}

# private 서브넷 생성 (EKS 워커 노드 배치)
# kubernetes.io/role/internal-elb = 1 : 내부용 LoadBalancer 서브넷
resource "aws_subnet" "private_1a_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name                              = "${local.tag_header}-private-1a-subnet"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_subnet" "private_1b_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name                              = "${local.tag_header}-private-1b-subnet"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_subnet" "private_1c_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.13.0/24"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name                              = "${local.tag_header}-private-1c-subnet"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# cluster 서브넷 생성 (EKS 컨트롤 플레인 ENI 배치)
resource "aws_subnet" "cluster_1a_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "${local.tag_header}-cluster-1a-subnet"
  }
}
resource "aws_subnet" "cluster_1b_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "${local.tag_header}-cluster-1b-subnet"
  }
}
resource "aws_subnet" "cluster_1c_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.23.0/24"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name = "${local.tag_header}-cluster-1c-subnet"
  }
}

# ===============================================================================================
# Internet Gateway 생성
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.tag_header}-igw"
  }
}

# NAT Gateway 생성을 위한 EIP 생성
resource "aws_eip" "nat_eip" {
  domain = "vpc" # VPC용 EIP

  tags = {
    Name = "${local.tag_header}-nat-eip"
  }
}

# NAT Gateway 생성 (실습 비용 절감을 위해 1a 에 1개만 생성)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1a_subnet.id
  depends_on    = [aws_internet_gateway.igw] # IGW 생성 후 NAT 생성

  tags = {
    Name = "${local.tag_header}-nat-gw"
  }
}

# ========================================================================================
# 라우팅 테이블 생성
# public
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id # IGW 는 gateway_id
  }
  tags = {
    Name = "${local.tag_header}-public-rt"
  }
}

# private (NAT 는 gateway_id 가 아니라 nat_gateway_id 사용)
resource "aws_route_table" "private_1a_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "${local.tag_header}-private-1a-rt"
  }
}
resource "aws_route_table" "private_1b_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "${local.tag_header}-private-1b-rt"
  }
}
resource "aws_route_table" "private_1c_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "${local.tag_header}-private-1c-rt"
  }
}

# cluster
resource "aws_route_table" "cluster_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "${local.tag_header}-cluster-rt"
  }
}

# ========================================================================================
# 서브넷 연결
# Public
resource "aws_route_table_association" "public_1a_rt_association" {
  subnet_id      = aws_subnet.public_1a_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_1b_rt_association" {
  subnet_id      = aws_subnet.public_1b_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_1c_rt_association" {
  subnet_id      = aws_subnet.public_1c_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# private
resource "aws_route_table_association" "private_1a_rt_association" {
  subnet_id      = aws_subnet.private_1a_subnet.id
  route_table_id = aws_route_table.private_1a_rt.id
}
resource "aws_route_table_association" "private_1b_rt_association" {
  subnet_id      = aws_subnet.private_1b_subnet.id
  route_table_id = aws_route_table.private_1b_rt.id
}
resource "aws_route_table_association" "private_1c_rt_association" {
  subnet_id      = aws_subnet.private_1c_subnet.id
  route_table_id = aws_route_table.private_1c_rt.id
}

# cluster
resource "aws_route_table_association" "cluster_1a_rt_association" {
  subnet_id      = aws_subnet.cluster_1a_subnet.id
  route_table_id = aws_route_table.cluster_rt.id
}
resource "aws_route_table_association" "cluster_1b_rt_association" {
  subnet_id      = aws_subnet.cluster_1b_subnet.id
  route_table_id = aws_route_table.cluster_rt.id
}
resource "aws_route_table_association" "cluster_1c_rt_association" {
  subnet_id      = aws_subnet.cluster_1c_subnet.id
  route_table_id = aws_route_table.cluster_rt.id
}

# =============================================================================================
# 보안그룹 설정 (MySQL - EKS 워커 노드에서만 접근)
resource "aws_security_group" "std07_lab_mysql_sg" {
  name        = "${local.tag_header}-mysql-sg"
  description = "Allow MySQL inbound traffic from EKS nodes"
  vpc_id      = aws_vpc.vpc.id

  # VPC 대역 전체가 아니라 EKS 노드가 쓰는 보안그룹에서 오는 3306 만 허용
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_header}-mysql-sg"
  }
}
