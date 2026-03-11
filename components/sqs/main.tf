# ============================================
# VARIABLES
# ============================================
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

# ============================================
# DEFINIR COLAS EN UN SOLO LUGAR
# ============================================
# Para agregar una nueva cola, simplemente agregue una entrada al mapa.
# El nombre final será: {environment}-{nombre_de_la_cola}
# Ejemplo: prod-packages-queue
locals {
  queues = {
    # Dominio: Packages - Cola para procesamiento de paquetes registrados
    packages_queue = {
      name                       = "packages-queue"
      delay_seconds              = 0
      max_message_size           = 262144  # 256 KB
      message_retention_seconds  = 345600  # 4 días
      receive_wait_time_seconds  = 10      # Long polling
      visibility_timeout_seconds = 60
      enable_dlq                 = true
      max_receive_count          = 3       # Reintentos antes de enviar a DLQ
    }

    # AGREGAR NUEVAS COLAS AQUÍ
    # mi_cola = {
    #   name                       = "mi-nueva-cola"
    #   delay_seconds              = 0
    #   max_message_size           = 262144
    #   message_retention_seconds  = 345600
    #   receive_wait_time_seconds  = 10
    #   visibility_timeout_seconds = 60
    #   enable_dlq                 = true
    #   max_receive_count          = 3
    # }
  }

  # Filtrar colas que tienen DLQ habilitada
  queues_with_dlq = {
    for key, queue in local.queues : key => queue
    if lookup(queue, "enable_dlq", false)
  }
}

# ============================================
# SQS QUEUES
# ============================================
resource "aws_sqs_queue" "queues" {
  for_each = local.queues

  name                       = "${var.environment}-${each.value.name}"
  delay_seconds              = each.value.delay_seconds
  max_message_size           = each.value.max_message_size
  message_retention_seconds  = each.value.message_retention_seconds
  receive_wait_time_seconds  = each.value.receive_wait_time_seconds
  visibility_timeout_seconds = each.value.visibility_timeout_seconds

  # Configurar DLQ si está habilitada
  redrive_policy = lookup(each.value, "enable_dlq", false) ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = each.value.max_receive_count
  }) : null

  tags = {
    Environment = var.environment
    Domain      = each.key
    ManagedBy   = "terraform"
  }

  depends_on = [aws_sqs_queue.dlq]
}

# ============================================
# DEAD LETTER QUEUES (DLQ)
# ============================================
resource "aws_sqs_queue" "dlq" {
  for_each = local.queues_with_dlq

  name                      = "${var.environment}-${each.value.name}-dlq"
  message_retention_seconds = 1209600 # 14 días para DLQ

  tags = {
    Environment = var.environment
    Domain      = each.key
    Type        = "DLQ"
    ManagedBy   = "terraform"
  }
}

# ============================================
# OUTPUTS
# ============================================
output "queue_urls" {
  description = "Mapa de URLs de todas las colas creadas"
  value = {
    for key, queue in aws_sqs_queue.queues : key => queue.url
  }
}

output "queue_arns" {
  description = "Mapa de ARNs de todas las colas creadas"
  value = {
    for key, queue in aws_sqs_queue.queues : key => queue.arn
  }
}

output "dlq_urls" {
  description = "Mapa de URLs de las Dead Letter Queues"
  value = {
    for key, queue in aws_sqs_queue.dlq : key => queue.url
  }
}

# Output individual para referencia rápida en el manifiesto K8s
output "packages_queue_url" {
  description = "URL de la cola de paquetes"
  value       = aws_sqs_queue.queues["packages_queue"].url
}

output "packages_queue_arn" {
  description = "ARN de la cola de paquetes"
  value       = aws_sqs_queue.queues["packages_queue"].arn
}
