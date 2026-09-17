# 상태 저장용 S3 버킷 관리 영역
# - backend 블록 없음 → 로컬 상태 사용 (버킷을 관리하는 코드가 그 버킷에 상태를 둘 수 없음)
# - 자동배포 대상에서 제외 (로컬에서 수동 실행)
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # 6.0 이상 7.0 미만
    }
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
