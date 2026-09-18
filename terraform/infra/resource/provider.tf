terraform {
  # S3 네이티브 잠금(use_lockfile)은 Terraform 1.10 이상 필요
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # 6.0 이상 7.0 미만 중 최신 버전
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0" # 3.x 부터 kubernetes 설정이 블록이 아닌 속성(=) 문법
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4" # LB Controller IAM 정책 JSON 다운로드용
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38" # DB 접속 정보를 k8s Secret 으로 전달
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6" # DB 비밀번호 생성
    }
  }

  backend "s3" {
    bucket       = "std07-ex-terraform-state-bucket"            # S3 버킷 이름
    key          = "TerraformState/Lab/total/terraform.tfstate" # 버킷 내 저장할 위치
    region       = "ap-southeast-1"                             # S3 버킷 리전
    use_lockfile = true                                         # S3 네이티브 상태 잠금 (DynamoDB 불필요)
    encrypt      = true                                         # 파일 암호화 여부
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Class = "bipa17"
      Owner = "std07"
    }
  }
}

# EKS 에 ArgoCD 를 설치하기 위한 Helm 프로바이더
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks.name, "--region", var.aws_region]
    }
  }
}

# k8s Secret(DB 접속 정보) 생성용
provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks.name, "--region", var.aws_region]
  }
}
