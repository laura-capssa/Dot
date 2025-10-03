# Nome do cluster EKS
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_id
}

# Endpoint do cluster EKS
output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
}

# Security Group associado ao cluster EKS
output "cluster_security_group" {
  description = "Security Group associado ao cluster"
  value       = module.eks.cluster_security_group_id
}
