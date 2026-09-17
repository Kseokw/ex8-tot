variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

# 이미 생성된 상태 저장 버킷 (terraform import 로 가져옴)
variable "state_bucket_name" {
  type    = string
  default = "std07-ex-terraform-state-bucket"
}
