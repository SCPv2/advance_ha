########################################################
# 공통 태그 설정
########################################################
variable "common_tags" {
  type        = map(string)
  description = "[TERRAFORM_INFRA] Common tags to be applied to all resources"
  default = {
    name      = "advance_lab"
    createdby = "terraform"
  }
}

########################################################
# 수강자 입력 항목
########################################################

variable "private_domain_name" {
  type        = string
  description = "[USER_INPUT] Private domain name (e.g., internal.local)"
  default     = "your_private_domain.name" # 사용자 Private 도메인으로 변경
}


variable "public_domain_name" {
  type        = string
  description = "[USER_INPUT] Public domain name (e.g., example.com)"
  default     = "your_public_domain.name" # 사용자 Public 도메인으로 변경
}


# Object Storage 변수들은 기본 3-tier 아키텍처에서 불필요하여 제거
# Three Tier Object 아키텍처(_obj 파일)를 사용할 경우에만 별도 구성 필요



variable "keypair_name" {
  type        = string
  description = "[USER_INPUT] Key Pair to access VM"
  default     = "mykey" # 기존 Key Pair 이름으로 변경
}

variable "user_public_ip" {
  type        = string
  description = "[USER_INPUT] Public IP address of user PC"
  default     = "your_public_ip/32" # 수강자 PC의 Public IP 주소 입력
}

########################################################
# File Storage 관련 변수
########################################################

variable "file_storage_mount_path" {
  type        = string
  description = "[CEWEB_REQUIRED] File storage mount path for shared files"
  default     = "/mnt/shared"
}

variable "file_storage_capacity" {
  type        = number
  description = "[CEWEB_REQUIRED] File storage capacity in GB"
  default     = 100
}

variable "file_storage_protocol" {
  type        = string
  description = "[CEWEB_REQUIRED] File storage protocol (NFS/CIFS)"
  default     = "NFS"
}

variable "file_storage_backup_enabled" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable automatic backup for file storage"
  default     = true
}

########################################################
# CEWEB 애플리케이션 필수 변수 (CEWEB_REQUIRED_VARIABLES)
# ceweb 애플리케이션과 Terraform에서 공통으로 사용하는 변수입니다.
########################################################

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
}

variable "database_host" {
  type        = string
  description = "[CEWEB_REQUIRED] Database server hostname"
  default     = "10.1.3.131" # File storage uses VM-based DB
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

variable "node_env" {
  type        = string
  description = "[CEWEB_REQUIRED] Node.js environment"
  default     = "production"
}

variable "session_secret" {
  type        = string
  description = "[CEWEB_REQUIRED] Application session secret"
  default     = "your-secret-key-change-in-production"
}

variable "db_type" {
  type        = string
  description = "[CEWEB_REQUIRED] Database type"
  default     = "postgresql"
}

variable "db_max_connections" {
  type        = number
  description = "[CEWEB_REQUIRED] Database max connections"
  default     = 100
}

variable "auto_deployment" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable auto deployment"
  default     = true
}

variable "rollback_enabled" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable rollback"
  default     = true
}

variable "backup_retention_days" {
  type        = number
  description = "[CEWEB_REQUIRED] Backup retention days"
  default     = 30
}

variable "company_name" {
  type        = string
  description = "[CEWEB_REQUIRED] Company name"
  default     = "Creative Energy"
}

variable "admin_email" {
  type        = string
  description = "[CEWEB_REQUIRED] Administrator email"
  default     = "ars4mundus@gmail.com"
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
  description = "[CEWEB_REQUIRED] Private IP address of database VM"
  default     = "10.1.3.131"
}

########################################################
# Terraform 인프라 변수 (TERRAFORM_INFRASTRUCTURE_VARIABLES)
# Terraform 리소스 생성에만 필요한 변수들
########################################################

variable "bastion_ip" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of bastion VM"
  default     = "10.1.1.110"
}

variable "web_ip2" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of web VM2"
  default     = "10.1.1.112"
}

variable "app_ip2" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of app VM2"
  default     = "10.1.2.122"
}

variable "db_ip2" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of db VM2 (standby)"
  default     = "10.1.3.33"
}

# VPC Configuration Variables
variable "vpc_name" {
  type        = string
  description = "VPC name [TERRAFORM_INFRA]"
  default     = "VPC1"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block [TERRAFORM_INFRA]"
  default     = "10.1.0.0/16"
}

variable "vpc_description" {
  type        = string
  description = "VPC description [TERRAFORM_INFRA]"
  default     = "ceweb VPC"
}

# Subnet Configuration Variables
variable "web_subnet_name" {
  type        = string
  description = "Web subnet name [TERRAFORM_INFRA]"
  default     = "Subnet11"
}

variable "web_subnet_cidr" {
  type        = string
  description = "Web subnet CIDR block [TERRAFORM_INFRA]"
  default     = "10.1.1.0/24"
}

variable "app_subnet_name" {
  type        = string
  description = "App subnet name [TERRAFORM_INFRA]"
  default     = "Subnet12"
}

variable "app_subnet_cidr" {
  type        = string
  description = "App subnet CIDR block [TERRAFORM_INFRA]"
  default     = "10.1.2.0/24"
}

variable "db_subnet_name" {
  type        = string
  description = "DB subnet name [TERRAFORM_INFRA]"
  default     = "Subnet13"
}

variable "db_subnet_cidr" {
  type        = string
  description = "DB subnet CIDR block [TERRAFORM_INFRA]"
  default     = "10.1.3.0/24"
}

variable "subnet_type" {
  type        = string
  description = "Subnet type [TERRAFORM_INFRA]"
  default     = "GENERAL"
}

########################################################
# VPC 변수 정의 (기존 list 형태 유지)
########################################################
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

########################################################
# Subnet 변수 정의
########################################################
variable "subnets" {
  description = "[TERRAFORM_INFRA] Subnet for Creative Energy"
  type = list(object({
    name        = string
    cidr        = string
    type        = string # GENERAL | LOCAL | VPC_ENDPOINT
    vpc_name    = string
    description = string
  }))
  default = [
    {
      name        = "Subnet11"
      cidr        = "10.1.1.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "Web Subnet"
    },
    {
      name        = "Subnet12"
      cidr        = "10.1.2.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "App Subnet"
    },
    {
      name        = "Subnet13"
      cidr        = "10.1.3.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "DB Subnet"
    }
  ]
}

# Public IP Configuration Variables
variable "pip1_name" {
  type        = string
  description = "Public IP 1 name [TERRAFORM_INFRA]"
  default     = "PIP1"
}

variable "pip2_name" {
  type        = string
  description = "Public IP 2 name [TERRAFORM_INFRA]"
  default     = "PIP2"
}

variable "pip3_name" {
  type        = string
  description = "Public IP 3 name [TERRAFORM_INFRA]"
  default     = "PIP3"
}

variable "public_ip_description" {
  type        = string
  description = "Public IP description [TERRAFORM_INFRA]"
  default     = "Public IP for VM"
}

########################################################
# Public IP 변수 정의 (기존 list 형태 유지)
########################################################

variable "public_ips" {
  type = list(object({
    name        = string
    description = string
  }))
  description = "[TERRAFORM_INFRA] Public IP configurations"
  default = [
    { name = "PIP1", description = "Public IP for VM" },
    { name = "PIP2", description = "Public IP for VM" },
    { name = "PIP3", description = "Public IP for VM" },
    { name = "PIP4", description = "Public IP for VM" },
    { name = "PIP5", description = "Public IP for VM" }
  ]
}

########################################################
# Security Group 변수 정의
########################################################
variable "security_group_bastion" {
  type        = string
  description = "[TERRAFORM_INFRA] Security group name for bastion host"
  default     = "bastionSG"
}

variable "security_group_web" {
  type        = string
  description = "[TERRAFORM_INFRA] Security group name for web servers"
  default     = "webSG"
}

variable "security_group_app" {
  type        = string
  description = "[TERRAFORM_INFRA] Security group name for app servers"
  default     = "appSG"
}

variable "security_group_db" {
  type        = string
  description = "[TERRAFORM_INFRA] Security group name for database servers"
  default     = "dbSG"
}

########################################################
# Virtual Server Standard Image 변수 정의
########################################################
variable "image_windows_os_distro" {
  type        = string
  description = "[TERRAFORM_INFRA] Windows OS distribution"
  default     = "windows"
}

variable "image_windows_scp_os_version" {
  type        = string
  description = "[TERRAFORM_INFRA] Windows SCP OS version"
  default     = "2022 Std."
}

variable "image_rocky_os_distro" {
  type        = string
  description = "[TERRAFORM_INFRA] Rocky Linux OS distribution"
  default     = "rocky"
}

variable "image_rocky_scp_os_version" {
  type        = string
  description = "[TERRAFORM_INFRA] Rocky Linux SCP OS version"
  default     = "9.4"
}
# Image and Engine IDs (Auto-generated from SCP CLI)
variable "postgresql_engine_id" {
  type        = string
  description = "PostgreSQL engine version ID [TERRAFORM_INFRA]"
  default     = "feebbfb2e7164b83a9855cacd0b64fde"
}

########################################################
# Virtual Server 변수 정의
########################################################

variable "server_type_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Server type ID for virtual machines"
  default     = "s2v1m2"
}

variable "vm_bastion" {
  type = object({
    name        = string
    description = string
  })
  description = "[TERRAFORM_INFRA] Bastion VM configuration"
  default = {
    name        = "bastionvm110w"
    description = "bastion VM"
  }
}

variable "vm_web" {
  type = object({
    name        = string
    description = string
  })
  description = "[TERRAFORM_INFRA] Web VM1 configuration"
  default = {
    name        = "webvm111r"
    description = "web VM1"
  }
}

variable "vm_web2" {
  type = object({
    name        = string
    description = string
  })
  description = "[TERRAFORM_INFRA] Web VM2 configuration"
  default = {
    name        = "webvm112r"
    description = "web VM2"
  }
}

variable "vm_app" {
  type = object({
    name        = string
    description = string
  })
  description = "[TERRAFORM_INFRA] App VM1 configuration"
  default = {
    name        = "appvm121r"
    description = "app VM1"
  }
}

variable "vm_app2" {
  type = object({
    name        = string
    description = string
  })
  description = "[TERRAFORM_INFRA] App VM2 configuration"
  default = {
    name        = "appvm122r"
    description = "app VM2"
  }
}

variable "vm_db" {
  type = object({
    name        = string
    description = string
  })
  description = "[TERRAFORM_INFRA] Database VM configuration"
  default = {
    name        = "dbvm131r"
    description = "db VM"
  }
}

variable "boot_volume_windows" {
  type = object({
    size                  = number
    type                  = optional(string)
    delete_on_termination = optional(bool)
  })
  description = "[TERRAFORM_INFRA] Boot volume configuration for Windows VMs"
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
  description = "[TERRAFORM_INFRA] Boot volume configuration for Rocky Linux VMs"
  default = {
    size                  = 16
    type                  = "SSD"
    delete_on_termination = true
  }
}

########################################################
# Load Balancer 변수 정의
########################################################
variable "web_lb_service_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Service IP for Web Load Balancer"
  default     = "10.1.1.100"
}

variable "app_lb_service_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Service IP for App Load Balancer"
  default     = "10.1.2.100"
}




















































