########################################################
# 공통 태그 설정
########################################################
variable "common_tags" {
  type        = map(string)
  description = "Common tags to be applied to all resources"
  default = {
    name      = "advance_lab"
    createdby = "terraform"
  }
}

########################################################
# 1. 사용자 입력 변수 (USER_INPUT_VARIABLES)
#    사용자가 대화형으로 수정 가능한 필수 입력 항목
#    ceweb 애플리케이션과 Terraform에서 공통으로 사용하는 변수입니다.
#    master_config.json에서 요구하는 변수 중 일부가 포함됩니다.
#    이 파트에는 새로운 변수를 추가할 수 없습니다.
########################################################

variable "private_domain_name" {
  type        = string
  description = "[USER_INPUT] Private domain name (e.g., internal.local)"
  default     = "your_private_domain.name"
}


variable "public_domain_name" {
  type        = string
  description = "[USER_INPUT] Public domain name (e.g., example.com)"
  default     = "your_public_domain.name"
}

variable "keypair_name" {
  type        = string
  description = "[USER_INPUT] Key Pair to access VM"
  default     = "mykey"
}

variable "user_public_ip" {
  type        = string
  description = "[USER_INPUT] Public IP address of user PC"
  default     = "your_public_ip/32"
}

# Optional Object Storage variables (can be empty for basic 3-tier)
variable "object_storage_access_key_id" {
  type        = string
  description = "[USER_INPUT] Object Storage access key ID (optional)"
  default     = "put_your_authentificate_access_key_here"
}

variable "object_storage_secret_access_key" {
  type        = string
  description = "[USER_INPUT] Object Storage secret access key (optional)"
  default     = "put_your_authentificate_secret_key_here"
  sensitive   = true
}

variable "object_storage_bucket_string" {
  type        = string
  description = "[USER_INPUT] Object Storage bucket string (optional)"
  default     = "put_your_account_id_here"
}

########################################################
# 2. ceweb 애플리케이션 필수 변수 (CEWEB_REQUIRED_VARIABLES)
#    ceweb 애플리케이션과 Terraform에서 공통으로 사용하는 변수입니다.
#    master_config.json에서 요구하는 변수 중 일부가 포함됩니다.
#    이 파트에는 새로운 변수를 추가할 수 없습니다.
########################################################

# VM IP addresses
variable "bastion_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Private IP address of bastion VM"
  default     = "10.1.1.110"
}

variable "web_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Private IP address of web VM"
  default     = "10.1.1.111"
}

variable "app_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Private IP address of app VM"
  default     = "10.1.2.121"
}

variable "db_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Private IP address of db VM"
  default     = "10.1.3.131"
}

variable "web_lb_service_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Web load balancer service IP"
  default     = "10.1.1.100"
}

variable "app_lb_service_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] App load balancer service IP"
  default     = "10.1.2.100"
}

# Application configuration
variable "app_server_port" {
  type        = number
  description = "[CEWEB_REQUIRED] Port number for application server"
  default     = 3000
}

variable "database_port" {
  type        = number
  description = "[CEWEB_REQUIRED] Port number for database server"
  default     = 2866
}

variable "database_name" {
  type        = string
  description = "[CEWEB_REQUIRED] Database name"
  default     = "cedb"
}

variable "database_user" {
  type        = string
  description = "[CEWEB_REQUIRED] Database admin user"
  default     = "cedbadmin"
}

variable "database_password" {
  type        = string
  description = "[CEWEB_REQUIRED] Database admin password"
  default     = "cedbadmin123!"
  sensitive   = true
}

variable "database_host" {
  type        = string
  description = "[CEWEB_REQUIRED] Database server hostname (auto-generated from private_domain_name)"
  default     = ""  # Will be dynamically set in variables_manager.ps1
}

variable "nginx_port" {
  type        = number
  description = "[CEWEB_REQUIRED] Nginx web server port"
  default     = 80
}

variable "ssl_enabled" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable SSL for web server"
  default     = false
}

variable "git_repository" {
  type        = string
  description = "[CEWEB_REQUIRED] Git repository URL"
  default     = "https://github.com/SCPv2/ceweb.git"
}

variable "git_branch" {
  type        = string
  description = "[CEWEB_REQUIRED] Git branch name"
  default     = "main"
}

variable "timezone" {
  type        = string
  description = "[CEWEB_REQUIRED] System timezone"
  default     = "Asia/Seoul"
}

variable "company_name" {
  type        = string
  description = "[CEWEB_REQUIRED] Company name for application"
  default     = "Creative Energy"
}

variable "admin_email" {
  type        = string
  description = "[CEWEB_REQUIRED] Administrator email address"
  default     = "ars4mundus@gmail.com"
}

variable "node_env" {
  type        = string
  description = "[CEWEB_REQUIRED] Node.js environment (development/production)"
  default     = "production"
}

variable "session_secret" {
  type        = string
  description = "[CEWEB_REQUIRED] Session secret key"
  default     = "your-secret-key-change-in-production"
  sensitive   = true
}

variable "db_type" {
  type        = string
  description = "[CEWEB_REQUIRED] Database type"
  default     = "postgresql"
}

variable "db_max_connections" {
  type        = number
  description = "[CEWEB_REQUIRED] Maximum database connections"
  default     = 100
}

variable "backup_retention_days" {
  type        = number
  description = "[CEWEB_REQUIRED] Backup retention period in days"
  default     = 30
}

variable "auto_deployment" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable automatic deployment"
  default     = true
}

variable "rollback_enabled" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable rollback capability"
  default     = true
}

########################################################
# 3. Terraform 인프라 변수 (TERRAFORM_INFRASTRUCTURE_VARIABLES)
#    이 파트에는 새로운 변수를 추가할 수 있습니다.
#    단, 이 파트의 변수는 main.tf에서만 사용됩니다.
########################################################

# VPC 변수 정의
variable "vpcs" {
  description = "[TERRAFORM_INFRA] VPC for Creative Energy"
  type = list(object({
    name        = string
    cidr        = string
    description = optional(string)
  }))
  default = [
    {
      name        = "VPC1"
      cidr        = "10.1.0.0/16"
      description = "ceweb VPC"
    }
  ]
}

# Subnet 변수 정의
variable "subnets" {
  description = "[TERRAFORM_INFRA] Subnet for Creative Energy"
  type = list(object({
    name        = string
    cidr        = string
    type        = string                                  # GENERAL | LOCAL | VPC_ENDPOINT
    vpc_name    = string   
    description = string
  }))
  default = [
    {
      name        = "Subnet11"
      cidr        = "10.1.1.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "ceweb Subnet"
    },
    {
      name        = "Subnet12"
      cidr        = "10.1.2.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "ceapp Subnet"
    },
    {
      name        = "Subnet13"
      cidr        = "10.1.3.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "cedb Subnet"
    }
  ]
}

# Public IP 변수 정의
variable "public_ips" {
  type = list(object({
    name        = string
    description = string
  }))
  default = [
    { name = "PIP1", description = "[TERRAFORM_INFRA] Public IP for Bastion" },
    { name = "PIP2", description = "[TERRAFORM_INFRA] Public IP for Web Server" },
    { name = "PIP3", description = "[TERRAFORM_INFRA] Public IP for Web NAT" },
    { name = "PIP4", description = "[TERRAFORM_INFRA] Public IP for App NAT" },
    { name = "PIP5", description = "[TERRAFORM_INFRA] Public IP for DB NAT" }
  ]
}

# Security Group 변수 정의
variable "security_group_bastion" {
  type        = string
  description = "[TERRAFORM_INFRA] Bastion security group name"
  default     = "bastionSG"
}

variable "security_group_web" {
  type        = string
  description = "[TERRAFORM_INFRA] Web security group name"
  default     = "webSG"
}

variable "security_group_app" {
  type        = string
  description = "[TERRAFORM_INFRA] App security group name"
  default     = "appSG"
}

variable "security_group_db" {
  type        = string
  description = "[TERRAFORM_INFRA] DB security group name"
  default     = "dbSG"
}

# Virtual Server Standard Image 변수 정의
variable "windows_image_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Windows Server image ID"
  default     = "28d98f66-44ca-4858-904f-636d4f674a62"
}

variable "rocky_image_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Rocky Linux image ID"
  default     = "253a91ea-1221-49d7-af53-a45c389e7e1a"
}

variable "postgresql_engine_id" {
  type        = string
  description = "[TERRAFORM_INFRA] PostgreSQL engine version ID"
  default     = "postgresql-engine-not-found"
}

# Virtual Server 변수 정의
variable "server_type_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Server type ID (instance type)"
  default     = "s1v1m2"
}

variable "vm_bastion" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "bastionvm110w"
    description = "bastion VM"
  }
}

variable "vm_web" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "webvm111r"
    description = "web VM1"
  }
}

variable "vm_app" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "appvm121r"
    description = "app VM1"
  }
}

variable "vm_db" {
  type = object({
    name = string
    description = string
  })
  default = {
    name = "dbvm131r"
    description = "db VM"
  }
}

variable "boot_volume_windows" {
  type = object({
    size                  = number
    type                  = optional(string)
    delete_on_termination = optional(bool)
  })
  default = {
    size                  = 32
    type                  = "SSD"
    delete_on_termination = true
  }
}

variable "boot_volume_rocky" {
  type = object({
    size                  = number
    type                  = optional(string)
    delete_on_termination = optional(bool)
  })
  default = {
    size                  = 16
    type                  = "SSD"
    delete_on_termination = true
  }
}

# Derived variables for master_config.json template
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR for template usage"
  default     = "10.1.0.0/16"
}

variable "web_subnet_cidr" {
  type        = string
  description = "Web subnet CIDR for template usage"
  default     = "10.1.1.0/24"
}

variable "app_subnet_cidr" {
  type        = string
  description = "App subnet CIDR for template usage"
  default     = "10.1.2.0/24"
}

variable "db_subnet_cidr" {
  type        = string
  description = "DB subnet CIDR for template usage"
  default     = "10.1.3.0/24"
}




















