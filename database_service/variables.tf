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
# 사용자가 대화형으로 수정 가능한 필수 입력 항목
########################################################

variable "private_domain_name" {
  type        = string
  description = "[USER_INPUT] Private domain name (e.g., internal.local)"
  default     = ""
}

variable "private_hosted_zone_id" {
  type        = string
  description = "[USER_INPUT] Private Hosted Zone ID for domain"
  default     = ""
}

variable "public_domain_name" {
  type        = string
  description = "[USER_INPUT] Public domain name (e.g., example.com)"
  default     = ""
}

variable "keypair_name" {
  type        = string
  description = "[USER_INPUT] Key Pair to access VM"
  default     = "mykey"
}

variable "user_public_ip" {
  type        = string
  description = "[USER_INPUT] Public IP address of user PC"
  default     = ""
}

variable "object_storage_access_key_id" {
  type        = string
  description = "[USER_INPUT] Object Storage access key ID"
  default     = ""
}

variable "object_storage_secret_access_key" {
  type        = string
  description = "[USER_INPUT] Object Storage secret access key"
  default     = ""
}

variable "object_storage_bucket_string" {
  type        = string
  description = "[USER_INPUT] Object Storage bucket string"
  default     = ""
}


########################################################
# 2. ceweb 애플리케이션 필수 변수 (CEWEB_REQUIRED_VARIABLES)
# ceweb 애플리케이션이 master_config.json에서 요구하는 변수들
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
  default     = "creative_energy_db"
}

variable "database_user" {
  type        = string
  description = "[CEWEB_REQUIRED] Database admin user"
  default     = "ceadmin"
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

variable "object_storage_bucket_name" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage bucket name"
  default     = "ceweb"
}

variable "object_storage_region" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage region"
  default     = "kr-west1"
}

variable "certificate_path" {
  type        = string
  description = "[CEWEB_REQUIRED] SSL certificate path"
  default     = "/etc/ssl/certs/certificate.crt"
}

variable "private_key_path" {
  type        = string
  description = "[CEWEB_REQUIRED] SSL private key path"
  default     = "/etc/ssl/private/private.key"
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

# 추가 필수 ceweb 변수들 (load_master_config.sh에서 요구)
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

variable "object_storage_private_endpoint" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage private endpoint"
  default     = "https://object-store.private.kr-west1.e.samsungsdscloud.com"
}

variable "object_storage_public_endpoint" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage public endpoint"
  default     = "https://object-store.kr-west1.e.samsungsdscloud.com"
}

variable "object_storage_media_folder" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage media folder"
  default     = "media/img"
}

variable "object_storage_audition_folder" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage audition folder"
  default     = "files/audition"
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
  default     = "revotty@ars4mundus@gmail.com"
}

########################################################
# 3. Terraform 인프라 변수 (TERRAFORM_INFRASTRUCTURE_VARIABLES)
# Terraform 리소스 생성에만 필요한 변수들
########################################################

variable "bastion_ip" {
  type        = string
  description = "Private IP address of bastion VM [TERRAFORM_INFRA]"
  default     = "10.1.1.110"
}

variable "web_ip" {
  type        = string
  description = "Private IP address of web VM [TERRAFORM_INFRA]"
  default     = "10.1.1.111"
}

variable "app_ip" {
  type        = string
  description = "Private IP address of app VM [TERRAFORM_INFRA]"
  default     = "10.1.2.121"
}

variable "web_ip2" {
  type        = string
  description = "Private IP address of web VM2 [TERRAFORM_INFRA]"
  default     = "10.1.1.112"
}

variable "app_ip2" {
  type        = string
  description = "Private IP address of app VM2 [TERRAFORM_INFRA]"
  default     = "10.1.2.122"
}

variable "db_ip" {
  type        = string
  description = "Private IP address of db VM [TERRAFORM_INFRA]"
  default     = "10.1.3.131"
}

variable "vpcs" {
  description = "VPC for Creative Energy [TERRAFORM_INFRA]"
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

variable "subnets" {
  description = "Subnet for Creative Energy [TERRAFORM_INFRA]"
  type = list(object({
    name        = string
    cidr        = string
    type        = string
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
      description = "bbweb Subnet"
    },
    {
      name        = "Subnet13"
      cidr        = "10.1.3.0/24"
      type        = "GENERAL"
      vpc_name    = "VPC1"
      description = "bbweb Subnet"
    }
  ]
}

variable "public_ips" {
  type = list(object({
    name        = string
    description = string
  }))
  description = "Public IP configuration [TERRAFORM_INFRA]"
  default = [
    { name = "PIP1", description = "Public IP for VM" },
    { name = "PIP2", description = "Public IP for VM" },
    { name = "PIP3", description = "Public IP for VM" },
    { name = "PIP4", description = "Public IP for VM" }
  ]
}

variable "security_group_bastion" {
  type        = string
  description = "Security group name for bastion [TERRAFORM_INFRA]"
  default     = "bastionSG"
}

variable "security_group_web" {
  type        = string
  description = "Security group name for web [TERRAFORM_INFRA]"
  default     = "webSG"
}

variable "security_group_app" {
  type        = string
  description = "Security group name for app [TERRAFORM_INFRA]"
  default     = "appSG"
}

variable "security_group_db" {
  type        = string
  description = "Security group name for db [TERRAFORM_INFRA]"
  default     = "dbSG"
}

variable "image_windows_os_distro" {
  type        = string
  description = "Windows OS distribution [TERRAFORM_INFRA]"
  default     = "windows"
}

variable "image_windows_scp_os_version" {
  type        = string
  description = "Windows SCP OS version [TERRAFORM_INFRA]"
  default     = "2022 Std."
}

variable "image_rocky_os_distro" {
  type        = string
  description = "Rocky OS distribution [TERRAFORM_INFRA]"
  default     = "rocky"
}

variable "image_rocky_scp_os_version" {
  type        = string
  description = "Rocky SCP OS version [TERRAFORM_INFRA]"
  default     = "9.4"
}

variable "server_type_id" {
  type        = string
  description = "Server type ID [TERRAFORM_INFRA]"
  default     = "s1v1m2"
}

variable "vm_bastion" {
  type = object({
    name        = string
    description = string
  })
  description = "Bastion VM configuration [TERRAFORM_INFRA]"
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
  description = "Web VM configuration [TERRAFORM_INFRA]"
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
  description = "Web VM2 configuration [TERRAFORM_INFRA]"
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
  description = "App VM configuration [TERRAFORM_INFRA]"
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
  description = "App VM2 configuration [TERRAFORM_INFRA]"
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
  description = "DB VM configuration [TERRAFORM_INFRA]"
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
  description = "Windows boot volume configuration [TERRAFORM_INFRA]"
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
  description = "Rocky boot volume configuration [TERRAFORM_INFRA]"
  default = {
    size                  = 16
    type                  = "SSD"
    delete_on_termination = true
  }
}