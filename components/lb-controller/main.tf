# =============================================================================
# Component: LB Controller - grupo1a
# =============================================================================
# Instala el AWS Load Balancer Controller en el cluster EKS:
# - IAM Policy con permisos para gestionar ALBs y NLBs
# - IAM Role con IRSA (IAM Roles for Service Accounts)
# - Kubernetes Service Account con anotación del rol
# - Helm Release del controller
#
# Inputs requeridos de otros componentes:
#   - eks: cluster_name, cluster_endpoint, cluster_ca_data, oidc_provider_arn, oidc_provider_url
#   - vpc: vpc_id
#
# Uso:
#   terraform init
#   terraform apply \
#     -var="environment=prod" \
#     -var="cluster_name=$(terraform -chdir=../eks output -raw cluster_name)" \
#     -var="cluster_endpoint=$(terraform -chdir=../eks output -raw cluster_endpoint)" \
#     -var="cluster_ca_data=$(terraform -chdir=../eks output -raw cluster_certificate_authority_data)" \
#     -var="oidc_provider_arn=$(terraform -chdir=../eks output -raw oidc_provider_arn)" \
#     -var="oidc_provider_url=$(terraform -chdir=../eks output -raw oidc_provider_url)" \
#     -var="vpc_id=$(terraform -chdir=../vpc output -raw vpc_id)"
#
# NOTA: Todas las variables marcadas sin default son OBLIGATORIAS.
#       Obtén sus valores de los outputs de los componentes eks y vpc.
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# -----------------------------------------------------------------------------
# Providers
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "grupo1a"
      Environment = var.environment
      Component   = "lb-controller"
      ManagedBy   = "Terraform"
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
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

  validation {
    condition     = contains(["dev", "pt", "stage", "prod"], var.environment)
    error_message = "El ambiente debe ser: dev, pt, stage o prod."
  }
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

variable "oidc_provider_arn" {
  description = "ARN del OIDC Provider — output del componente eks"
  type        = string
  default     = "arn:aws:iam::200283853536:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/C04924D0D88779667269961B05B946B4"
}

variable "oidc_provider_url" {
  description = "URL del OIDC Provider sin https:// — output del componente eks"
  type        = string
  default     = "oidc.eks.us-east-1.amazonaws.com/id/C04924D0D88779667269961B05B946B4"
}

# --- Inputs de componente vpc ---
variable "vpc_id" {
  description = "ID de la VPC — output del componente vpc"
  type        = string
  default     = "vpc-049ae53c681eb0582"
}

# --- Configuración del LB Controller ---
variable "lb_controller_policy_arn" {
  description = "ARN de una política IAM existente para el LB Controller. Si es null, se crea una nueva."
  type        = string
  default     = null
}

variable "lb_controller_role_name" {
  description = "Nombre del IAM Role para el LB Controller. Si no se especifica, se genera automáticamente."
  type        = string
  default     = null
}

variable "helm_chart_version" {
  description = "Versión del Helm chart del AWS Load Balancer Controller"
  type        = string
  default     = "1.7.1"
}

variable "namespace" {
  description = "Namespace de Kubernetes donde se instala el controller"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Nombre del Service Account de Kubernetes"
  type        = string
  default     = "aws-load-balancer-controller"
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
  role_name = var.lb_controller_role_name != null ? var.lb_controller_role_name : "eks-${var.cluster_name}-aws-load-balancer-controller-role"
}

# =============================================================================
# IAM POLICY (si no se proporciona una existente)
# =============================================================================

resource "aws_iam_policy" "lb_controller" {
  count = var.lb_controller_policy_arn == null ? 1 : 0

  name        = "AWSLoadBalancerControllerIAMPolicy-${var.environment}"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = { "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses", "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways", "ec2:DescribeVpcs", "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeTags", "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools", "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes", "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates", "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules", "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes", "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags", "elasticloadbalancing:DescribeTrustStores"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient", "acm:ListCertificates", "acm:DescribeCertificate",
          "iam:ListServerCertificates", "iam:GetServerCertificate",
          "waf-regional:GetWebACL", "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL", "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL", "wafv2:GetWebACLForResource", "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState", "shield:DescribeProtection",
          "shield:CreateProtection", "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateSecurityGroup"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
          Null         = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup"]
        Resource = "*"
        Condition = { Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"]
        Resource = "*"
        Condition = { Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes", "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource  = "*"
        Condition = { Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = { "elasticloadbalancing:CreateAction" = ["CreateTargetGroup", "CreateLoadBalancer"] }
          Null         = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:SetWebAcl", "elasticloadbalancing:ModifyListener", "elasticloadbalancing:AddListenerCertificates", "elasticloadbalancing:RemoveListenerCertificates", "elasticloadbalancing:ModifyRule"]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

locals {
  policy_arn = var.lb_controller_policy_arn != null ? var.lb_controller_policy_arn : aws_iam_policy.lb_controller[0].arn
}

# =============================================================================
# IAM ROLE CON IRSA
# =============================================================================

resource "aws_iam_role" "lb_controller" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = local.role_name
    Component = "aws-load-balancer-controller"
  })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  policy_arn = local.policy_arn
  role       = aws_iam_role.lb_controller.name
}

# =============================================================================
# KUBERNETES SERVICE ACCOUNT
# =============================================================================

resource "kubernetes_service_account_v1" "lb_controller" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }

    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
  }
}

# =============================================================================
# HELM RELEASE - AWS LOAD BALANCER CONTROLLER
# =============================================================================

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = var.namespace
  version    = var.helm_chart_version

  values = [
    yamlencode({
      clusterName = var.cluster_name
      serviceAccount = {
        create = false
        name   = var.service_account_name
      }
      region = var.aws_region
      vpcId  = var.vpc_id
    })
  ]

  depends_on = [
    kubernetes_service_account_v1.lb_controller,
    aws_iam_role_policy_attachment.lb_controller
  ]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "lb_controller_role_arn" {
  description = "ARN del IAM Role del AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "lb_controller_role_name" {
  description = "Nombre del IAM Role del AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.name
}

output "lb_controller_policy_arn" {
  description = "ARN de la IAM Policy usada por el LB Controller"
  value       = local.policy_arn
}

output "helm_release_status" {
  description = "Estado del Helm release del LB Controller"
  value       = helm_release.lb_controller.status
}
