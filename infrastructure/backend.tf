
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.1"
    }
  }

  required_version = ">= 1.2.0"

  cloud {
    organization = "itsjoshb"

    workspaces {
      name = "alexandria"
    }
  }
}
