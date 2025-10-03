module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.8.4" # versão estável do módulo EKS
  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  # VPC e subnets onde o cluster será provisionado
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids

  # Configuração de node group gerenciado pelo EKS
  eks_managed_node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      # Tipo de instância EC2 usada nos nós
      instance_types = ["t3.medium"]
    }
  }
}
