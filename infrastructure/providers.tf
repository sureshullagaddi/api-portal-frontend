terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "api-portal-terraform-state"
    region         = "eu-north-1"
    dynamodb_table = "api-portal-terraform-locks"
    encrypt        = true
    # key injected: -backend-config="key=frontend/{env}/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "api-portal"
      Component   = "frontend"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repo        = "api-portal-frontend"
    }
  }
}

