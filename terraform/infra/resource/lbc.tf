# =============================================================================================
# AWS Load Balancer Controller
# Ingress → ALB, Service(LoadBalancer) → NLB 를 생성하는 컨트롤러
# =============================================================================================

# 1) IAM 정책 (실습의 curl + aws iam create-policy 대체)
data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${var.lbc_policy_ref}/docs/install/iam_policy.json"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "LB Controller IAM 정책 JSON 을 받아오지 못했습니다."
    }
  }
}

resource "aws_iam_policy" "lbc" {
  name   = "${local.tag_header}-AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.lbc_iam_policy.response_body

  tags = {
    Name = "${local.tag_header}-AWSLoadBalancerControllerIAMPolicy"
  }
}

# 2) 컨트롤러 파드가 사용할 IAM 역할 (Pod Identity 신뢰 정책)
data "aws_iam_policy_document" "lbc_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "${local.tag_header}-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# 3) kube-system/aws-load-balancer-controller 서비스 어카운트 ↔ IAM 역할 연결
#    (실습의 eksctl create iamserviceaccount 대체, SA 어노테이션 불필요)
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}

# 4) Helm 설치 (CRD 도 차트에 포함되어 함께 설치됨)
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version
  namespace  = "kube-system"
  timeout    = 600

  values = [yamlencode({
    clusterName = aws_eks_cluster.eks.name
    region      = var.aws_region
    vpcId       = aws_vpc.vpc.id
    serviceAccount = {
      create = true # 차트가 SA 생성 (IAM 연결은 Pod Identity 가 담당)
      name   = "aws-load-balancer-controller"
    }
  })]

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_eks_pod_identity_association.lbc,
    aws_iam_role_policy_attachment.lbc,
  ]
}
