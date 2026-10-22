variable "aws_region" {
  description = "Região AWS usada pelo Learner Lab."
  type        = string
  default     = "us-west-2"
}

variable "newrelic_account_id" {
  description = "Account ID usado para publicar eventos customizados de telemetria do RDS."
  type        = number
  default     = 0
}

variable "newrelic_license_key" {
  description = "License/Ingest key do New Relic. Fornecida como variável sensível no HCP Terraform."
  type        = string
  sensitive   = true
  default     = ""
}

variable "newrelic_region" {
  description = "Região da conta New Relic."
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU"], var.newrelic_region)
    error_message = "newrelic_region deve ser US ou EU."
  }
}

variable "rds_newrelic_telemetry_enabled" {
  description = "Cria a Lambda agendada que publica métricas e contagens sanitizadas do RDS no New Relic."
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Prefixo dos recursos."
  type        = string
  default     = "oficina"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name deve usar letras minúsculas, números ou hífen."
  }
}

variable "environment" {
  description = "Ambiente lógico associado à branch e ao workspace HCP Terraform."
  type        = string
  default     = "homolog"

  validation {
    condition     = contains(["homolog", "production"], var.environment)
    error_message = "environment deve ser homolog ou production."
  }
}

variable "vpc_id" {
  description = "ID da VPC criada pelo repositório Kubernetes."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id deve ser um ID de VPC válido."
  }
}

variable "private_subnet_ids" {
  description = "Subnets privadas, em ao menos duas zonas, criadas pelo repositório Kubernetes."
  type        = list(string)

  validation {
    condition = (
      length(var.private_subnet_ids) >= 2 &&
      length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids) &&
      alltrue([for id in var.private_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    )
    error_message = "Informe ao menos duas subnets privadas válidas e distintas."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups autorizados a acessar o PostgreSQL, inicialmente o SG do EKS."
  type        = set(string)

  validation {
    condition = (
      length(var.allowed_security_group_ids) >= 1 &&
      alltrue([for id in var.allowed_security_group_ids : can(regex("^sg-[0-9a-f]+$", id))])
    )
    error_message = "Informe ao menos um security group válido."
  }
}

variable "db_name" {
  description = "Nome do banco inicial."
  type        = string
  default     = "oficina"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_name))
    error_message = "db_name deve começar com letra e conter somente letras, números ou underscore."
  }
}

variable "db_username" {
  description = "Usuário master do PostgreSQL."
  type        = string
  default     = "oficina_admin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_username))
    error_message = "db_username deve começar com letra e conter somente letras, números ou underscore."
  }
}

variable "db_password" {
  description = "Senha master fornecida como variável sensível no HCP Terraform."
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.db_password) >= 16 &&
      length(var.db_password) <= 128 &&
      can(regex("^[!-~]+$", var.db_password)) &&
      !can(regex("[/@\"]", var.db_password))
    )
    error_message = "db_password deve possuir entre 16 e 128 caracteres ASCII imprimíveis e não pode conter barra, arroba, aspas ou espaço."
  }
}

variable "db_engine_version" {
  description = "Versão principal do PostgreSQL aceita no AWS Academy."
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "Classe da instância RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento inicial em GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage deve ser pelo menos 20 GiB para gp3."
  }
}

variable "db_max_allocated_storage" {
  description = "Limite do autoscaling de armazenamento em GiB."
  type        = number
  default     = 40
}

variable "multi_az" {
  description = "Ativa réplica Multi-AZ. O perfil production define true; homologação e override acadêmico usam false."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Retenção de backups automáticos."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days deve estar entre 1 e 35."
  }
}

variable "deletion_protection" {
  description = "Proteção contra exclusão. O perfil production define true."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Controla a criação do snapshot final. O perfil production define false."
  type        = bool
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Logs do PostgreSQL exportados para o CloudWatch Logs. Use [] para desligar completamente."
  type        = list(string)
  default     = ["postgresql"]

  validation {
    condition = (
      length(distinct(var.enabled_cloudwatch_logs_exports)) == length(var.enabled_cloudwatch_logs_exports) &&
      alltrue([for log in var.enabled_cloudwatch_logs_exports : contains(["postgresql", "upgrade"], log)])
    )
    error_message = "enabled_cloudwatch_logs_exports aceita somente os valores distintos postgresql e upgrade."
  }
}

variable "manage_cloudwatch_log_groups" {
  description = "Cria os log groups pelo Terraform para aplicar retenção e limitar custo do CloudWatch."
  type        = bool
  default     = true
}

variable "cloudwatch_logs_retention_days" {
  description = "Retenção dos logs do banco no CloudWatch Logs."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.cloudwatch_logs_retention_days)
    error_message = "cloudwatch_logs_retention_days deve ser um valor de retenção aceito pelo CloudWatch Logs."
  }
}

variable "log_connections" {
  description = "Registra conexões. Mantido ativo para evidenciar acesso do EKS e da Lambda."
  type        = bool
  default     = true
}

variable "log_disconnections" {
  description = "Registra desconexões, complementando a evidência de conectividade."
  type        = bool
  default     = true
}

variable "log_min_duration_statement_ms" {
  description = "Duração mínima, em milissegundos, para registrar consultas lentas. Use -1 para desativar."
  type        = number
  default     = 1000

  validation {
    condition     = var.log_min_duration_statement_ms >= -1
    error_message = "log_min_duration_statement_ms deve ser -1 ou um valor maior ou igual a zero."
  }
}

variable "log_statement" {
  description = "Escopo de SQL registrado. Mantido em ddl para não gravar dados pessoais no log."
  type        = string
  default     = "ddl"

  validation {
    condition     = contains(["none", "ddl", "mod", "all"], var.log_statement)
    error_message = "log_statement deve ser none, ddl, mod ou all."
  }
}

variable "performance_insights_enabled" {
  description = "Ativa o Performance Insights. Desligado por padrão para controlar custo no AWS Academy."
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Retenção do Performance Insights em dias. Somente 7 permanece na camada gratuita."
  type        = number
  default     = 7

  validation {
    condition     = var.performance_insights_retention_period == 7 || var.performance_insights_retention_period == 731 || (var.performance_insights_retention_period % 31 == 0 && var.performance_insights_retention_period <= 713)
    error_message = "performance_insights_retention_period deve ser 7, 731 ou múltiplo de 31 até 713."
  }
}

variable "monitoring_interval" {
  description = "Intervalo do Enhanced Monitoring em segundos. Exige monitoring_role_arn existente."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval deve ser 0, 1, 5, 10, 15, 30 ou 60."
  }
}

variable "monitoring_role_arn" {
  description = "ARN de role já existente para Enhanced Monitoring. Nulo no AWS Academy, onde não criamos roles IAM."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.monitoring_role_arn == null || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.monitoring_role_arn))
    error_message = "monitoring_role_arn deve ser nulo ou um ARN de role IAM válido."
  }
}

variable "final_snapshot_identifier" {
  description = "Nome do snapshot final quando skip_final_snapshot for false."
  type        = string
  default     = null
  nullable    = true
}
