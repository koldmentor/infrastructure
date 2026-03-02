# =============================================================================
# Component: NLB - Cash Management
# =============================================================================
# Crea el Network Load Balancer interno que conecta API Gateway con el ALB de
# Kubernetes, y registra las IPs del ALB en el Target Group:
# - Security Group del NLB
# - NLB interno (tipo network)
# - Target Group (tipo IP para registrar IPs del ALB de K8s)
# - Listener TCP:80
# - null_resource: registra IPs del ALB en el Target Group
#
# Flujo: API Gateway → VPC Link → NLB → ALB (Kubernetes) → Pods
#
# Inputs requeridos de otros componentes:
#   - vpc:              vpc_id, vpc_cidr, private_subnet_ids
#   - eks:              cluster_name
#   - alb-initializer:  ingress_group_name, alb_ready
#
# Outputs necesarios para los siguientes componentes:
#   - vpc-link:     security_group_id
#   - api-gateway:  nlb_arn, nlb_dns_name
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
      Environment = var.environment
      BankCode    = var.bank_code
      Component   = "nlb"
      ManagedBy   = "Terraform"
    }
  }
}

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

variable "private_subnet_ids" {
  description = "IDs de subnets privadas — output del componente vpc"
  type        = list(string)
  default     = ["subnet-0f81538068635fb98", "subnet-076f9a301bc4ac898"]
}

# --- Inputs de componente eks ---
variable "cluster_name" {
  description = "Nombre del cluster EKS — output del componente eks (para kubeconfig del script)"
  type        = string
  default     = "eks-cm-grupo1a-prod"
}

# --- Inputs de componente alb-initializer ---
variable "ingress_group_name" {
  description = "Nombre del grupo de Ingress del ALB — output del componente alb-initializer"
  type        = string
  default     = "grupo1a-shared-alb"
}

variable "alb_ready" {
  description = "Trigger de sincronización que indica que el ALB está listo — output del componente alb-initializer"
  type        = string
  default     = ""
}

# --- Configuración del NLB ---
variable "nlb_name" {
  description = "Nombre del NLB. Si no se especifica, se genera automáticamente."
  type        = string
  default     = null
}

variable "target_group_name" {
  description = "Nombre del Target Group. Si no se especifica, se genera automáticamente."
  type        = string
  default     = null
}

variable "security_group_name" {
  description = "Nombre del Security Group. Si no se especifica, se genera automáticamente."
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "Path para el health check del Target Group"
  type        = string
  default     = "/api/health"
}

variable "enable_deletion_protection" {
  description = "Habilitar protección contra eliminación en el NLB"
  type        = bool
  default     = false
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
  project_name        = "cm-${var.bank_code}"
  nlb_name            = var.nlb_name != null ? var.nlb_name : "nlb-apigateway-${local.project_name}"
  target_group_name   = var.target_group_name != null ? var.target_group_name : "tg-nlb-to-alb-${local.project_name}"
  security_group_name = var.security_group_name != null ? var.security_group_name : "${local.project_name}-nlb-sg"
}

# =============================================================================
# SECURITY GROUP para NLB
# =============================================================================

resource "aws_security_group" "nlb" {
  name        = local.security_group_name
  description = "Security group for NLB - allows traffic from VPC Link"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow traffic from VPC Link"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = local.security_group_name
  })
}

# =============================================================================
# NETWORK LOAD BALANCER (Interno)
# =============================================================================

resource "aws_lb" "nlb" {
  name               = local.nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = local.nlb_name
  })
}

# =============================================================================
# TARGET GROUP (tipo IP para IPs del ALB de Kubernetes)
# =============================================================================

resource "aws_lb_target_group" "alb" {
  name        = local.target_group_name
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = var.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 6
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name = local.target_group_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# LISTENER TCP:80
# =============================================================================

resource "aws_lb_listener" "tcp_80" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }

  tags = merge(var.tags, {
    Name = "${local.project_name}-nlb-listener-80"
  })
}

# =============================================================================
# REGISTRAR IPs del ALB de Kubernetes en el Target Group del NLB
# =============================================================================
# Se ejecuta DESPUÉS de que el alb-initializer crea el ALB.
# Usa kubectl para encontrar el DNS del ALB y lo resuelve a IPs.

resource "null_resource" "register_k8s_alb_ips" {
  triggers = {
    target_group_arn = aws_lb_target_group.alb.arn
    ingress_group    = var.ingress_group_name
    alb_ready        = var.alb_ready
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      echo "=== Configurando kubeconfig ==="
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}

      echo "=== Buscando ALB de Kubernetes (group: ${var.ingress_group_name}) ==="
      ALB_DNS=""
      ATTEMPTS=0
      MAX_ATTEMPTS=30

      while [ -z "$ALB_DNS" ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        ALB_DNS=$(kubectl get ingress --all-namespaces -o jsonpath='{.items[?(@.metadata.annotations.alb\.ingress\.kubernetes\.io/group\.name=="${var.ingress_group_name}")].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

        if [ -z "$ALB_DNS" ]; then
          ATTEMPTS=$((ATTEMPTS + 1))
          echo "Intento $ATTEMPTS/$MAX_ATTEMPTS: Esperando ALB de Kubernetes..."
          sleep 10
        fi
      done

      if [ -z "$ALB_DNS" ]; then
        echo "ERROR: No se encontró ALB de Kubernetes después de $MAX_ATTEMPTS intentos"
        exit 1
      fi

      echo "ALB DNS encontrado: $ALB_DNS"

      echo "=== Obteniendo IPs del ALB ==="
      sleep 30

      ALB_IPS=$(dig +short $ALB_DNS | grep -E '^[0-9]+\.' | head -10 || true)

      if [ -z "$ALB_IPS" ]; then
        ALB_NAME=$(echo $ALB_DNS | cut -d'.' -f1)
        ALB_IPS=$(aws ec2 describe-network-interfaces \
          --filters "Name=description,Values=*$ALB_NAME*" \
          --query 'NetworkInterfaces[].PrivateIpAddress' \
          --output text \
          --region ${var.aws_region} 2>/dev/null || true)
      fi

      if [ -z "$ALB_IPS" ]; then
        echo "ERROR: No se pudieron obtener las IPs del ALB"
        exit 1
      fi

      echo "IPs encontradas: $ALB_IPS"

      echo "=== Limpiando targets anteriores del Target Group ==="
      CURRENT_TARGETS=$(aws elbv2 describe-target-health \
        --target-group-arn ${aws_lb_target_group.alb.arn} \
        --query 'TargetHealthDescriptions[].Target.Id' \
        --output text \
        --region ${var.aws_region} 2>/dev/null || true)

      if [ -n "$CURRENT_TARGETS" ]; then
        for TARGET in $CURRENT_TARGETS; do
          echo "Eliminando target anterior: $TARGET"
          aws elbv2 deregister-targets \
            --target-group-arn ${aws_lb_target_group.alb.arn} \
            --targets Id=$TARGET \
            --region ${var.aws_region} || true
        done
      fi

      echo "=== Registrando IPs en Target Group del NLB ==="
      for IP in $ALB_IPS; do
        echo "Registrando IP: $IP"
        aws elbv2 register-targets \
          --target-group-arn ${aws_lb_target_group.alb.arn} \
          --targets Id=$IP,Port=80 \
          --region ${var.aws_region}
      done

      echo "=== Verificando registro ==="
      aws elbv2 describe-target-health \
        --target-group-arn ${aws_lb_target_group.alb.arn} \
        --region ${var.aws_region}

      echo "=== Registro completado exitosamente ==="
    EOT
  }

  depends_on = [
    aws_lb.nlb,
    aws_lb_target_group.alb,
    aws_lb_listener.tcp_80
  ]
}

# -----------------------------------------------------------------------------
# Outputs
# (Anotar estos valores para pasarlos como -var a los siguientes componentes)
# -----------------------------------------------------------------------------
output "nlb_arn" {
  description = "ARN del NLB — input requerido para: api-gateway"
  value       = aws_lb.nlb.arn
}

output "nlb_dns_name" {
  description = "DNS name del NLB — input requerido para: api-gateway"
  value       = aws_lb.nlb.dns_name
}

output "nlb_name" {
  description = "Nombre del NLB"
  value       = aws_lb.nlb.name
}

output "target_group_arn" {
  description = "ARN del Target Group"
  value       = aws_lb_target_group.alb.arn
}

output "security_group_id" {
  description = "ID del Security Group del NLB — input requerido para: vpc-link"
  value       = aws_security_group.nlb.id
}
