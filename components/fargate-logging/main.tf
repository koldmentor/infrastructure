# =============================================================================
# Component: Fargate Logging - Cash Management
# =============================================================================
# Configura Fluent Bit para enviar logs de pods Fargate a CloudWatch:
# - Namespace aws-observability (requerido por AWS Fargate logging)
# - ConfigMap aws-logging con configuración de Fluent Bit
#
# Inputs requeridos de otros componentes:
#   - eks: cluster_name, cluster_endpoint, cluster_ca_data
#
# Referencia: https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html
#
# Uso:
#   terraform init
#   terraform apply
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
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

# --- Inputs de componente eks ---
variable "cluster_name" {
  description = "Nombre del cluster EKS — output del componente eks"
  type        = string
  default     = "eks-cm-grupo1a-prod"
}

variable "cluster_endpoint" {
  description = "Endpoint del API server del cluster EKS — output del componente eks"
  type        = string
  default     = "https://C04924D0D88779667269961B05B946B4.gr7.us-east-1.eks.amazonaws.com"
}

variable "cluster_ca_data" {
  description = "Certificate Authority data (base64) del cluster EKS — output del componente eks"
  type        = string
  sensitive   = true
  default     = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJSGhaLzlyWXh1S293RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TmpBeU1qWXhOekE0TURaYUZ3MHpOakF5TWpReE56RXpNRFphTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUUN4V2IwWnhLSGdVK21ELzdEdWE3VEJvMzJTVW5LeWFndUhBVGRGSmtwVFhkWmEyUDA4RVlFbzlMZkIKa04rbkNqRlo1RHRwUVZnSTY3TFBpMytBbU45aEprV3YrWmJKY1BRbmFBaXhLQS9vUEY0RS9yZ1IyQ1FBbFRlcAoydTg1ZlEvY25zZXhDdmVITWF1bHl3ZGpMNU45KysxaGJUMnpwT1RFQnZLVWRlOVFWTThpUk9JS1Y4U3RIZTdkCldvWHdlUENGRVNNcUk5UGk0d1hJeDh1Z0tINkpvL3EvWmxoQ2RlWkRWcHd1NnhSRERCWWFlM2JxZ1ZTVEs2cEoKT2RXc0pXQzlrVGxtRjlqQmI2SHdqQmtGUG5Vb1NRYmV5R05xcTJlOHNmN1dzOGRMeHdXam13WVBXVHdYTUJVQwoya3EvdjBSQU9iNldabWtmT0o1cFJwazQ1YWRMQWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJSWGFKemxGUjlEakhjSVlDSnJTR1lQYVZMSDN6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1RxSFl2MGdFRQoyN2p0ek5IOEVSaWgvbUFsSCtsRGkyOUtPUG9IMmlyaklVOW1DQ1BJZ3gveE5YMGhUNnFLN0h4eDljOWU5bU5nCkIvWnVIaU1rVjZhb21ldDBYeWdHc2V0NTdCRWRHWUlwT1RWMG5yOCtLUzhoeGtRejlFMkp2NW9TMTY2blQ2VnAKU1J1eWZhWVJxaTlodTNLNVgzUnIvdTZ3N1dRSC9jZDJnUnIwaThteUEydVpnd0xVbE4vcE1xTXc5WmlEWWtnVgoyOUYzcHExNjZkcS9na2Nja09oajlHTVlKTXFQaHRrajZaTDU1WUZ3bmRaQ2RFTktWVTZCYllic3lMS2hqT2NNClhnWmZ5RmtHdUFBZDFJbkdNSEpUNWh3NUQzWWdZWU9CZlpMcXJObEJHdUVFTnY1KzlhcHIwOTV6cjdSYzRLdlUKdVYyTnlNOURuYWF2Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
}

# =============================================================================
# NAMESPACE: aws-observability
# Requerido por AWS Fargate para la configuración de logging
# =============================================================================

resource "kubernetes_namespace" "aws_observability" {
  metadata {
    name = "aws-observability"

    labels = {
      "aws-observability" = "enabled"
    }
  }
}

# =============================================================================
# CONFIGMAP: aws-logging
# Configuración de Fluent Bit para enviar logs a CloudWatch
# =============================================================================

resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws_observability.metadata[0].name
  }

  data = {
    "flb_log_cw" = "true"

    "output.conf" = <<-EOT
      [OUTPUT]
          Name cloudwatch_logs
          Match *
          region ${var.aws_region}
          log_group_name /aws/eks/${var.cluster_name}/pods
          log_stream_prefix fargate-
          auto_create_group true
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name docker
          Format json
          Time_Key time
          Time_Format %Y-%m-%dT%H:%M:%S.%LZ
    EOT

    "filters.conf" = <<-EOT
      [FILTER]
          Name parser
          Match *
          Key_name log
          Parser docker
          Reserve_Data On
    EOT
  }

  depends_on = [kubernetes_namespace.aws_observability]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "namespace_name" {
  description = "Nombre del namespace aws-observability"
  value       = kubernetes_namespace.aws_observability.metadata[0].name
}

output "configmap_name" {
  description = "Nombre del ConfigMap de logging"
  value       = kubernetes_config_map.aws_logging.metadata[0].name
}

output "log_group_name" {
  description = "Nombre del CloudWatch Log Group donde se envían los logs"
  value       = "/aws/eks/${var.cluster_name}/pods"
}
