# =============================================================================
# Component: VPC - Diplomado Grupo 1A
# =============================================================================
# Crea la red base para el ambiente: VPC, subnets públicas y privadas,
# Internet Gateway, NAT Gateways y tablas de rutas.
#
# No depende de ningún otro componente.
#
# Outputs necesarios para los siguientes componentes:
#   - eks:               vpc_id, private_subnet_ids
#   - alb-security-groups: vpc_id, vpc_cidr
#   - alb-initializer:   private_subnet_ids
#   - nlb:               vpc_id, vpc_cidr, private_subnet_ids
#   - vpc-link:          private_subnet_ids
#
# Uso:
#   terraform init
#   terraform apply -var="environment=prod"
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
      Project     = "grupo1a"
      Environment = var.environment
      Component   = "vpc"
      ManagedBy   = "Terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
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

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.11.0.0/16"
}

variable "az_count" {
  description = "Número de Availability Zones a usar"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway para subnets privadas"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "Nombre del cluster EKS (para tags de subnets Kubernetes). Si no se especifica, se usa el nombre por defecto."
  type        = string
  default     = "eks-cm-grupo1a-prod"
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
  vpc_name         = "vpc-grupo1a-${var.environment}"
  eks_cluster_name = var.eks_cluster_name != "" ? var.eks_cluster_name : "eks-cm-grupo1a-${var.environment}"

  # Seleccionar las primeras N AZs disponibles
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = local.vpc_name
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${local.vpc_name}-igw"
  })
}

# -----------------------------------------------------------------------------
# Subnets Públicas (para NAT Gateways, recursos públicos)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(local.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                            = "${local.vpc_name}-public-${local.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  })
}

# -----------------------------------------------------------------------------
# Subnets Privadas (para EKS Fargate, ALBs, NLBs)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(local.availability_zones))
  availability_zone = local.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                                            = "${local.vpc_name}-private-${local.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  })
}

# -----------------------------------------------------------------------------
# Elastic IPs para NAT Gateways
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? length(local.availability_zones) : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${local.vpc_name}-nat-eip-${local.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# NAT Gateways (uno por AZ para alta disponibilidad)
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? length(local.availability_zones) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${local.vpc_name}-nat-${local.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Table - Pública
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${local.vpc_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(local.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Route Tables - Privadas (una por AZ, apunta al NAT Gateway de su AZ)
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  count  = length(local.availability_zones)
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${local.vpc_name}-private-rt-${local.availability_zones[count.index]}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(local.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -----------------------------------------------------------------------------
# Outputs
# (Anotar estos valores para pasarlos como -var a los siguientes componentes)
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID de la VPC — input requerido para: eks, alb-security-groups, nlb, vpc-link"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC — input requerido para: alb-security-groups, nlb"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de subnets privadas — input requerido para: eks, alb-initializer, nlb, vpc-link"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability Zones utilizadas"
  value       = local.availability_zones
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "vpc_name" {
  description = "Nombre de la VPC"
  value       = local.vpc_name
}

output "eks_cluster_name_used" {
  description = "Nombre del cluster EKS usado en los tags de subnets"
  value       = local.eks_cluster_name
}
