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
# 수강자 입력 항목
########################################################

variable "private_domain_name" {
  type        = string
  description = "Private domain name (e.g., internal.local)"
  default     = "cesvc.net"                                     # 사용자 Private 도메인으로 변경
}

variable "private_hosted_zone_id" {
  type        = string
  description = "Private Hosted Zone ID for domain"
  default     = "9fa4151c-0dc8-4397-a22c-9797c3026cd2"                                    # Private Hosted Zone ID 입력 필요 : 콘솔에서 등록하고 입력 필요.
}

variable "public_domain_name" {
  type        = string
  description = "Public domain name (e.g., example.com)"
  default     = "cosmetic-evolution.net"                                     # 사용자 Public 도메인으로 변경
}


########################################################
# Object Storage 설정 (Three Tier Object 아키텍처용)
########################################################

variable "object_storage_bucket_name" {
  type        = string
  description = "Object Storage Bucket name for media files"
  default     = "ceweb"                                     # 사용자가 생성한 버킷 이름으로 변경
}

variable "object_storage_bucket_string" {
  type        = string
  description = "Object Storage Bucket string identifier"
  default     = "thisneedstobereplaced1234"                 # 사용자 버킷 생성 후 실제 bucket string으로 변경
}

variable "object_storage_access_key_id" {
  type        = string
  description = "Object Storage access key ID"
  default     = "your-access-key-here"                      # 사용자 Access Key ID로 변경
}

variable "object_storage_secret_access_key" {
  type        = string
  description = "Object Storage secret access key"
  default     = "your-secret-key-here"                      # 사용자 Secret Access Key로 변경
}

########################################################
# 관리형 데이터베이스 설정 (기존 VM 기반 DB 속성 유지)
########################################################

variable "database_name" {
  type        = string
  description = "PostgreSQL database name"
  default     = "cedb"                                      # 기존 VM 기반 DB와 동일한 데이터베이스명
}

variable "database_user" {
  type        = string
  description = "PostgreSQL master username"
  default     = "ceadmin"                                   # 기존 VM 기반 DB와 동일한 사용자명
}

variable "database_password" {
  type        = string
  description = "PostgreSQL master password"
  default     = "ceadmin123!"                               # 기존 VM 기반 DB와 동일한 비밀번호
}

variable "postgresql_engine_version_id" {
  type        = string
  description = "PostgreSQL engine version ID for managed cluster"  
  default     = "8a463aa4b1dc4f279c3f53b94dc45e74"          # Samsung Cloud Platform 포털에서 PostgreSQL Community 16.8 엔진 버전 ID 확인 후 입력
  # 실제 운영 환경: softwareVersion "COMMUNITY 16.8", dbaasFlavorName "db1v2m4"
}

variable "keypair_name" {
  type        = string
  description = "Key Pair to access VM"
  default     = "mykey"                                 # 기존 Key Pair 이름으로 변경
}

variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"
  default     = "x.x.x.x"                                # 수강자 PC의 Public IP 주소 입력
}

########################################################
# VM Private IP 주소
########################################################
variable "bastion_ip" {
  type        = string
  description = "Private IP address of bastion VM"
  default     = "10.1.1.110"                           
}

variable "web_ip" {
  type        = string
  description = "Private IP address of web VM"
  default     = "10.1.1.111"                           
}

variable "app_ip" {
  type        = string
  description = "Private IP address of app VM"
  default     = "10.1.2.121"                           
}

variable "web_ip2" {
  type        = string
  description = "Private IP address of web VM2"
  default     = "10.1.1.112"                           
}

variable "app_ip2" {
  type        = string
  description = "Private IP address of app VM2"
  default     = "10.1.2.122"                           
}

variable "db_ip" {
  type        = string
  description = "Private IP address of db VM"
  default     = "10.1.3.131"                           
}

########################################################
# VPC 변수 정의
########################################################
variable "vpcs" {
  description = "VPC for Creative Energy"
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
  description = "Subnet for Creative Energy"
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
    default     = "bastionSG"
  }

variable "security_group_web" {
    type        = string
    default     = "webSG"
  }

variable "security_group_app" {
    type        = string
    default     = "appSG"
  }

variable "security_group_db" {
    type        = string
    default     = "dbSG"
  }

########################################################
# Virtual Server Standard Image 변수 정의
########################################################
variable "image_windows_os_distro" {
  type        = string
  default     = "windows"
}

variable "image_windows_scp_os_version" {
  type        = string
  default     = "2022 Std."
}

variable "image_rocky_os_distro" {
  type        = string
  default     = "rocky"
}

variable "image_rocky_scp_os_version" {
  type        = string
  default     = "9.4"
}

########################################################
# Virtual Server 변수 정의
########################################################

variable "server_type_id" {
  type    = string
  default = "s1v1m2"
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

variable "vm_web2" {
  type = object({
    name = string
    description = string
  })
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

########################################################
# Load Balancer 변수 정의
########################################################
variable "web_lb_service_ip" {
  type        = string
  description = "Service IP for Web Load Balancer"
  default     = "10.1.1.100"
}

variable "app_lb_service_ip" {
  type        = string
  description = "Service IP for App Load Balancer"
  default     = "10.1.2.100"
}