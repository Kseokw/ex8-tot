# =============================================================================================
# EKS 클러스터 IAM 역할
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${local.tag_header}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# =============================================================================================
# EKS 클러스터
resource "aws_eks_cluster" "eks" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    # 컨트롤 플레인 ENI 는 cluster 서브넷에 배치
    subnet_ids = [
      aws_subnet.cluster_1a_subnet.id,
      aws_subnet.cluster_1b_subnet.id,
      aws_subnet.cluster_1c_subnet.id,
    ]
    endpoint_private_access = true # 노드는 VPC 내부 경로로 API 접근
    endpoint_public_access  = true # GitHub Actions 러너에서 접근하기 위해 필요
  }

  # IAM 기반 접근 관리 (aws-auth ConfigMap 미사용)
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true # 생성 주체에게 관리자 권한
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name = local.cluster_name
  }
}

# 추가 관리자 등록 (선택)
resource "aws_eks_access_entry" "admin" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admin" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# =============================================================================================
# 워커 노드 IAM 역할
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "${local.tag_header}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # ECR 이미지 pull
  ])
  role       = aws_iam_role.eks_node_role.name
  policy_arn = each.value
}

# =============================================================================================
# 관리형 노드 그룹 (private 서브넷)
resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${local.tag_header}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.private_1a_subnet.id,
    aws_subnet.private_1b_subnet.id,
    aws_subnet.private_1c_subnet.id,
  ]

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = var.node_instance_types
  disk_size      = 20

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = 1
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  # 노드가 뜰 때 NAT 경로가 있어야 클러스터 조인/이미지 pull 가능
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_route_table_association.private_1a_rt_association,
    aws_route_table_association.private_1b_rt_association,
    aws_route_table_association.private_1c_rt_association,
  ]

  tags = {
    Name = "${local.tag_header}-node"
  }
}

# =============================================================================================
# EKS Pod Identity Agent
# 파드(서비스 어카운트)에 IAM 역할을 부여하는 기능
# 실습 때 eksctl 로 한 OIDC 공급자 연결 + iamserviceaccount 생성을 대체
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [aws_eks_node_group.node_group]
}
