# =============================================================================
# Component: EKS - Cash Management
# =============================================================================
# Crea el cluster EKS con Fargate y sus recursos asociados:
# - EKS Cluster
# - OIDC Provider (para IRSA)
# - Fargate Profiles (kube-system + uno por banco)
# - CloudWatch Log Group
# - CoreDNS restart (requerido para Fargate)
# - Access Entries (acceso IAM al cluster)
#
# Inputs requeridos de otros componentes:
#   - vpc:  vpc_id, private_subnet_ids
#   - iam:  eks_cluster_role_arn, fargate_pod_execution_role_arn
#
# Outputs necesarios para los siguientes componentes:
#   - lb-controller:    cluster_name, cluster_endpoint, cluster_ca_data, oidc_provider_arn, oidc_provider_url
#   - fargate-logging:  cluster_name, cluster_endpoint, cluster_ca_data
#   - alb-initializer:  cluster_name, cluster_endpoint, cluster_ca_data, cluster_security_group_id
#   - nlb:              cluster_name
#
# Uso:
#   terraform init
#   terraform apply \
#     -var="environment=prod" \
#     -var="vpc_id=vpc-049ae53c681eb0582" \
#     -var="private_subnet_ids=[\"subnet-0f81538068635fb98\",\"subnet-076f9a301bc4ac898\"]" \
#     -var="eks_cluster_role_arn=arn:aws:iam::200283853536:role/eks-grupo1a-prod-cluster-role" \
#     -var="fargate_pod_execution_role_arn=arn:aws:iam::200283853536:role/eks-grupo1a-prod-fargate-pod-execution-role"
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Diplomado"
      BankCode    = "grupo1a"
      Environment = var.environment
      Component   = "eks"
      ManagedBy   = "Terraform"
    }
  }
}

provider "tls" {}
provider "null" {}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nombre del ambiente (dev, pt, stage, prod)"
  type        = string
  default     = "prod"
}

# --- Inputs de componente vpc ---
variable "vpc_id" {
  description = "ID de la VPC — output del componente vpc"
  type        = string
  default     = "vpc-049ae53c681eb0582"
}

variable "private_subnet_ids" {
  description = "IDs de subnets privadas — output del componente vpc"
  type        = list(string)
  default     = ["subnet-0f81538068635fb98", "subnet-076f9a301bc4ac898"]
}

# --- Inputs de componente iam ---
variable "eks_cluster_role_arn" {
  description = "ARN del IAM Role para EKS Cluster — output del componente iam"
  type        = string
  default     = "arn:aws:iam::200283853536:role/eks-grupo1a-prod-cluster-role"
}

variable "fargate_pod_execution_role_arn" {
  description = "ARN del IAM Role para Fargate Pod Execution — output del componente iam"
  type        = string
  default     = "arn:aws:iam::200283853536:role/eks-grupo1a-prod-fargate-pod-execution-role"
}

# --- Configuración del cluster ---
variable "cluster_name" {
  description = "Nombre del cluster EKS. Si no se especifica, se genera automáticamente."
  type        = string
  default     = "eks-cm-grupo1a-prod"
}

variable "cluster_version" {
  description = "Versión de Kubernetes"
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_private_access" {
  description = "Habilitar acceso privado al endpoint del cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Habilitar acceso público al endpoint del cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs permitidos para acceso público al endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Tipos de logs del cluster a habilitar"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "bank_namespaces" {
  description = "Mapa de bancos con sus namespaces de Kubernetes para los Fargate Profiles"
  type = map(object({
    namespace = string
  }))
  default = {
    grupo1a = { namespace = "grupo1a-ms" }
  }
}

variable "cluster_admin_arns" {
  description = "ARNs de usuarios/roles IAM con acceso admin al cluster"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags adicionales a aplicar a todos los recursos"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------
locals {
  cluster_name = var.cluster_name != "" ? var.cluster_name : "eks-cm-${var.environment}"

  fargate_bank_profiles = {
    for bank, config in var.bank_namespaces : bank => {
      name      = "${bank}-ms"
      namespace = config.namespace
    }
  }
}

# =============================================================================
# EKS CLUSTER
# =============================================================================

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = var.eks_cluster_role_arn

  # Necesario para clusters con Fargate (sin node groups)
  bootstrap_self_managed_addons = true

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(var.tags, {
    Name = local.cluster_name
  })

  # Ignora cambios en configuraciones que causan bugs en AWS provider 5.x
  # https://github.com/hashicorp/terraform-provider-aws/issues/39765
  lifecycle {
    ignore_changes = [
      compute_config,
      bootstrap_self_managed_addons,
      storage_config
    ]
  }

  depends_on = [aws_cloudwatch_log_group.eks]
}

# =============================================================================
# CLOUDWATCH LOG GROUP
# =============================================================================

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-logs"
  })
}

# =============================================================================
# OIDC PROVIDER (para IRSA - IAM Roles for Service Accounts)
# =============================================================================

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-oidc-provider"
  })
}

# =============================================================================
# FARGATE PROFILES
# =============================================================================

# Fargate Profile para kube-system (CoreDNS, AWS Load Balancer Controller)
resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "kube-system"
  pod_execution_role_arn = var.fargate_pod_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = "kube-system"
  }

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-fargate-kube-system"
  })
}

# Fargate Profiles para cada banco
resource "aws_eks_fargate_profile" "bank" {
  for_each = local.fargate_bank_profiles

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = each.value.name
  pod_execution_role_arn = var.fargate_pod_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = each.value.namespace
  }

  tags = merge(var.tags, {
    Name     = "${local.cluster_name}-fargate-${each.value.name}"
    BankCode = each.key
  })
}

# =============================================================================
# COREDNS RESTART
# En EKS con Fargate, CoreDNS queda en Pending hasta hacer restart
# =============================================================================

resource "null_resource" "coredns_restart" {
  triggers = {
    fargate_profile_id = aws_eks_fargate_profile.kube_system.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.aws_region}
      kubectl rollout restart deployment coredns -n kube-system
    EOT
  }

  depends_on = [aws_eks_fargate_profile.kube_system]
}

# =============================================================================
# EKS ACCESS ENTRIES (acceso IAM al cluster)
# =============================================================================

resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.cluster_admin_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-access-entry"
  })
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = toset(var.cluster_admin_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# -----------------------------------------------------------------------------
# Outputs
# (Anotar estos valores para pasarlos como -var a los siguientes componentes)
# -----------------------------------------------------------------------------
output "cluster_name" {
  description = "Nombre del cluster EKS — input requerido para: lb-controller, fargate-logging, alb-initializer, nlb"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint del API server — input requerido para: lb-controller, fargate-logging, alb-initializer"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_data" {
  description = "Certificate Authority data (base64) — input requerido para: lb-controller, fargate-logging, alb-initializer"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security Group del cluster EKS — input requerido para: alb-initializer"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN del OIDC Provider — input requerido para: lb-controller"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL del OIDC Provider (sin https://) — input requerido para: lb-controller"
  value       = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

output "oidc_issuer" {
  description = "URL completa del OIDC issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_arn" {
  description = "ARN del cluster EKS"
  value       = aws_eks_cluster.main.arn
}

output "cluster_version" {
  description = "Versión de Kubernetes del cluster"
  value       = aws_eks_cluster.main.version
}

output "cloudwatch_log_group_name" {
  description = "Nombre del CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.eks.name
}
