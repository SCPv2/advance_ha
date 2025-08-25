########################################################
# Provider : Samsung Cloud Platform v2
########################################################
terraform {
  required_providers {
    samsungcloudplatformv2 = {
      version = "1.0.3"
      source  = "SamsungSDSCloud/samsungcloudplatformv2"
    }
  }
  required_version = ">= 1.11"
}

provider "samsungcloudplatformv2" {
}

########################################################
# VPC 자원 생성
########################################################
resource "samsungcloudplatformv2_vpc_vpc" "vpc" {
  name        = var.vpc_name
  cidr        = var.vpc_cidr
  description = var.vpc_description
  tags        = var.common_tags
}

########################################################
# Internet Gateway 생성, VPC 연결
########################################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "igw" {
  type              = "IGW"
  vpc_id            = samsungcloudplatformv2_vpc_vpc.vpc.id
  firewall_enabled  = true
  firewall_loggable = false
  tags              = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpc]
}

########################################################
# Subnet 자원 생성
########################################################
resource "samsungcloudplatformv2_vpc_subnet" "web_subnet" {
  name        = var.web_subnet_name
  cidr        = var.web_subnet_cidr
  type        = var.subnet_type
  description = "ceweb Subnet"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

resource "samsungcloudplatformv2_vpc_subnet" "app_subnet" {
  name        = var.app_subnet_name
  cidr        = var.app_subnet_cidr
  type        = var.subnet_type
  description = "App Subnet"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

resource "samsungcloudplatformv2_vpc_subnet" "db_subnet" {
  name        = var.db_subnet_name
  cidr        = var.db_subnet_cidr
  type        = var.subnet_type
  description = "DB Subnet"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# 기존 Key Pair 조회
########################################################
data "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
}

########################################################
# DNS Private Hosted Zone Records (Initial VM IPs)
########################################################
resource "samsungcloudplatformv2_dns_record" "www_initial" {
  hosted_zone_id = var.private_hosted_zone_id
  record_create = {
    name        = "www.${var.private_domain_name}"
    type        = "A"
    records     = [var.web_ip]
    ttl         = 300
    description = "Initial DNS record for web server (will be updated to LB IP manually)"
  }

  depends_on = [samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet]
}

resource "samsungcloudplatformv2_dns_record" "app_initial" {
  hosted_zone_id = var.private_hosted_zone_id
  record_create = {
    name        = "app.${var.private_domain_name}"
    type        = "A"
    records     = [var.app_ip]
    ttl         = 300
    description = "Initial DNS record for app server (will be updated to LB IP manually)"
  }

  depends_on = [samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet]
}

resource "samsungcloudplatformv2_dns_record" "db_record" {
  hosted_zone_id = var.private_hosted_zone_id
  record_create = {
    name        = "db.${var.private_domain_name}"
    type        = "A"
    records     = [var.db_ip]
    ttl         = 300
    description = "DNS record for database server (permanent)"
  }

  depends_on = [samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet]
}

########################################################
# Public IP
########################################################
resource "samsungcloudplatformv2_vpc_publicip" "pip1" {
  type        = "IGW"
  description = var.public_ip_description
  tags        = var.common_tags
  depends_on  = [samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet]
}

resource "samsungcloudplatformv2_vpc_publicip" "pip2" {
  type        = "IGW"
  description = var.public_ip_description
  tags        = var.common_tags
  depends_on  = [samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet]
}

resource "samsungcloudplatformv2_vpc_publicip" "pip3" {
  type        = "IGW"
  description = var.public_ip_description
  tags        = var.common_tags
  depends_on  = [samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet]
}

resource "samsungcloudplatformv2_vpc_publicip" "pip4" {
  type        = "IGW"
  description = var.public_ip_description
  tags        = var.common_tags
  depends_on  = [samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet]
}

########################################################
# Security Group
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "bastion_sg" {
  name     = var.security_group_bastion
  loggable = false
  tags     = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "web_sg" {
  name     = var.security_group_web
  loggable = false
  tags     = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "app_sg" {
  name     = var.security_group_app
  loggable = false
  tags     = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "db_sg" {
  name     = var.security_group_db
  loggable = false
  tags     = var.common_tags
}

########################################################
# 기본 통신 규칙 (Firewall)
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "fw_igw" {
  product_type = ["IGW"]
  size         = 1

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

locals {
  igw1_firewall_id = try(data.samsungcloudplatformv2_firewall_firewalls.fw_igw.ids, "")
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "bastion_rdp_in_fw" {
  firewall_id = local.igw1_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.bastion_ip]
    description         = "RDP inbound to bastion"
    service = [
      { service_type = "TCP", service_value = "3389" }
    ]

    depends_on = [samsungcloudplatformv2_firewall_firewall_rule.vm_web_out_fw]
  }
}

# Web Load Balancer inbound rule
resource "samsungcloudplatformv2_firewall_firewall_rule" "web_lb_in_fw" {
  firewall_id = local.igw1_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.web_lb_service_ip]
    description         = "HTTP inbound to Web Load Balancer"
    service = [
      { service_type = "TCP", service_value = "80" }
    ]

    depends_on = [samsungcloudplatformv2_firewall_firewall_rule.bastion_rdp_in_fw]
  }
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "vm_web_out_fw" {
  firewall_id = local.igw1_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = [var.bastion_ip, var.web_ip, var.web_ip2, var.app_ip, var.app_ip2, var.db_ip]
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP/HTTPS outbound to Internet"
    service = [
      { service_type = "TCP", service_value = "80" },
      { service_type = "TCP", service_value = "443" }
    ]

    depends_on = [samsungcloudplatformv2_vpc_internet_gateway.igw]
  }
}

########################################################
# 기본 통신 규칙 (Security Group)
########################################################
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_RDP_in_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 3389
  port_range_max    = 3389
  description       = "RDP inbound to bastion VM"
  remote_ip_prefix  = var.user_public_ip

  depends_on = [samsungcloudplatformv2_security_group_security_group.bastion_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_RDP_in_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "db_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.db_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "db_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.db_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.db_http_out_sg]
}

########################################################
# Subnet에 NAT Gateway 연결
########################################################
resource "samsungcloudplatformv2_vpc_nat_gateway" "web_natgateway" {
  subnet_id   = samsungcloudplatformv2_vpc_subnet.web_subnet.id
  publicip_id = samsungcloudplatformv2_vpc_publicip.pip2.id
  description = "NAT for web"
  tags        = var.common_tags

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_publicip.pip1, samsungcloudplatformv2_vpc_publicip.pip2, samsungcloudplatformv2_vpc_publicip.pip3, samsungcloudplatformv2_vpc_publicip.pip4
  ]
}

resource "samsungcloudplatformv2_vpc_nat_gateway" "app_natgateway" {
  subnet_id   = samsungcloudplatformv2_vpc_subnet.app_subnet.id
  publicip_id = samsungcloudplatformv2_vpc_publicip.pip3.id
  description = "NAT for app"
  tags        = var.common_tags

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_publicip.pip1, samsungcloudplatformv2_vpc_publicip.pip2, samsungcloudplatformv2_vpc_publicip.pip3, samsungcloudplatformv2_vpc_publicip.pip4
  ]
}

resource "samsungcloudplatformv2_vpc_nat_gateway" "db_natgateway" {
  subnet_id   = samsungcloudplatformv2_vpc_subnet.db_subnet.id
  publicip_id = samsungcloudplatformv2_vpc_publicip.pip4.id
  description = "NAT for db"
  tags        = var.common_tags

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_publicip.pip1, samsungcloudplatformv2_vpc_publicip.pip2, samsungcloudplatformv2_vpc_publicip.pip3, samsungcloudplatformv2_vpc_publicip.pip4
  ]
}

########################################################
# Ports
########################################################
resource "samsungcloudplatformv2_vpc_port" "bastion_port" {
  name             = "bastionport"
  description      = "bastion port"
  subnet_id        = samsungcloudplatformv2_vpc_subnet.web_subnet.id
  fixed_ip_address = var.bastion_ip
  tags             = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet
  ]
}

resource "samsungcloudplatformv2_vpc_port" "web_port" {
  name             = "webport"
  description      = "web port"
  subnet_id        = samsungcloudplatformv2_vpc_subnet.web_subnet.id
  fixed_ip_address = var.web_ip
  tags             = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.web_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.web_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet
  ]
}

resource "samsungcloudplatformv2_vpc_port" "web_port2" {
  name             = "webport2"
  description      = "web port2"
  subnet_id        = samsungcloudplatformv2_vpc_subnet.web_subnet.id
  fixed_ip_address = var.web_ip2
  tags             = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.web_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.web_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet
  ]
}

resource "samsungcloudplatformv2_vpc_port" "app_port" {
  name             = "appport"
  description      = "app port"
  subnet_id        = samsungcloudplatformv2_vpc_subnet.app_subnet.id
  fixed_ip_address = var.app_ip
  tags             = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.app_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.app_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet
  ]
}

resource "samsungcloudplatformv2_vpc_port" "app_port2" {
  name             = "appport2"
  description      = "app port2"
  subnet_id        = samsungcloudplatformv2_vpc_subnet.app_subnet.id
  fixed_ip_address = var.app_ip2
  tags             = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.app_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.app_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet
  ]
}

resource "samsungcloudplatformv2_vpc_port" "db_port" {
  name             = "dbport"
  description      = "db port"
  subnet_id        = samsungcloudplatformv2_vpc_subnet.db_subnet.id
  fixed_ip_address = var.db_ip
  tags             = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.db_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.db_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet
  ]
}

########################################################
# Virtual Server Standard Image ID 조회
########################################################
# Windows 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "windows" {
  os_distro = var.image_windows_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_windows_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_windows_scp_os_version]
    use_regex = false
  }
}

# Rocky Linux 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "rocky" {
  os_distro = var.image_rocky_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_rocky_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_rocky_scp_os_version]
    use_regex = false
  }
}

# 이미지 Local 변수 지정
locals {
  windows_ids = try(data.samsungcloudplatformv2_virtualserver_images.windows.ids, [])
  rocky_ids   = try(data.samsungcloudplatformv2_virtualserver_images.rocky.ids, [])

  windows_image_id_first = length(local.windows_ids) > 0 ? local.windows_ids[0] : ""
  rocky_image_id_first   = length(local.rocky_ids) > 0 ? local.rocky_ids[0] : ""
}

########################################################
# Virtual Server 자원 생성
########################################################

# 1. DB VM (첫 번째 생성)
resource "samsungcloudplatformv2_virtualserver_server" "vm4" {
  name           = var.vm_db_name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.rocky_boot_volume_size
    type                  = var.rocky_boot_volume_type
    delete_on_termination = var.rocky_boot_volume_delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.db_port.id
    }
  }
  user_data = base64encode(file("${path.module}/scripts/userdata_db.sh"))
  depends_on = [
    samsungcloudplatformv2_dns_record.db_record,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_security_group_security_group.db_sg,
    samsungcloudplatformv2_vpc_port.db_port,
    samsungcloudplatformv2_vpc_nat_gateway.db_natgateway
  ]
}

# 2. App VM1 
resource "samsungcloudplatformv2_virtualserver_server" "vm3" {
  name           = var.vm_app_name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.rocky_boot_volume_size
    type                  = var.rocky_boot_volume_type
    delete_on_termination = var.rocky_boot_volume_delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.app_port.id
    }
  }
  user_data = base64encode(file("${path.module}/scripts/userdata_app.sh"))
  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm4,  # DB VM 완료 후
    samsungcloudplatformv2_dns_record.app_initial,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_port.app_port,
    samsungcloudplatformv2_vpc_nat_gateway.app_natgateway
  ]
}

# App VM2
resource "samsungcloudplatformv2_virtualserver_server" "vm3_2" {
  name           = var.vm_app2_name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.rocky_boot_volume_size
    type                  = var.rocky_boot_volume_type
    delete_on_termination = var.rocky_boot_volume_delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.app_port2.id
    }
  }
  user_data = base64encode(file("${path.module}/scripts/userdata_app.sh"))
  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm4,  # DB VM 완료 후
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_port.app_port2,
    samsungcloudplatformv2_vpc_nat_gateway.app_natgateway
  ]
}

# Web VM1
resource "samsungcloudplatformv2_virtualserver_server" "vm2" {
  name           = var.vm_web_name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags
  boot_volume = {
    size                  = var.rocky_boot_volume_size
    type                  = var.rocky_boot_volume_type
    delete_on_termination = var.rocky_boot_volume_delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.web_port.id
    }
  }
  user_data = base64encode(file("${path.module}/scripts/userdata_web.sh"))
  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm3,  # App VM 1 완료 후
    samsungcloudplatformv2_dns_record.www_initial,
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_port.web_port,
    samsungcloudplatformv2_vpc_nat_gateway.web_natgateway
  ]
}

# Web VM 2 (App VM 1 생성 후)
resource "samsungcloudplatformv2_virtualserver_server" "vm2_2" {
  name           = var.vm_web2_name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags
  boot_volume = {
    size                  = var.rocky_boot_volume_size
    type                  = var.rocky_boot_volume_type
    delete_on_termination = var.rocky_boot_volume_delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.web_port2.id
    }
  }
  user_data = base64encode(file("${path.module}/scripts/userdata_web.sh"))
  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm3,  # App VM 1 완료 후
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_port.web_port2,
    samsungcloudplatformv2_vpc_nat_gateway.web_natgateway
  ]
}

# 6. Bastion VM
resource "samsungcloudplatformv2_virtualserver_server" "vm1" {
  name           = var.vm_bastion_name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags
  boot_volume = {
    size                  = var.windows_boot_volume_size
    type                  = var.windows_boot_volume_type
    delete_on_termination = var.windows_boot_volume_delete_on_termination
  }
  image_id = local.windows_image_id_first
  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pip1.id,
      port_id      = samsungcloudplatformv2_vpc_port.bastion_port.id
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_publicip.pip1, samsungcloudplatformv2_vpc_publicip.pip2, samsungcloudplatformv2_vpc_publicip.pip3, samsungcloudplatformv2_vpc_publicip.pip4,
    samsungcloudplatformv2_vpc_port.bastion_port
  ]
}

########################################################
# Web Load Balancer 구성
########################################################

# Web Load Balancer
resource "samsungcloudplatformv2_loadbalancer_loadbalancer" "web_lb" {
  loadbalancer_create = {
    name                     = "weblb"
    description              = "Web Load Balancer"
    layer_type               = "L4"
    vpc_id                   = samsungcloudplatformv2_vpc_vpc.vpc.id
    subnet_id                = samsungcloudplatformv2_vpc_subnet.web_subnet.id
    service_ip               = var.web_lb_service_ip
    publicip_id              = samsungcloudplatformv2_vpc_publicip.pip2.id
    firewall_enabled         = true
    firewall_logging_enabled = true
  }

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm2_2,  # 모든 Web VM 생성 완료 후
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_vpc_publicip.pip1, samsungcloudplatformv2_vpc_publicip.pip2, samsungcloudplatformv2_vpc_publicip.pip3, samsungcloudplatformv2_vpc_publicip.pip4
  ]
}

# Web Health Check
resource "samsungcloudplatformv2_loadbalancer_lb_health_check" "web_health_check" {
  lb_health_check_create = {
    name                  = "web_healthcheck"
    vpc_id                = samsungcloudplatformv2_vpc_vpc.vpc.id
    subnet_id             = samsungcloudplatformv2_vpc_subnet.web_subnet.id
    protocol              = "HTTP"
    health_check_port     = 80
    health_check_interval = 5
    health_check_timeout  = 5
    health_check_count    = 3
    http_method           = "GET"
    health_check_url      = "/"
    response_code         = "200"
    description           = "Web server health check"
  }

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_loadbalancer_loadbalancer.web_lb
  ]
}

# Web Server Group
resource "samsungcloudplatformv2_loadbalancer_lb_server_group" "web_server_group" {
  lb_server_group_create = {
    name               = "weblbgrp"
    vpc_id             = samsungcloudplatformv2_vpc_vpc.vpc.id
    subnet_id          = samsungcloudplatformv2_vpc_subnet.web_subnet.id
    protocol           = "TCP"
    lb_method          = "ROUND_ROBIN"
    description        = "Web server group"
    lb_health_check_id = samsungcloudplatformv2_loadbalancer_lb_health_check.web_health_check.id
  }

  depends_on = [
    samsungcloudplatformv2_loadbalancer_lb_health_check.web_health_check
  ]
}

# Web Server Group Members
resource "samsungcloudplatformv2_loadbalancer_lb_member" "web_member1" {
  lb_server_group_id = samsungcloudplatformv2_loadbalancer_lb_server_group.web_server_group.id

  lb_member_create = {
    name          = "webvm111r-member"
    object_type   = "VM"
    object_id     = samsungcloudplatformv2_virtualserver_server.vm2.id
    member_weight = 1
  }

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm2,
    samsungcloudplatformv2_loadbalancer_lb_server_group.web_server_group
  ]
}

resource "samsungcloudplatformv2_loadbalancer_lb_member" "web_member2" {
  lb_server_group_id = samsungcloudplatformv2_loadbalancer_lb_server_group.web_server_group.id

  lb_member_create = {
    name          = "webvm112r-member"
    object_type   = "VM"
    object_id     = samsungcloudplatformv2_virtualserver_server.vm2_2.id
    member_weight = 1
  }

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm2_2,
    samsungcloudplatformv2_loadbalancer_lb_server_group.web_server_group
  ]
}

# Web Listener
resource "samsungcloudplatformv2_loadbalancer_lb_listener" "web_listener" {
  lb_listener_create = {
    name                  = "weblistener"
    description           = "Web listener"
    loadbalancer_id       = samsungcloudplatformv2_loadbalancer_loadbalancer.web_lb.id
    protocol              = "TCP"
    service_port          = 80
    server_group_id       = samsungcloudplatformv2_loadbalancer_lb_server_group.web_server_group.id
    session_duration_time = 120
    persistence           = "source-ip"
    insert_client_ip      = false
  }

  depends_on = [
    samsungcloudplatformv2_loadbalancer_loadbalancer.web_lb,
    samsungcloudplatformv2_loadbalancer_lb_server_group.web_server_group
  ]
}

########################################################
# App Load Balancer 구성
########################################################

# App Load Balancer
resource "samsungcloudplatformv2_loadbalancer_loadbalancer" "app_lb" {
  loadbalancer_create = {
    name                     = "applb"
    description              = "App Load Balancer"
    layer_type               = "L4"
    vpc_id                   = samsungcloudplatformv2_vpc_vpc.vpc.id
    subnet_id                = samsungcloudplatformv2_vpc_subnet.app_subnet.id
    service_ip               = var.app_lb_service_ip
    publicip_id              = null
    firewall_enabled         = true
    firewall_logging_enabled = true
  }

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm3_2,  # 모든 App VM 생성 완료 후
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet
  ]
}

# App Health Check
resource "samsungcloudplatformv2_loadbalancer_lb_health_check" "app_health_check" {
  lb_health_check_create = {
    name                  = "app_healthcheck"
    vpc_id                = samsungcloudplatformv2_vpc_vpc.vpc.id
    subnet_id             = samsungcloudplatformv2_vpc_subnet.app_subnet.id
    protocol              = "TCP"
    health_check_port     = 3000
    health_check_interval = 5
    health_check_timeout  = 5
    health_check_count    = 3
    description           = "App server health check"
  }

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.web_subnet, samsungcloudplatformv2_vpc_subnet.app_subnet, samsungcloudplatformv2_vpc_subnet.db_subnet,
    samsungcloudplatformv2_loadbalancer_loadbalancer.app_lb
  ]
}

# App Server Group
resource "samsungcloudplatformv2_loadbalancer_lb_server_group" "app_server_group" {
  lb_server_group_create = {
    name               = "applbgrp"
    vpc_id             = samsungcloudplatformv2_vpc_vpc.vpc.id
    subnet_id          = samsungcloudplatformv2_vpc_subnet.app_subnet.id
    protocol           = "TCP"
    lb_method          = "ROUND_ROBIN"
    description        = "App server group"
    lb_health_check_id = samsungcloudplatformv2_loadbalancer_lb_health_check.app_health_check.id
  }

  depends_on = [
    samsungcloudplatformv2_loadbalancer_lb_health_check.app_health_check
  ]
}

# App Server Group Members
resource "samsungcloudplatformv2_loadbalancer_lb_member" "app_member1" {
  lb_server_group_id = samsungcloudplatformv2_loadbalancer_lb_server_group.app_server_group.id

  lb_member_create = {
    name          = "appvm121r-member"
    object_type   = "VM"
    object_id     = samsungcloudplatformv2_virtualserver_server.vm3.id
    member_weight = 1
  }

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm3,
    samsungcloudplatformv2_loadbalancer_lb_server_group.app_server_group
  ]
}

resource "samsungcloudplatformv2_loadbalancer_lb_member" "app_member2" {
  lb_server_group_id = samsungcloudplatformv2_loadbalancer_lb_server_group.app_server_group.id

  lb_member_create = {
    name          = "appvm122r-member"
    object_type   = "VM"
    object_id     = samsungcloudplatformv2_virtualserver_server.vm3_2.id
    member_weight = 1
  }

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm3_2,
    samsungcloudplatformv2_loadbalancer_lb_server_group.app_server_group

  ]
}

# App Listener
resource "samsungcloudplatformv2_loadbalancer_lb_listener" "app_listener" {
  lb_listener_create = {
    name                  = "applistener"
    description           = "App listener"
    loadbalancer_id       = samsungcloudplatformv2_loadbalancer_loadbalancer.app_lb.id
    protocol              = "TCP"
    service_port          = 3000
    server_group_id       = samsungcloudplatformv2_loadbalancer_lb_server_group.app_server_group.id
    session_duration_time = 120
    persistence           = "source-ip"
    insert_client_ip      = false
  }

  depends_on = [
    samsungcloudplatformv2_loadbalancer_loadbalancer.app_lb,
    samsungcloudplatformv2_loadbalancer_lb_server_group.app_server_group
  ]
}


########################################################
# 추가 Security Group 규칙 - 3-Tier 아키텍처 요구사항
########################################################

# Bastion SSH outbound to web SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_ssh_to_web_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH outbound to web vm"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.web_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.db_https_out_sg]
}

# Bastion SSH outbound to app SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_ssh_to_app_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH outbound to app vm"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.app_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_ssh_to_web_sg]
}

# Bastion SSH outbound to db SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_ssh_to_db_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH outbound to db vm"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.db_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_ssh_to_app_sg]
}

# Bastion HTTP outbound to web SG for monitoring
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_http_to_web_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to web vm for monitoring"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.web_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_ssh_to_db_sg]
}

# Web SSH inbound from bastion SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_ssh_from_bastion_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH inbound from bastion"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_http_to_web_sg]
}

# Web HTTP inbound from bastion SG for monitoring
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_http_from_bastion_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP inbound from bastion"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_ssh_from_bastion_sg]
}

# Web API outbound to app LB Service IP
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_api_to_app_lb_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  description       = "API connection outbound to app LB"
  remote_ip_prefix  = "${var.app_lb_service_ip}/32"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_http_from_bastion_sg]
}

# App SSH inbound from bastion SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "app_ssh_from_bastion_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH inbound from bastion"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_api_to_app_lb_sg]
}

# App DB outbound to db SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "app_db_to_db_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 2866
  port_range_max    = 2866
  description       = "db connection outbound to db vm"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.db_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_ssh_from_bastion_sg]
}

# DB inbound from app SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "db_from_app_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.db_sg.id
  protocol          = "tcp"
  port_range_min    = 2866
  port_range_max    = 2866
  description       = "db connection inbound from app vm"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.app_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_db_to_db_sg]
}

# DB SSH inbound from bastion SG
resource "samsungcloudplatformv2_security_group_security_group_rule" "db_ssh_from_bastion_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.db_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH inbound from bastion"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.db_from_app_sg]
}

########################################################
# 추가 Security Group 규칙 - Web-to-App 직접 통신
########################################################

# Web direct API outbound to App SG (for initial deployment before LB)
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_direct_to_app_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  description       = "Direct API connection outbound to app servers"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.app_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.db_ssh_from_bastion_sg]
}

# App direct API inbound from Web SG (for initial deployment before LB)
resource "samsungcloudplatformv2_security_group_security_group_rule" "app_direct_from_web_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  description       = "Direct API connection inbound from web servers"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.web_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_direct_to_app_sg]
}

########################################################
# File Storage Volume 구성
########################################################

# Shared File Storage Volume 생성 (Web/App 서버 공유)
resource "samsungcloudplatformv2_filestorage_volume" "shared_volume" {
  name                       = "shared_storage"
  protocol                   = "NFS"
  type_name                  = "HighPerformanceSSD"
  file_unit_recovery_enabled = true
  tags                       = var.common_tags

  # 4개 서버에 대한 접근 권한 설정
  access_rules = [
    {
      object_type = "VM"
      object_id   = samsungcloudplatformv2_virtualserver_server.vm2.id # webvm111r
    },
    {
      object_type = "VM"
      object_id   = samsungcloudplatformv2_virtualserver_server.vm2_2.id # webvm112r
    },
    {
      object_type = "VM"
      object_id   = samsungcloudplatformv2_virtualserver_server.vm3.id # appvm121r
    },
    {
      object_type = "VM"
      object_id   = samsungcloudplatformv2_virtualserver_server.vm3_2.id # appvm122r
    }
  ]

  depends_on = [
    samsungcloudplatformv2_virtualserver_server.vm2,
    samsungcloudplatformv2_virtualserver_server.vm2_2,
    samsungcloudplatformv2_virtualserver_server.vm3,
    samsungcloudplatformv2_virtualserver_server.vm3_2
  ]
}
