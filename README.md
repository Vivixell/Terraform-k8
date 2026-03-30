# Deploying Multi-Cloud Infrastructure with Terraform Modules

## The Monolith Problem
Most engineers start writing Terraform by dropping a single AWS provider block at the top of their `main.tf` and dumping all their resources underneath it. That works for a weekend project. It completely falls apart in production.

When you need to deploy a globally distributed application, or provision underlying infrastructure *and* deploy application workloads on top of it simultaneously, you need to master advanced provider orchestration.

Today, I am sharing the blueprints for three advanced Terraform provider patterns: 
1. Passing Aliased Providers into Modules.
2. Local Container Orchestration (Docker).
3. Provider Chaining (AWS EKS + Kubernetes).

---

## Pattern 1: The Multi-Provider Module
The golden rule of writing reusable Terraform modules is this: **A module must never declare its own provider block.**

If a module hardcodes a region or an account, it becomes rigid. Instead, a module must demand that the calling configuration passes the providers down to it. We do this using `configuration_aliases`.

### The Module Definition (`modules/app/main.tf`)
Notice how the module explicitly requires two distinct AWS connections to function:
```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.primary, aws.replica] 
    }
  }
}

resource "aws_s3_bucket" "primary" {
  provider      = aws.primary
  bucket_prefix = "primary-data-"
}
```

### The Root Caller (`live/main.tf`)
In the root directory, we define the actual API connections and "wire" them into the module using the `providers` map:

```
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

module "global_app" {
  source = "../modules/app"
  
  providers = {
    aws.primary = aws.east
    aws.replica = aws.west
  }
}

```
## Pattern 2: Local Container Orchestration
Terraform is not just for cloud APIs. It can orchestrate anything with an accessible API—including your local Docker daemon. Before dealing with the complexity of cloud-managed Kubernetes, you can test container deployments locally using the `kreuzwerker/docker` provider.

```
provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false 
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"
  ports {
    internal = 80
    external = 8080
  }
}
```


Run `terraform apply`, and Terraform will pull the image and spin up the container on port 8080 locally. No `docker run` commands required.


---
## Pattern 3: Provider Chaining (AWS EKS + Kubernetes)
This is where Terraform flexes its true enterprise capability.

What if you want to provision an AWS EKS cluster, and then immediately deploy an Nginx pod into that cluster, all within a single `terraform apply`?

To do this, we use **Provider Chaining**. We use the AWS provider to build the cluster, extract the cluster's endpoint and certificate authority data on the fly, and pass that data directly into the configuration of the Kubernetes provider.

### The Dynamic Authentication Block
Instead of hardcoding static `kubeconfig` files, we use an `exec` block. This forces the Kubernetes provider to execute an AWS CLI command in the background to fetch a short-lived authentication token for the cluster we *just* built.

```
# 1. Provision the Cluster (AWS Provider)
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "production-cluster"
  # ... vpc and subnet configuration ...
}

# 2. Authenticate dynamically to the new cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# 3. Deploy the workload (Kubernetes Provider)
resource "kubernetes_deployment" "nginx" {
  depends_on = [module.eks] 
  
  metadata {
    name = "nginx-deployment"
  }
  spec {
    replicas = 2
    # ... container spec ...
  }
}
```
*Note:* The `depends_on = [module.eks]` is critical. It prevents the Kubernetes provider from trying to deploy pods before the AWS provider has finished standing up the control plane.

### Conclusion
When you decouple providers from modules and learn to chain them together, Terraform transitions from a simple provisioning tool into a complete, end-to-end platform orchestrator.

#Terraform #DevOps #AWS #EKS #Kubernetes #CloudEngineering

