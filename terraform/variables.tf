# Região da AWS
variable "region" {
  description = "Região AWS"
  default     = "us-east-1"
}

# Nome do cluster EKS
variable "cluster_name" {
  description = "Nome do cluster EKS"
  default     = "meu-cluster"
}

# ID da VPC onde o cluster será criado
variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

# Lista de subnets para o cluster
variable "subnet_ids" {
  description = "Lista de subnets"
  type        = list(string)
}
