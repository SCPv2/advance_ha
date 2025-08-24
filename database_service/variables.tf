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
  default     = "ceservice.net"
}

variable "private_hosted_zone_id" {
  type        = string
  description = "[USER_INPUT] Private Hosted Zone ID for domain"
  default     = "975bba7b0f0b4359af97519e8bcff842"
}

variable "public_domain_name" {
  type        = string
  description = "[USER_INPUT] Public domain name (e.g., example.com)"
  default     = "creative-energy.net"
}

variable "keypair_name" {
  type        = string
  description = "[USER_INPUT] Key Pair to access VM"
  default     = "stkey"
}

variable "user_public_ip" {
  type        = string
  description = "[USER_INPUT] Public IP address of user PC"
  default     = "14.39.93.74"
}

variable "object_storage_access_key_id" {
  type        = string
  description = "[USER_INPUT] Object Storage access key ID"
  default     = "put_the_value_if_you_use_object_storage_in_this_lab"
}

variable "object_storage_secret_access_key" {
  type        = string
  description = "[USER_INPUT] Object Storage secret access key"
  default     = "put_the_value_if_you_use_object_storage_in_this_lab"
}

variable "object_storage_bucket_string" {
  type        = string
  description = "[USER_INPUT] Object Storage bucket string"
  default     = "put_the_value_if_you_use_object_storage_in_this_lab"
}

########################################################
# 2. ceweb 애플리케이션 필수 변수 (CEWEB_REQUIRED_VARIABLES)
#    ceweb 애플리케이션과 Terraform에서 공통으로 사용하는 변수입니다.
#    master_config.json에서 요구하는 변수 중 일부가 포함됩니다.
#    이 파트에는 새로운 변수를 추가할 수 없습니다.
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
  default     = "ars4mundus@gmail.com"
}

########################################################
# 3. Terraform 인프라 변수 (TERRAFORM_INFRASTRUCTURE_VARIABLES)
#    Terraform 리소스 생성에만 필요한 변수들
#    이 파트에는 새로운 변수를 추가할 수 있습니다.
#    단, 이 파트의 변수는 main.tf에서만 사용됩니다.
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

variable "pip4_name" {
  type        = string
  description = "Public IP 4 name [TERRAFORM_INFRA]"
  default     = "PIP4"
}

variable "public_ip_description" {
  type        = string
  description = "Public IP description [TERRAFORM_INFRA]"
  default     = "Public IP for VM"
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

# VM Configuration Variables
variable "vm_bastion_name" {
  type        = string
  description = "Bastion VM name [TERRAFORM_INFRA]"
  default     = "bastionvm110w"
}

variable "vm_bastion_description" {
  type        = string
  description = "Bastion VM description [TERRAFORM_INFRA]"
  default     = "bastion VM"
}

variable "vm_web_name" {
  type        = string
  description = "Web VM name [TERRAFORM_INFRA]"
  default     = "webvm111r"
}

variable "vm_web_description" {
  type        = string
  description = "Web VM description [TERRAFORM_INFRA]"
  default     = "web VM1"
}

variable "vm_web2_name" {
  type        = string
  description = "Web VM2 name [TERRAFORM_INFRA]"
  default     = "webvm112r"
}

variable "vm_web2_description" {
  type        = string
  description = "Web VM2 description [TERRAFORM_INFRA]"
  default     = "web VM2"
}

variable "vm_app_name" {
  type        = string
  description = "App VM name [TERRAFORM_INFRA]"
  default     = "appvm121r"
}

variable "vm_app_description" {
  type        = string
  description = "App VM description [TERRAFORM_INFRA]"
  default     = "app VM1"
}

variable "vm_app2_name" {
  type        = string
  description = "App VM2 name [TERRAFORM_INFRA]"
  default     = "appvm122r"
}

variable "vm_app2_description" {
  type        = string
  description = "App VM2 description [TERRAFORM_INFRA]"
  default     = "app VM2"
}

variable "vm_db_name" {
  type        = string
  description = "DB VM name [TERRAFORM_INFRA]"
  default     = "dbvm131r"
}

variable "vm_db_description" {
  type        = string
  description = "DB VM description [TERRAFORM_INFRA]"
  default     = "db VM"
}

# Boot Volume Configuration Variables
variable "windows_boot_volume_size" {
  type        = number
  description = "Windows boot volume size in GB [TERRAFORM_INFRA]"
  default     = 32
}

variable "windows_boot_volume_type" {
  type        = string
  description = "Windows boot volume type [TERRAFORM_INFRA]"
  default     = "SSD"
}

variable "windows_boot_volume_delete_on_termination" {
  type        = bool
  description = "Delete Windows boot volume on termination [TERRAFORM_INFRA]"
  default     = true
}

variable "rocky_boot_volume_size" {
  type        = number
  description = "Rocky boot volume size in GB [TERRAFORM_INFRA]"
  default     = 16
}

variable "rocky_boot_volume_type" {
  type        = string
  description = "Rocky boot volume type [TERRAFORM_INFRA]"
  default     = "SSD"
}

variable "rocky_boot_volume_delete_on_termination" {
  type        = bool
  description = "Delete Rocky boot volume on termination [TERRAFORM_INFRA]"
  default     = true
}










