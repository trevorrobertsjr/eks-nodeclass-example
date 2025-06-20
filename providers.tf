terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Kubernetes provider configuration using remote state data
provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      local.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Optional: Helm provider if you plan to deploy Helm charts
# provider "helm" {
#   kubernetes {
#     host                   = local.cluster_endpoint
#     cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
#     
#     exec {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "aws"
#       args = [
#         "eks",
#         "get-token",
#         "--cluster-name",
#         local.cluster_name,
#         "--region",
#         var.aws_region
#       ]
#     }
#   }
# }