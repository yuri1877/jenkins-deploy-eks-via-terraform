#
# Provider Configuration
#
terraform {
  required_version = "~>1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    # Not required: currently used in conjuction with using
    # icanhazip.com to determine local workstation external IP
    # to open EC2 Security Group access to the Kubernetes cluster.
    # See workstation-external-ip.tf for additional information.
    http = {
      source  = "hashicorp/http"
      version = "~> 2.1.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  # profile = var.aws_profile   # uncomment if you want to run locally

  default_tags {
    tags = local.all_tags
  }
}