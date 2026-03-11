# =============================================================================
# Component: CloudFront con VPC Origin - Diplomado Grupo 1A
# =============================================================================
# Crea una distribución CloudFront que se conecta a un ALB interno (privado)
# mediante VPC Origins, sin necesidad de exponer el ALB a Internet.
#
# Inputs requeridos de otros componentes:
#   - alb-security-groups: alb_security_group_id
#
# El ALB ARN se obtiene del ALB creado por el Kubernetes Ingress Controller.
# CloudFront VPC Origins resuelve la VPC y subnets automáticamente desde el ARN.
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
      Project     = "Diplomado"
      BankCode    = "grupo1a"
      Environment = var.environment
      Component   = "cloudfront"
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

# --- Input de componente alb-security-groups ---
variable "alb_security_group_id" {
  description = "ID del Security Group del ALB — SG del LoadBalancer de Kubernetes"
  type        = string
  default     = "sg-04e5ef811f1de186d"
}

# --- Input del ALB de Kubernetes (Ingress Controller) ---
variable "alb_arn" {
  description = "ARN del ALB interno al que CloudFront se conectará via VPC Origin"
  type        = string
  default     = "arn:aws:elasticloadbalancing:us-east-1:200283853536:loadbalancer/app/k8s-frontendalb-4063d04f64/f37470601d7eb118"
}

variable "tags" {
  description = "Tags adicionales a aplicar a todos los recursos"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_lb" "alb" {
  arn = var.alb_arn
}

# -----------------------------------------------------------------------------
# CloudFront VPC Origin
# -----------------------------------------------------------------------------
resource "aws_cloudfront_vpc_origin" "alb" {
  vpc_origin_endpoint_config {
    name                   = "grupo1a-alb-vpc-origin-${var.environment}"
    arn                    = data.aws_lb.alb.arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = merge(var.tags, {
    Name = "grupo1a-vpc-origin-${var.environment}"
  })
}

# -----------------------------------------------------------------------------
# CloudFront Distribution
# -----------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  comment             = "Grupo1A - CloudFront con VPC Origin al ALB interno (${var.environment})"
  price_class         = "PriceClass_100"
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  wait_for_deployment = true

  origin {
    domain_name = data.aws_lb.alb.dns_name
    origin_id   = "alb-vpc-origin"

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.alb.id
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-vpc-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Authorization"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, {
    Name = "grupo1a-cloudfront-${var.environment}"
  })
}

# -----------------------------------------------------------------------------
# Security Group Rule - Permitir tráfico de CloudFront al ALB
# -----------------------------------------------------------------------------
# CloudFront VPC Origins usa el prefijo administrado de AWS para CloudFront.
# Se agrega una regla al SG del ALB para permitir tráfico desde CloudFront.
# -----------------------------------------------------------------------------
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group_rule" "cloudfront_to_alb" {
  count = var.alb_security_group_id != "" ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  security_group_id = var.alb_security_group_id
  description       = "Allow CloudFront VPC Origin traffic to ALB"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "cloudfront_distribution_id" {
  description = "ID de la distribución CloudFront"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_domain_name" {
  description = "Domain name de CloudFront (usar para acceder a la aplicación)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_arn" {
  description = "ARN de la distribución CloudFront"
  value       = aws_cloudfront_distribution.main.arn
}

output "vpc_origin_id" {
  description = "ID del VPC Origin de CloudFront"
  value       = aws_cloudfront_vpc_origin.alb.id
}
