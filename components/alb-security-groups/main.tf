# =============================================================================
# Component: ALB Security Groups - Cash Management
# =============================================================================
# Crea los Security Groups reutilizados por el ALB de Kubernetes:
# - ALB Security Group: permite HTTP/HTTPS desde la VPC
# - Backend Security Group: permite tráfico desde el ALB hacia los pods
#
# NOTA: El ALB en sí es creado y gestionado por el Kubernetes Ingress Controller.
# Terraform solo gestiona los Security Groups que el ALB reutiliza.
#
# Inputs requeridos de otros componentes:
#   - vpc: vpc_id, vpc_cidr
#
# Outputs necesarios para los siguientes componentes:
#   - alb-initializer: alb_security_group_id, (+ eks cluster_security_group_id de eks)
#
# Uso:
#   terraform init
#   terraform apply
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
      Project     = "CashManagement"
      Environment = var.environment
      BankCode    = var.bank_code
      Component   = "alb-security-groups"
      ManagedBy   = "Terraform"
    }
  }
}

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

variable "bank_code" {
  description = "Código del banco (bbgo, bavv, bocc, bpop)"
  type        = string
  default     = "grupo1a"
}

# --- Inputs de componente vpc ---
variable "vpc_id" {
  description = "ID de la VPC — output del componente vpc"
  type        = string
  default     = "vpc-049ae53c681eb0582"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC — output del componente vpc"
  type        = string
  default     = "10.11.0.0/16"
}

variable "alb_security_group_name" {
  description = "Nombre del Security Group del ALB. Si no se especifica, se genera automáticamente."
  type        = string
  default     = null
}

variable "backend_security_group_name" {
  description = "Nombre del Security Group del backend. Si no se especifica, se genera automáticamente."
  type        = string
  default     = null
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
  project_name                = "cm-${var.bank_code}"
  alb_security_group_name     = var.alb_security_group_name != null ? var.alb_security_group_name : "${local.project_name}-alb-sg"
  backend_security_group_name = var.backend_security_group_name != null ? var.backend_security_group_name : "${local.project_name}-backend-sg"
}

# =============================================================================
# Security Group - ALB (reutilizado por el ALB de Kubernetes)
# Asignado mediante: alb.ingress.kubernetes.io/security-groups
# =============================================================================

resource "aws_security_group" "alb" {
  name        = local.alb_security_group_name
  description = "Security group for internal ALB (Kubernetes) - allows HTTP/HTTPS traffic from VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = local.alb_security_group_name
  })
}

# =============================================================================
# Security Group - Backend (EKS Pods)
# Permite tráfico desde el ALB hacia los pods de EKS
# =============================================================================

resource "aws_security_group" "backend" {
  name        = local.backend_security_group_name
  description = "Security group for backend pods - allows traffic from ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = local.backend_security_group_name
  })
}

# -----------------------------------------------------------------------------
# Outputs
# (Anotar estos valores para pasarlos como -var al componente alb-initializer)
# -----------------------------------------------------------------------------
output "alb_security_group_id" {
  description = "ID del Security Group del ALB — input requerido para: alb-initializer"
  value       = aws_security_group.alb.id
}

output "alb_security_group_name" {
  description = "Nombre del Security Group del ALB"
  value       = aws_security_group.alb.name
}

output "backend_security_group_id" {
  description = "ID del Security Group del backend (pods EKS)"
  value       = aws_security_group.backend.id
}

output "backend_security_group_name" {
  description = "Nombre del Security Group del backend"
  value       = aws_security_group.backend.name
}
