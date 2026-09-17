output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.repo : k => v.repository_url }
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${aws_eks_cluster.eks.name} --region ${var.aws_region}"
}
