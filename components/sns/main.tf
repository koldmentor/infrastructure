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
# DEFINIR TOPICS EN UN SOLO LUGAR
# ============================================
# Para agregar un nuevo topic, simplemente agregue una entrada al mapa.
# El nombre final será: {environment}-{nombre_del_topic}
# Ejemplo: prod-package-events
locals {
  topics = {
    # Dominio: Packages - Eventos de paquetes (creación, cambio de estado)
    package_events = {
      name         = "package-events"
      display_name = "Package Events Topic"
    }

    # Dominio: Notifications - Notificaciones al cliente (email, sms, push)
    notifications = {
      name         = "notifications"
      display_name = "Notifications Topic"
    }

    # AGREGAR NUEVOS TOPICS AQUÍ
    # ejemplo = {
    #   name         = "mi-nuevo-topic"
    #   display_name = "Descripción del topic"
    # }
  }
}

# ============================================
# SNS TOPICS
# ============================================
resource "aws_sns_topic" "topics" {
  for_each = local.topics

  name         = "${var.environment}-${each.value.name}"
  display_name = each.value.display_name

  tags = {
    Environment = var.environment
    Domain      = each.key
    ManagedBy   = "terraform"
  }
}

# ============================================
# OUTPUTS
# ============================================
output "topic_arns" {
  description = "Mapa de ARNs de todos los topics creados"
  value = {
    for key, topic in aws_sns_topic.topics : key => topic.arn
  }
}

output "topic_names" {
  description = "Mapa de nombres de todos los topics creados"
  value = {
    for key, topic in aws_sns_topic.topics : key => topic.name
  }
}

# Outputs individuales para referencia rápida en el manifiesto K8s
output "package_events_arn" {
  description = "ARN del topic de eventos de paquetes"
  value       = aws_sns_topic.topics["package_events"].arn
}

output "notifications_arn" {
  description = "ARN del topic de notificaciones"
  value       = aws_sns_topic.topics["notifications"].arn
}
