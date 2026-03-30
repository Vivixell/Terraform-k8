terraform {

  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 6.9"
    }
  }
}


# Connects to your local Docker daemon socket automatically
provider "docker" {}

# Pulls the Nginx image from Docker Hub
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false # Ensures the image is deleted when we run terraform destroy
}

# Runs the container and maps port 8080 to 80
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"

  ports {
    internal = 80
    external = 8080
  }
}
