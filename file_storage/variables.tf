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
  default     = "your_private_domain.name"                                     # 사용자 Private 도메인으로 변경
}


variable "public_domain_name" {
  type        = string
  description = "[USER_INPUT] Public domain name (e.g., example.com)"
  default     = "your_public_domain.name"                                     # 사용자 Public 도메인으로 변경
}


# Object Storage 변수들은 기본 3-tier 아키텍처에서 불필요하여 제거
# Three Tier Object 아키텍처(_obj 파일)를 사용할 경우에만 별도 구성 필요



variable "keypair_name" {
  type        = string
  description = "[USER_INPUT] Key Pair to access VM"
  default     = "mykey"                                 # 기존 Key Pair 이름으로 변경
}

variable "user_public_ip" {
  type        = string
  description = "[USER_INPUT] Public IP address of user PC"
  default     = "your_public_ip/32"                                # 수강자 PC의 Public IP 주소 입력
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
# VM Private IP 주소
########################################################
variable "bastion_ip" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of bastion VM"
  default     = "10.1.1.110"                           
}

variable "web_ip" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of web VM"
  default     = "10.1.1.111"                           
}

variable "app_ip" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of app VM"
  default     = "10.1.2.121"                           
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

variable "db_ip" {
  type        = string
  description = "[TERRAFORM_INFRA] Private IP address of db VM"
  default     = "10.1.3.131"                           
}

########################################################
# VPC 변수 정의
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

########################################################
# Public IP 변수 정의
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
    { name = "PIP4", description = "Public IP for VM" }
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
# Image IDs (Auto-generated from SCP CLI)
variable "windows_image_id" {
  type        = string
  description = "Windows Server image ID [TERRAFORM_INFRA]"
  default     = "image-not-found"
}

variable "rocky_image_id" {
  type        = string
  description = "Rocky Linux image ID [TERRAFORM_INFRA]"
  default     = "image-not-found"
}

########################################################
# Virtual Server 변수 정의
########################################################

variable "server_type_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Server type ID for virtual machines"
  default     = "s1v1m2"
}

variable "vm_bastion" {
  type = object({
    name = string
    description = string
  })
  description = "[TERRAFORM_INFRA] Bastion VM configuration"
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
  description = "[TERRAFORM_INFRA] Web VM1 configuration"
  default = {
    name = "webvm111r"
    description = "web VM1"
  }
}

variable "vm_web2" {
  type = object({
    name = string
    description = string
  })
  description = "[TERRAFORM_INFRA] Web VM2 configuration"
  default = {
    name = "webvm112r"
    description = "web VM2"
  }
}

variable "vm_app" {
  type = object({
    name = string
    description = string
  })
  description = "[TERRAFORM_INFRA] App VM1 configuration"
  default = {
    name = "appvm121r"
    description = "app VM1"
  }
}

variable "vm_app2" {
  type = object({
    name = string
    description = string
  })
  description = "[TERRAFORM_INFRA] App VM2 configuration"
  default = {
    name = "appvm122r"
    description = "app VM2"
  }
}

variable "vm_db" {
  type = object({
    name = string
    description = string
  })
  description = "[TERRAFORM_INFRA] Database VM configuration"
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





























