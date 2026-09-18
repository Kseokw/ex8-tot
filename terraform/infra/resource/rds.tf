# =============================================================================================
# RDS (MySQL) - 교육생 성적 데이터 저장
# - private 서브넷에 배치, 외부 접속 불가
# - 비밀번호는 Terraform 이 생성해 k8s Secret 으로 전달
# =============================================================================================

# DB 서브넷 그룹 (private 서브넷 3개)
resource "aws_db_subnet_group" "mysql" {
  name = "${local.tag_header}-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_1a_subnet.id,
    aws_subnet.private_1b_subnet.id,
    aws_subnet.private_1c_subnet.id,
  ]

  tags = {
    Name = "${local.tag_header}-db-subnet-group"
  }
}

# DB 비밀번호 생성 (RDS 가 허용하지 않는 문자 제외)
resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "mysql" {
  identifier     = "${local.tag_header}-mysql"
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.std07_lab_mysql_sg.id]
  publicly_accessible    = false
  multi_az               = false # 실습용 단일 AZ

  backup_retention_period = 1
  skip_final_snapshot     = true  # 실습용: 삭제 시 스냅샷 남기지 않음
  deletion_protection     = false # 실습용: 삭제 보호 해제
  apply_immediately       = true

  tags = {
    Name = "${local.tag_header}-mysql"
  }
}

# =============================================================================================
# 앱 네임스페이스와 DB 접속 정보 Secret
# (네임스페이스를 Terraform 이 만들므로 k8s/namespace.yaml 은 사용하지 않음)
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }

  depends_on = [aws_eks_node_group.node_group]
}

resource "kubernetes_secret" "db" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  # 파드는 envFrom 으로 이 값들을 환경변수로 받는다
  data = {
    DB_HOST     = aws_db_instance.mysql.address
    DB_PORT     = tostring(aws_db_instance.mysql.port)
    DB_NAME     = var.db_name
    DB_USER     = var.db_username
    DB_PASSWORD = random_password.db.result
  }

  type = "Opaque"
}
