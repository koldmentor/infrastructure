# =============================================================================
# Component: RDS MySQL - Diplomado Grupo 1A
# =============================================================================
# Crea una instancia RDS MySQL con la base de datos DBMySQLGrupo1a y todas
# las tablas del sistema de última milla.
#
# Depende de:
#   - vpc: vpc_id, public_subnet_ids
#
# Outputs necesarios para aplicaciones:
#   - db_endpoint, db_port, db_name
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
      Project     = "grupo1a"
      Environment = var.environment
      Component   = "rds"
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

variable "vpc_id" {
  description = "ID de la VPC — output del componente vpc"
  type        = string
  default     = "vpc-049ae53c681eb0582"
}

variable "public_subnet_ids" {
  description = "IDs de subnets públicas — output del componente vpc"
  type        = list(string)
  default     = ["subnet-0caa27a6a42427a4c", "subnet-0c13a679cb46358ad"]
}

variable "private_subnet_ids" {
  description = "IDs de subnets privadas — necesarias para mantener compatibilidad con el subnet group existente"
  type        = list(string)
  default     = ["subnet-0f81538068635fb98", "subnet-076f9a301bc4ac898"]
}

variable "my_ip" {
  description = "Tu IP pública para acceso directo a la BD (formato CIDR, ej: 190.x.x.x/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC para permitir acceso desde la red interna"
  type        = string
  default     = "10.11.0.0/16"
}

variable "db_instance_class" {
  description = "Clase de instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Almacenamiento asignado en GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Versión del motor MySQL"
  type        = string
  default     = "8.0"
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "DBMySQLGrupo1a"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos"
  type        = string
  default     = "admin_grupo1a"
}

variable "db_password" {
  description = "Contraseña del usuario administrador (pasar via -var o TF_VAR_db_password)"
  type        = string
  sensitive   = true
  default     = "Grupo1a_2024!"
}

variable "db_multi_az" {
  description = "Habilitar Multi-AZ para alta disponibilidad"
  type        = bool
  default     = false
}

variable "db_backup_retention" {
  description = "Días de retención de backups automáticos"
  type        = number
  default     = 1
}

variable "db_skip_final_snapshot" {
  description = "Omitir snapshot final al destruir la instancia"
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
  db_identifier = "rds-mysql-grupo1a-${var.environment}"
}

# -----------------------------------------------------------------------------
# Security Group para RDS
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${local.db_identifier}-sg"
  description = "Security group para RDS MySQL - Grupo 1A"
  vpc_id      = var.vpc_id

  # Permitir tráfico MySQL desde la VPC
  ingress {
    description = "MySQL desde VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Permitir tráfico MySQL desde tu IP pública
  ingress {
    description = "MySQL desde mi PC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Egress abierto
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.db_identifier}-sg"
  })
}

# -----------------------------------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${local.db_identifier}-public-subnet-group"
  subnet_ids = var.public_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.db_identifier}-public-subnet-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# DB Parameter Group (MySQL 8.0 con charset utf8mb4)
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name   = "${local.db_identifier}-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = merge(var.tags, {
    Name = "${local.db_identifier}-params"
  })
}

# -----------------------------------------------------------------------------
# RDS MySQL Instance
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = local.db_identifier

  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az            = var.db_multi_az
  publicly_accessible = true

  backup_retention_period = var.db_backup_retention
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"

  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.db_identifier}-final-snapshot"

  deletion_protection = false

  tags = merge(var.tags, {
    Name = local.db_identifier
  })
}

# -----------------------------------------------------------------------------
# Inicialización del esquema
# -----------------------------------------------------------------------------
# La instancia RDS es accesible públicamente. Puedes conectarte directamente
# desde tu máquina local:
#
#   mysql -h <db_address> -u admin_grupo1a -p'Grupo1a_2024!' DBMySQLGrupo1a
#
# O ejecutar el script SQL directamente:
#
#   mysql -h <db_address> -u admin_grupo1a -p'Grupo1a_2024!' DBMySQLGrupo1a \
#     < ../../SQL/init_schema.sql
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "db_instance_id" {
  description = "ID de la instancia RDS"
  value       = aws_db_instance.main.id
}

output "db_endpoint" {
  description = "Endpoint de conexión (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "Hostname de la instancia RDS"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Puerto de la instancia RDS"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Usuario administrador"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_security_group_id" {
  description = "ID del Security Group de RDS — útil para otros componentes que necesiten acceso"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Nombre del DB Subnet Group"
  value       = aws_db_subnet_group.main.name
}

output "db_arn" {
  description = "ARN de la instancia RDS"
  value       = aws_db_instance.main.arn
}
