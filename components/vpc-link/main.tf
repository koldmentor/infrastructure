# =============================================================================
# Component: VPC Link - Cash Management
# =============================================================================
# Crea el VPC Link V2 que conecta el API Gateway (público) con el NLB
# (privado dentro de la VPC), permitiendo que el API Gateway enrute tráfico
# a recursos internos de forma segura sin exponer el NLB a internet.
#
# Inputs requeridos de otros componentes:
#   - nlb: security_group_id
#   - vpc: private_subnet_ids
#
# Outputs necesarios para el siguiente componente:
#   - api-gateway: vpc_link_id
#
# Uso:
#   terraform init
#   # Primero actualiza nlb_security_group_id con el output del componente nlb:
#   #   terraform -chdir=../nlb output -raw security_group_id
#   terraform apply \
#     -var="nlb_security_group_id=<output de nlb>"
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
      Project     = "Diplomado"
      Environment = var.environment
      BankCode    = var.bank_code
      Component   = "vpc-link"
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

# --- Inputs de componente nlb ---
variable "nlb_security_group_id" {
  description = "ID del Security Group del NLB — output del componente nlb"
  type        = string
  default     = "sg-052478da4b482ab77"
}

# --- Inputs de componente vpc ---
variable "private_subnet_ids" {
  description = "IDs de subnets privadas — output del componente vpc"
  type        = list(string)
  default     = ["subnet-0f81538068635fb98", "subnet-076f9a301bc4ac898"]
}

variable "vpc_link_name" {
  description = "Nombre del VPC Link. Si no se especifica, se genera automáticamente."
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
  vpc_link_name = var.vpc_link_name != null ? var.vpc_link_name : "vpc-link-cm-${var.bank_code}"
}

# --- Input del NLB ARN ---
variable "nlb_arn" {
  description = "ARN del NLB — output del componente nlb"
  type        = string
  default     = "arn:aws:elasticloadbalancing:us-east-1:200283853536:loadbalancer/net/nlb-apigateway-cm-grupo1a/ad8a0410a5bddba9"
}

# =============================================================================
# VPC LINK V1 (REST API)
# Conecta el API Gateway REST (V1) con el NLB interno
# =============================================================================

resource "aws_api_gateway_vpc_link" "this" {
  name        = local.vpc_link_name
  target_arns = [var.nlb_arn]

  tags = merge(var.tags, {
    Name     = local.vpc_link_name
    BankCode = var.bank_code
  })
}

# -----------------------------------------------------------------------------
# Outputs
# (Anotar este valor para pasarlo como -var al componente api-gateway)
# -----------------------------------------------------------------------------
output "vpc_link_id" {
  description = "ID del VPC Link V1 (REST API) — input requerido para: api-gateway"
  value       = aws_api_gateway_vpc_link.this.id
}

output "vpc_link_name" {
  description = "Nombre del VPC Link"
  value       = aws_api_gateway_vpc_link.this.name
}

output "vpc_link_arn" {
  description = "ARN del VPC Link"
  value       = aws_api_gateway_vpc_link.this.arn
}
