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
resource "samsungcloudplatformv2_vpc_vpc" "vpcs" {
  for_each    = { for v in var.vpcs : v.name => v }
  name        = each.value.name
  cidr        = each.value.cidr
  description = lookup(each.value, "description", null)
  tags        = var.common_tags
}

########################################################
# Internet Gateway 생성, VPC 연결
########################################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "igw" {
  for_each          = samsungcloudplatformv2_vpc_vpc.vpcs
  type              = "IGW"
  vpc_id            = each.value.id
  firewall_enabled  = true
  firewall_loggable = false
  tags              = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpcs]
}

########################################################
# Subnet 자원 생성
########################################################
resource "samsungcloudplatformv2_vpc_subnet" "subnets" {
  for_each    = { for sb in var.subnets : sb.name => sb }
  name        = each.value.name
  cidr        = each.value.cidr
  type        = each.value.type
  description = each.value.description
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpcs[each.value.vpc_name].id
  tags        = var.common_tags

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# 기존 Key Pair 조회
########################################################
data "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
}

########################################################
# Public IP
########################################################
resource "samsungcloudplatformv2_vpc_publicip" "publicips" {
  for_each    = { for pip in var.public_ips : pip.name => pip }
  type        = "IGW"
  description = each.value.description
  tags        = var.common_tags

 depends_on = [samsungcloudplatformv2_vpc_subnet.subnets] 
}

########################################################
# Security Group
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "bastion_sg" {
  name        = var.security_group_bastion
  loggable    = false
  tags        = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "web_sg" {
  name        = var.security_group_web
  loggable    = false
  tags        = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "app_sg" {
  name        = var.security_group_app
  loggable    = false
  tags        = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "db_sg" {
  name        = var.security_group_db
  loggable    = false
  tags        = var.common_tags
}

########################################################
# IGW Firewall 기본 통신 규칙
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "fw_igw" {
  product_type = ["IGW"]
  size         = 1
  
  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
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
  }
  depends_on  = [samsungcloudplatformv2_firewall_firewall_rule.web_http_in_fw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "web_http_in_fw" {
  firewall_id = local.igw1_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.web_ip]
    description         = "HTTP inbound to web server (단일서버 직접 접근)"
    service = [
      { service_type = "TCP", service_value = "80" }
    ]
  }
  depends_on  = [samsungcloudplatformv2_firewall_firewall_rule.vm_all_out_fw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "vm_all_out_fw" {
  firewall_id = local.igw1_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = [var.bastion_ip, var.web_ip, var.app_ip, var.db_ip]
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP/HTTPS outbound to Internet"
    service = [
      { service_type = "TCP", service_value = "80" },
      { service_type = "TCP", service_value = "443" }
    ]
  }
  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# Security Group 기본 통신 규칙 (CSV 기반)
########################################################

# BastionSG 규칙들
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_rdp_in_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 3389
  port_range_max    = 3389
  description       = "RDP inbound from user PC"
  remote_ip_prefix  = "${var.user_public_ip}/32"

  depends_on  = [samsungcloudplatformv2_security_group_security_group.bastion_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_ssh_out_to_web_sg" {
  direction                = "egress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol                 = "tcp"
  port_range_min           = 22
  port_range_max           = 22
  description              = "SSH outbound to webSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.web_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_rdp_in_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_ssh_out_to_app_sg" {
  direction                = "egress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol                 = "tcp"
  port_range_min           = 22
  port_range_max           = 22
  description              = "SSH outbound to appSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.app_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_ssh_out_to_web_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_ssh_out_to_db_sg" {
  direction                = "egress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol                 = "tcp"
  port_range_min           = 22
  port_range_max           = 22
  description              = "SSH outbound to dbSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.db_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_ssh_out_to_app_sg]
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

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_ssh_out_to_db_sg]
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

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.bastion_http_out_sg]
}

# WebSG 규칙들
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_ssh_in_from_bastion_sg" {
  direction                = "ingress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol                 = "tcp"
  port_range_min           = 22
  port_range_max           = 22
  description              = "SSH inbound from bastionSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_http_in_from_user_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP inbound from user PC (단일서버 직접 접근)"
  remote_ip_prefix  = "${var.user_public_ip}/32"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_ssh_in_from_bastion_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_api_out_to_app_sg" {
  direction                = "egress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol                 = "tcp"
  port_range_min           = 3000
  port_range_max           = 3000
  description              = "API outbound to appSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.app_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_http_in_from_user_sg]
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

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_api_out_to_app_sg]
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

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.web_http_out_sg]
}

# AppSG 규칙들
resource "samsungcloudplatformv2_security_group_security_group_rule" "app_ssh_in_from_bastion_sg" {
  direction                = "ingress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol                 = "tcp"
  port_range_min           = 22
  port_range_max           = 22
  description              = "SSH inbound from bastionSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_api_in_from_web_sg" {
  direction                = "ingress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol                 = "tcp"
  port_range_min           = 3000
  port_range_max           = 3000
  description              = "API inbound from webSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.web_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_ssh_in_from_bastion_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_db_out_to_db_sg" {
  direction                = "egress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol                 = "tcp"
  port_range_min           = 2866
  port_range_max           = 2866
  description              = "DB connection outbound to dbSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.db_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_api_in_from_web_sg]
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

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_db_out_to_db_sg]
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

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.app_http_out_sg]
}

# DbSG 규칙들
resource "samsungcloudplatformv2_security_group_security_group_rule" "db_ssh_in_from_bastion_sg" {
  direction                = "ingress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.db_sg.id
  protocol                 = "tcp"
  port_range_min           = 22
  port_range_max           = 22
  description              = "SSH inbound from bastionSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "db_connection_in_from_app_sg" {
  direction                = "ingress"
  ethertype                = "IPv4"
  security_group_id        = samsungcloudplatformv2_security_group_security_group.db_sg.id
  protocol                 = "tcp"
  port_range_min           = 2866
  port_range_max           = 2866
  description              = "DB connection inbound from appSG"
  remote_group_id          = samsungcloudplatformv2_security_group_security_group.app_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.db_ssh_in_from_bastion_sg]
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

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.db_connection_in_from_app_sg]
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

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.db_http_out_sg]
}

########################################################
# Subnet에 NAT Gateway 연결
########################################################
resource "samsungcloudplatformv2_vpc_nat_gateway" "web_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
    publicip_id = samsungcloudplatformv2_vpc_publicip.publicips["PIP2"].id
    description = "NAT for web"
    tags        = var.common_tags

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.web_sg,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_vpc_publicip.publicips
  ]
}

resource "samsungcloudplatformv2_vpc_nat_gateway" "app_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.subnets["Subnet12"].id
    publicip_id = samsungcloudplatformv2_vpc_publicip.publicips["PIP3"].id
    description = "NAT for app"
    tags        = var.common_tags

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.app_sg,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_vpc_publicip.publicips
  ]
}

resource "samsungcloudplatformv2_vpc_nat_gateway" "db_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.subnets["Subnet13"].id
    publicip_id = samsungcloudplatformv2_vpc_publicip.publicips["PIP4"].id
    description = "NAT for db"
    tags        = var.common_tags

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.db_sg,
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_vpc_publicip.publicips
  ]
}

########################################################
# Ports
########################################################
resource "samsungcloudplatformv2_vpc_port" "bastion_port" {
  name              = "bastionport"
  description       = "bastion port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
  fixed_ip_address  = var.bastion_ip
  tags              = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "web_port" {
  name              = "webport"
  description       = "web port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets["Subnet11"].id
  fixed_ip_address  = var.web_ip
  tags              = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.web_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.web_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "app_port" {
  name              = "appport"
  description       = "app port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets["Subnet12"].id
  fixed_ip_address  = var.app_ip
  tags              = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.app_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.app_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
  ]
}

resource "samsungcloudplatformv2_vpc_port" "db_port" {
  name              = "dbport"
  description       = "db port"
  subnet_id         = samsungcloudplatformv2_vpc_subnet.subnets["Subnet13"].id
  fixed_ip_address  = var.db_ip
  tags              = var.common_tags

  security_groups = [samsungcloudplatformv2_security_group_security_group.db_sg.id]

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.db_sg,
    samsungcloudplatformv2_vpc_subnet.subnets
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

# Rocky 이미지 조회
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
  rocky_image_id_first   = length(local.rocky_ids)   > 0 ? local.rocky_ids[0]   : ""
}

########################################################
# DNS Private Hosted Zone 설정
########################################################
data "samsungcloudplatformv2_dns_hosted_zone" "private_zone" {
  count      = var.private_hosted_zone_id != "" ? 1 : 0
  hosted_zone_id = var.private_hosted_zone_id
}

########################################################
# Virtual Server 자원 생성 (DB → APP → WEB 순서)
########################################################

# 1. bastion VM (Windows)
resource "samsungcloudplatformv2_virtualserver_server" "vm_bastion" {
  name           = var.vm_bastion.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"
  tags           = var.common_tags
  boot_volume = {
    size                  = var.boot_volume_windows.size
    type                  = var.boot_volume_windows.type
    delete_on_termination = var.boot_volume_windows.delete_on_termination
  }
  image_id = local.windows_image_id_first
  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.publicips["PIP1"].id,
      port_id      = samsungcloudplatformv2_vpc_port.bastion_port.id
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_publicip.publicips,
    samsungcloudplatformv2_vpc_port.bastion_port,
    samsungcloudplatformv2_security_group_security_group_rule.db_https_out_sg
  ]
}

# 2. db VM (첫 번째로 생성)
resource "samsungcloudplatformv2_virtualserver_server" "vm_db" {
  name           = var.vm_db.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.db_port.id
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.db_sg.id]
  user_data = base64encode(templatefile("${path.module}/master_config.json.tpl", {
    timestamp = timestamp()
    public_domain_name = var.public_domain_name
    private_domain_name = var.private_domain_name
    private_hosted_zone_id = var.private_hosted_zone_id
    vpc_cidr = var.vpc_cidr
    web_subnet_cidr = var.web_subnet_cidr
    app_subnet_cidr = var.app_subnet_cidr
    db_subnet_cidr = var.db_subnet_cidr
    web_ip = var.web_ip
    app_ip = var.app_ip
    db_ip = var.db_ip
    bastion_ip = var.bastion_ip
    user_public_ip = var.user_public_ip
    keypair_name = var.keypair_name
    object_storage_access_key_id = var.object_storage_access_key_id
    object_storage_secret_access_key = var.object_storage_secret_access_key
    object_storage_bucket_string = var.object_storage_bucket_string
  }))
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.db_sg,
    samsungcloudplatformv2_vpc_port.db_port,
    samsungcloudplatformv2_vpc_nat_gateway.db_natgateway
  ]
}

# 3. app VM (두 번째로 생성)
resource "samsungcloudplatformv2_virtualserver_server" "vm_app" {
  name           = var.vm_app.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"
  tags           = var.common_tags 
  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  } 
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.app_port.id
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.app_sg.id]
  user_data = base64encode(templatefile("${path.module}/master_config.json.tpl", {
    timestamp = timestamp()
    public_domain_name = var.public_domain_name
    private_domain_name = var.private_domain_name
    private_hosted_zone_id = var.private_hosted_zone_id
    vpc_cidr = var.vpc_cidr
    web_subnet_cidr = var.web_subnet_cidr
    app_subnet_cidr = var.app_subnet_cidr
    db_subnet_cidr = var.db_subnet_cidr
    web_ip = var.web_ip
    app_ip = var.app_ip
    db_ip = var.db_ip
    bastion_ip = var.bastion_ip
    user_public_ip = var.user_public_ip
    keypair_name = var.keypair_name
    object_storage_access_key_id = var.object_storage_access_key_id
    object_storage_secret_access_key = var.object_storage_secret_access_key
    object_storage_bucket_string = var.object_storage_bucket_string
  }))
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.app_sg,
    samsungcloudplatformv2_vpc_port.app_port,
    samsungcloudplatformv2_vpc_nat_gateway.app_natgateway,
    samsungcloudplatformv2_virtualserver_server.vm_db
  ]
}

# 4. web VM (세 번째로 생성)
resource "samsungcloudplatformv2_virtualserver_server" "vm_web" {
  name           = var.vm_web.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"
  tags           = var.common_tags
  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      port_id = samsungcloudplatformv2_vpc_port.web_port.id
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.web_sg.id] 
  user_data = base64encode(templatefile("${path.module}/master_config.json.tpl", {
    timestamp = timestamp()
    public_domain_name = var.public_domain_name
    private_domain_name = var.private_domain_name
    private_hosted_zone_id = var.private_hosted_zone_id
    vpc_cidr = var.vpc_cidr
    web_subnet_cidr = var.web_subnet_cidr
    app_subnet_cidr = var.app_subnet_cidr
    db_subnet_cidr = var.db_subnet_cidr
    web_ip = var.web_ip
    app_ip = var.app_ip
    db_ip = var.db_ip
    bastion_ip = var.bastion_ip
    user_public_ip = var.user_public_ip
    keypair_name = var.keypair_name
    object_storage_access_key_id = var.object_storage_access_key_id
    object_storage_secret_access_key = var.object_storage_secret_access_key
    object_storage_bucket_string = var.object_storage_bucket_string
  }))
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnets,
    samsungcloudplatformv2_security_group_security_group.web_sg,
    samsungcloudplatformv2_vpc_port.web_port,
    samsungcloudplatformv2_vpc_nat_gateway.web_natgateway,
    samsungcloudplatformv2_virtualserver_server.vm_app
  ]
}

########################################################
# DNS 레코드 설정 (Private Domain)
########################################################

resource "samsungcloudplatformv2_dns_record" "www_record" {
  count           = var.private_hosted_zone_id != "" ? 1 : 0
  hosted_zone_id  = var.private_hosted_zone_id
  name            = "www"
  type            = "A"
  ttl             = 300
  records         = [var.web_ip]
  description     = "Web server A record"

  depends_on = [samsungcloudplatformv2_virtualserver_server.vm_web]
}

resource "samsungcloudplatformv2_dns_record" "app_record" {
  count           = var.private_hosted_zone_id != "" ? 1 : 0
  hosted_zone_id  = var.private_hosted_zone_id
  name            = "app"
  type            = "A"
  ttl             = 300
  records         = [var.app_ip]
  description     = "App server A record"

  depends_on = [samsungcloudplatformv2_virtualserver_server.vm_app]
}

resource "samsungcloudplatformv2_dns_record" "db_record" {
  count           = var.private_hosted_zone_id != "" ? 1 : 0
  hosted_zone_id  = var.private_hosted_zone_id
  name            = "db"
  type            = "A"
  ttl             = 300
  records         = [var.db_ip]
  description     = "Database server A record"

  depends_on = [samsungcloudplatformv2_virtualserver_server.vm_db]
}

########################################################
# DNS 레코드 설정 (Public Domain) - 선택사항
########################################################

