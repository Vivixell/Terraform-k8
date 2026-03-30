terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. THE NETWORK LAYER (VPC)
# ==========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "ovr-eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # Keeps costs down for this build
  enable_dns_hostnames = true
}

# ==========================================
# 2. THE COMPUTE LAYER (EKS CLUSTER)
# ==========================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "ovr-production-cluster"
  cluster_version = "1.29"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.small"]
    }
  }
}

# ==========================================
# 3. KUBERNETES PROVIDER AUTHENTICATION
# ==========================================
# This dynamically authenticates to the cluster we JUST built
# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
#   }
# }


provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # Added the explicit --region argument below
    args        = ["eks", "get-token", "--region", "us-east-1", "--cluster-name", module.eks.cluster_name]
  }
}

# ==========================================
# 4. THE APPLICATION WORKLOAD
# ==========================================
resource "kubernetes_deployment" "nginx" {
  # Forces Terraform to wait until the EKS cluster is fully ready
  depends_on = [module.eks] 

  metadata {
    name = "nginx-deployment"
    labels = { app = "nginx" }
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "nginx" } }
    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          port { container_port = 80 }
        }
      }
    }
  }
}