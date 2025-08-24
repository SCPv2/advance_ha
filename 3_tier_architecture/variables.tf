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


variable "object_storage_bucket_string" {
  type        = string
  description = "Samsung Cloud Platform Object Storage bucket string"
  default     = ""                                      # Object Storage bucket string 입력 필요
}

variable "object_storage_access_key_id" {
  type        = string
  description = "Samsung Cloud Platform Object Storage Access Key ID"
  default     = ""                                      # Object Storage Access Key ID 입력 필요
}

variable "object_storage_secret_access_key" {
  type        = string
  description = "Samsung Cloud Platform Object Storage Secret Access Key"
  default     = ""                                      # Object Storage Secret Key 입력 필요
  sensitive   = true
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

########################################################
# Public IP 변수 정의
########################################################

variable "public_ips" {
  type = list(object({
    name        = string
    description = string
  }))
  default = [
    { name = "PIP1", description = "Public IP for Bastion" },
    { name = "PIP2", description = "Public IP for Web NAT" },
    { name = "PIP3", description = "Public IP for App NAT" },
    { name = "PIP4", description = "Public IP for DB NAT" }
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

########################################################
# Derived variables for master_config.json template
########################################################
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