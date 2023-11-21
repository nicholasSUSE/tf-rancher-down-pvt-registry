terraform {
  required_providers {
    # Rancher
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.0.0"
    }
    # Helm resources
    helm = {
      source  = "hashicorp/helm"
      version = "2.10.1"
    }
    # manage resources in AWS
    aws = {
      source  = "hashicorp/aws"
      version = "5.1.0"
    }
    # manage local filesystem resources (CRUD) files on the local machine that terraform is run
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    # Generate and manage TLS certificates and keys
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
    # Execute commands through SSH on EC2 instances
    ssh = {
      source  = "loafoe/ssh"
      version = "2.6.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token      = var.aws_session_token
  region     = var.aws_region
}

provider "helm" {
  kubernetes {
    config_path = local_file.kube_config_server_yaml.filename
  }
}

# Rancher2 bootstrapping provider - RANCHER SERVER
provider "rancher2" {
  alias = "MASTER"

  api_url  = "https://${join(".", ["rancher", aws_instance.rancher_server.public_ip, "sslip.io"])}"
  insecure = true
  bootstrap = true
}

# Rancher2 administration provider - WORKLOAD NODE
provider "rancher2" {
  alias = "WORKLOAD"

  api_url  = "https://${join(".", ["rancher", aws_instance.rancher_server.public_ip, "sslip.io"])}"
  insecure = true
  # ca_certs  = data.kubernetes_secret.rancher_cert.data["ca.crt"]
  token_key = rancher2_bootstrap.admin.token
  # timeout   = "300s"
}
