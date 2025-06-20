data "terraform_remote_state" "eks_infrastructure" {
  backend = "remote"
  
  config = {
    organization = "my-org"
    workspaces = {
      name = "eks-cluster-workspace"
    }
  }
}

# Local values for easier reference
locals {
  # EKS Cluster Information
  cluster_name                        = data.terraform_remote_state.eks_infrastructure.outputs.cluster_name
  cluster_endpoint                    = data.terraform_remote_state.eks_infrastructure.outputs.cluster_endpoint
  cluster_certificate_authority_data  = data.terraform_remote_state.eks_infrastructure.outputs.cluster_certificate_authority_data
  cluster_security_group_id           = data.terraform_remote_state.eks_infrastructure.outputs.cluster_security_group_id
  node_security_group_id              = data.terraform_remote_state.eks_infrastructure.outputs.node_security_group_id
  pod_security_group_id               = data.terraform_remote_state.eks_infrastructure.outputs.pod_security_group_id
  oidc_provider_arn                   = data.terraform_remote_state.eks_infrastructure.outputs.oidc_provider_arn
  
  # Network Information
  vpc_id                = data.terraform_remote_state.eks_infrastructure.outputs.vpc_id
  vpc_cidr_block        = data.terraform_remote_state.eks_infrastructure.outputs.vpc_cidr_block
  availability_zones    = data.terraform_remote_state.eks_infrastructure.outputs.availability_zones
  
  # Subnet Information
  public_subnet_ids     = data.terraform_remote_state.eks_infrastructure.outputs.public_subnet_ids
  private_subnet_ids    = data.terraform_remote_state.eks_infrastructure.outputs.private_subnet_ids
  database_subnet_ids   = data.terraform_remote_state.eks_infrastructure.outputs.database_subnet_ids
  pod_subnet_ids        = data.terraform_remote_state.eks_infrastructure.outputs.pod_subnet_ids
  subnets_by_az         = data.terraform_remote_state.eks_infrastructure.outputs.subnets_by_az
  
  # Provider Configurations
  kubernetes_config = data.terraform_remote_state.eks_infrastructure.outputs.kubernetes_config
  helm_config       = data.terraform_remote_state.eks_infrastructure.outputs.helm_config
  
  # Tags and Metadata
  common_tags    = data.terraform_remote_state.eks_infrastructure.outputs.common_tags
  environment    = data.terraform_remote_state.eks_infrastructure.outputs.environment
  project_name   = data.terraform_remote_state.eks_infrastructure.outputs.project_name
  aws_region     = data.terraform_remote_state.eks_infrastructure.outputs.aws_region
}