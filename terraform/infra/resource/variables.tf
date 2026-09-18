variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

# EKS 버전 (EKS 콘솔에서 표준 지원 중인 버전인지 확인 후 사용)
variable "cluster_version" {
  type    = string
  default = "1.34"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

# 클러스터 관리자 권한을 추가로 줄 IAM ARN (예: 로컬에서 kubectl 쓸 IAM 사용자)
# ※ 클러스터를 생성한 주체(GitHub Actions 역할)는 자동으로 관리자이므로 넣지 말 것
variable "admin_principal_arns" {
  type    = list(string)
  default = []
}

# ArgoCD 가 바라볼 Git 저장소 (파이프라인에서 자동 주입)
variable "git_repo_url" {
  type = string
}

variable "git_revision" {
  type    = string
  default = "main"
}

# Helm 차트 버전 (null = 최신, 운영에서는 고정 권장)
variable "argocd_chart_version" {
  type    = string
  default = null
}

variable "argocd_apps_chart_version" {
  type    = string
  default = null
}

# AWS Load Balancer Controller
# IAM 정책 JSON 을 가져올 Git ref (main 또는 v2.x.x 태그)
variable "lbc_policy_ref" {
  type    = string
  default = "main"
}

variable "lbc_chart_version" {
  type    = string
  default = null # null = 최신
}

# ArgoCD admin 비밀번호의 bcrypt 해시
# GitHub Secret ARGOCD_ADMIN_PASSWORD_HASH → TF_VAR_argocd_admin_password_hash 로 주입
# 비어 있으면 ArgoCD 가 임의 비밀번호를 생성 (argocd-initial-admin-secret)
variable "argocd_admin_password_hash" {
  type      = string
  default   = ""
  sensitive = true
}

# ------------------------------- RDS -------------------------------
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro" # 프리 티어 대상 인스턴스
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_engine_version" {
  type    = string
  default = "8.0"
}

variable "db_name" {
  type    = string
  default = "grades"
}

variable "db_username" {
  type    = string
  default = "dbadmin" # admin, root 등 예약어는 사용 불가
}

variable "app_namespace" {
  type    = string
  default = "company"
}
