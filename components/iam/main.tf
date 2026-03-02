# =============================================================================
# Component: IAM - Diplomado Grupo 1A
# =============================================================================
# Crea los roles IAM necesarios para el cluster EKS y los pods Fargate:
# - EKS Cluster Role (para el control plane)
# - Fargate Pod Execution Role (para los pods, con permisos de ECR, S3, SQS, etc.)
# - EKS Admin Role (opcional, para que usuarios IAM accedan al cluster)
#
# No depende de ningún otro componente.
#
# Outputs necesarios para los siguientes componentes:
#   - eks: eks_cluster_role_arn, fargate_pod_execution_role_arn
#   - lb-controller: (el lb-controller crea su propio IRSA role internamente)
#
# Uso:
#   terraform init
#   terraform apply -var="environment=ginko"
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
      Component   = "iam"
      ManagedBy   = "Terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

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

variable "eks_cluster_role_name" {
  description = "Nombre del IAM Role para EKS Cluster. Si no se especifica, se genera automáticamente."
  type        = string
  default     = "eks-grupo1a-prod-cluster-role"
}

variable "fargate_pod_execution_role_name" {
  description = "Nombre del IAM Role para Fargate Pod Execution. Si no se especifica, se genera automáticamente."
  type        = string
  default     = "eks-grupo1a-prod-fargate-pod-execution-role"
}

variable "fargate_combined_policy_name" {
  description = "Nombre de la política combinada para Fargate. Si no se especifica, se genera automáticamente."
  type        = string
  default     = "eks-grupo1a-prod-fargate-combined-policy"
}

variable "enable_eks_admin_role" {
  description = "Habilita la creación del rol de admin para EKS"
  type        = bool
  default     = false
}

variable "eks_admin_role_name" {
  description = "Nombre del IAM Role para EKS Admin. Si no se especifica, se genera automáticamente."
  type        = string
  default     = "eks-grupo1a-prod-admin-role"
}

variable "eks_admin_trusted_arns" {
  description = "Lista de ARNs de usuarios/roles IAM que pueden asumir el rol de admin EKS"
  type        = list(string)
  default     = []
}

variable "eks_admin_external_id" {
  description = "External ID requerido para asumir el rol admin (seguridad adicional). Dejar null para no requerir."
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
  account_id = data.aws_caller_identity.current.account_id

  eks_cluster_role_name           = var.eks_cluster_role_name != null ? var.eks_cluster_role_name : "eks-grupo1a-${var.environment}-cluster-role"
  fargate_pod_execution_role_name = var.fargate_pod_execution_role_name != null ? var.fargate_pod_execution_role_name : "eks-grupo1a-${var.environment}-fargate-pod-execution-role"
  fargate_combined_policy_name    = var.fargate_combined_policy_name != null ? var.fargate_combined_policy_name : "eks-grupo1a-${var.environment}-fargate-combined-policy"
  eks_admin_role_name             = var.eks_admin_role_name != null ? var.eks_admin_role_name : "eks-grupo1a-${var.environment}-admin-role"
}

# =============================================================================
# IAM ROLE - EKS CLUSTER (Control Plane)
# =============================================================================

resource "aws_iam_role" "eks_cluster" {
  name = local.eks_cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = local.eks_cluster_role_name
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# =============================================================================
# IAM ROLE - FARGATE POD EXECUTION
# =============================================================================

resource "aws_iam_role" "fargate_pod_execution" {
  name = local.fargate_pod_execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = local.fargate_pod_execution_role_name
  })
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_pod_execution.name
}

# =============================================================================
# IAM POLICY - FARGATE COMBINED
# Permisos adicionales para los microservicios: ECR, S3, SQS, SNS, DynamoDB,
# Secrets Manager, SSM, CloudWatch, KMS, Lambda
# =============================================================================

resource "aws_iam_policy" "fargate_combined" {
  name        = local.fargate_combined_policy_name
  description = "Politica combinada para Fargate - ECR, S3, SQS, SNS, DynamoDB, Secrets Manager, SSM, CloudWatch, KMS, Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.environment}-*",
          "arn:aws:s3:::${var.environment}-*/*"
        ]
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${local.account_id}:${var.environment}-*"
      },
      {
        Sid    = "SNSAccess"
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:GetTopicAttributes",
          "sns:ListTopics"
        ]
        Resource = "arn:aws:sns:${var.aws_region}:${local.account_id}:${var.environment}-*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.environment}-*",
          "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.environment}-*/index/*"
        ]
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${var.environment}/*"
      },
      {
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${var.environment}/*"
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/eks/eks-grupo1a-${var.environment}/*",
          "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/eks/eks-grupo1a-${var.environment}/*:*"
        ]
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:${local.account_id}:key/*"
      },
      {
        Sid    = "LambdaInvokeAccess"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeAsync"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.environment}-*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate_combined" {
  policy_arn = aws_iam_policy.fargate_combined.arn
  role       = aws_iam_role.fargate_pod_execution.name
}

# =============================================================================
# IAM POLICY - FARGATE FLUENT BIT LOGGING
# Permisos para que Fluent Bit en Fargate pueda enviar logs a CloudWatch
# =============================================================================

resource "aws_iam_policy" "fargate_fluent_bit_logging" {
  name        = "eks-grupo1a-${var.environment}-fargate-fluent-bit-logging"
  description = "Politica para Fluent Bit en Fargate - CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FluentBitCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate_fluent_bit_logging" {
  policy_arn = aws_iam_policy.fargate_fluent_bit_logging.arn
  role       = aws_iam_role.fargate_pod_execution.name
}

# =============================================================================
# IAM ROLE - EKS ADMIN (opcional)
# Permite que usuarios IAM accedan al cluster EKS con permisos de admin
# =============================================================================

resource "aws_iam_role" "eks_admin" {
  count = var.enable_eks_admin_role ? 1 : 0

  name = local.eks_admin_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      merge(
        {
          Effect = "Allow"
          Principal = {
            AWS = var.eks_admin_trusted_arns
          }
          Action = "sts:AssumeRole"
        },
        var.eks_admin_external_id != null ? {
          Condition = {
            StringEquals = {
              "sts:ExternalId" = var.eks_admin_external_id
            }
          }
        } : {}
      )
    ]
  })

  tags = merge(var.tags, {
    Name = local.eks_admin_role_name
  })
}

# Politica mínima para poder usar kubectl (describe cluster, get token)
resource "aws_iam_role_policy" "eks_admin_policy" {
  count = var.enable_eks_admin_role ? 1 : 0

  name = "eks-admin-access"
  role = aws_iam_role.eks_admin[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Outputs
# (Anotar estos valores para pasarlos como -var al componente eks)
# -----------------------------------------------------------------------------
output "eks_cluster_role_arn" {
  description = "ARN del IAM Role para EKS Cluster — input requerido para: eks"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_cluster_role_name" {
  description = "Nombre del IAM Role para EKS Cluster"
  value       = aws_iam_role.eks_cluster.name
}

output "fargate_pod_execution_role_arn" {
  description = "ARN del IAM Role para Fargate Pod Execution — input requerido para: eks"
  value       = aws_iam_role.fargate_pod_execution.arn
}

output "fargate_pod_execution_role_name" {
  description = "Nombre del IAM Role para Fargate Pod Execution"
  value       = aws_iam_role.fargate_pod_execution.name
}

output "eks_admin_role_arn" {
  description = "ARN del IAM Role admin de EKS (null si no fue creado)"
  value       = var.enable_eks_admin_role ? aws_iam_role.eks_admin[0].arn : null
}

output "aws_account_id" {
  description = "ID de la cuenta AWS"
  value       = local.account_id
}
