locals {
  all_tags = {
    ManagedBy   = "Terraform"
    Environment = "sandbox"
    Project     = "eks-dev-demo"
  }
}

// in case you need a random cluster name for development purposes
locals {
  cluster_name = "dev-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}
