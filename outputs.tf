output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.eks.id
}

output "k8s_cluster" {
  value = aws_eks_cluster.eks
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.cluster-name
}
