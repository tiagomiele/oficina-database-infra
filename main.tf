locals {
  name = "${var.project_name}-${var.environment}"

  db_identifier = "${local.name}-db"

  # RDS publica cada log habilitado em um log group próprio e previsível.
  managed_log_groups = var.manage_cloudwatch_log_groups ? toset(var.enabled_cloudwatch_logs_exports) : toset([])
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${local.name}-db-subnets"
  }
}

resource "aws_security_group" "database" {
  name        = "${local.name}-database-sg"
  description = "PostgreSQL access restricted to authorized application security groups"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids

    content {
      description     = "PostgreSQL from ${ingress.value}"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  tags = {
    Name = "${local.name}-database-sg"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name}-postgres16"
  family = "postgres16"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Conexões e desconexões são registradas de propósito: sustentam a evidência de
  # que a aplicação no EKS e a Lambda de login realmente alcançaram o banco.
  parameter {
    name  = "log_connections"
    value = var.log_connections ? "1" : "0"
  }

  parameter {
    name  = "log_disconnections"
    value = var.log_disconnections ? "1" : "0"
  }

  # Somente consultas lentas são registradas, para diagnóstico de índices.
  parameter {
    name  = "log_min_duration_statement"
    value = tostring(var.log_min_duration_statement_ms)
  }

  # Evita despejar o SQL completo de toda transação no CloudWatch.
  parameter {
    name  = "log_statement"
    value = var.log_statement
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  # Parâmetros de bind ficam truncados em zero caractere, de modo que documentos,
  # e-mails e telefones dos clientes nunca chegam ao log.
  parameter {
    name  = "log_parameter_max_length"
    value = "0"
  }

  parameter {
    name  = "log_parameter_max_length_on_error"
    value = "0"
  }

  tags = {
    Name = "${local.name}-postgres16"
  }
}

# Log group gerenciado apenas para limitar a retenção e o custo do CloudWatch.
# Quando desabilitado, o RDS cria o log group com retenção "Never expire".
resource "aws_cloudwatch_log_group" "database" {
  for_each = local.managed_log_groups

  name              = "/aws/rds/instance/${local.db_identifier}/${each.value}"
  retention_in_days = var.cloudwatch_logs_retention_days

  tags = {
    Name = "${local.name}-${each.value}-logs"
  }
}

resource "aws_db_instance" "main" {
  identifier = local.db_identifier

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  publicly_accessible       = false
  multi_az                  = var.multi_az
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  auto_minor_version_upgrade = true
  apply_immediately          = true
  copy_tags_to_snapshot      = true
  delete_automated_backups   = true

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Performance Insights fica desligado por padrão: no Learner Lab ele consome
  # cota sem ser necessário para as evidências exigidas.
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Enhanced Monitoring exigiria uma role IAM dedicada, o que não é permitido no
  # AWS Academy. Permanece desligado a menos que uma role existente seja informada.
  monitoring_interval = var.monitoring_role_arn == null ? 0 : var.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn

  depends_on = [aws_cloudwatch_log_group.database]

  lifecycle {
    precondition {
      condition     = var.db_max_allocated_storage >= var.db_allocated_storage
      error_message = "db_max_allocated_storage deve ser maior ou igual a db_allocated_storage."
    }

    precondition {
      condition     = var.skip_final_snapshot || var.final_snapshot_identifier != null
      error_message = "final_snapshot_identifier é obrigatório quando skip_final_snapshot for false."
    }

    precondition {
      condition     = var.monitoring_interval == 0 || var.monitoring_role_arn != null
      error_message = "monitoring_interval maior que zero exige monitoring_role_arn de uma role já existente."
    }
  }

  tags = {
    Name = "${local.name}-db"
  }
}
