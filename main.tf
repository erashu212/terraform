terraform {
  required_version = ">= 0.12.23"
  required_providers {
    aws      = ">= 3.30.0"
    external = ">= 1.2"
    random   = "~> 3.0.0"
    null     = "~> 3.0.0"
    archive  = "~> 2.0.0"
  }
  backend "remote" {
    hostname = "app.terraform.io"
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "useast1"
}

provider "aws" {
  region = var.region
}

data "aws_region" "active" {}

data "aws_caller_identity" "active" {}

provider "aws" {
  alias  = "failover_region"
  region = local.failover_region
}
