variable "region" {
  description = "Região AWS"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  default     = "meu-cluster"
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "subnets" {
  description = "Lista de subnets"
  type        = list(string)
}
