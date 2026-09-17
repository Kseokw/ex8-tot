# 컨테이너 이미지 저장소
resource "aws_ecr_repository" "repo" {
  for_each = toset(["company-backend", "company-frontend"])

  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true # 실습용: destroy 시 이미지가 있어도 삭제

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.tag_header}-${each.key}"
  }
}

# 최근 이미지 10개만 유지
resource "aws_ecr_lifecycle_policy" "repo" {
  for_each   = aws_ecr_repository.repo
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
