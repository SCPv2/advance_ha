########################################################
# Output 정의
########################################################

output "deployment_info" {
  description = "Basic deployment information"
  value = {
    vpc_id = values(samsungcloudplatformv2_vpc_vpc.vpcs)[0].id
    vpc_cidr = values(samsungcloudplatformv2_vpc_vpc.vpcs)[0].cidr
    deployment_type = "3-Tier Architecture (Single Server)"
  }
}

output "server_information" {
  description = "Server IP addresses and access information"
  value = {
    bastion = {
      name = var.vm_bastion.name
      private_ip = var.bastion_ip
      public_ip = "Available after deployment"
      os = "Windows Server 2022"
      access = "RDP"
      status = "Ready to deploy"
    }
    web_server = {
      name = var.vm_web.name
      private_ip = var.web_ip
      public_ip = "Available after deployment (PIP2)"
      os = "Rocky Linux 9.4"
      service_port = var.nginx_port
      access = "SSH via bastion or direct via public IP"
      userdata = "userdata_web.sh"
      status = "Ready to deploy"
    }
    app_server = {
      name = var.vm_app.name
      private_ip = var.app_ip
      os = "Rocky Linux 9.4"
      service_port = var.app_server_port
      access = "SSH via bastion"
      userdata = "userdata_app.sh"
      status = "Ready to deploy"
    }
    db_server = {
      name = var.vm_db.name
      private_ip = var.db_ip
      os = "Rocky Linux 9.4"
      service_port = var.database_port
      access = "SSH via bastion"
      userdata = "userdata_db.sh"
      status = "Ready to deploy"
    }
  }
}


output "network_information" {
  description = "Network configuration details"
  value = {
    subnets = {
      web_subnet = {
        name = "Subnet11"
        cidr = "10.1.1.0/24"
        hosts = ["bastion (${var.bastion_ip})", "web (${var.web_ip})"]
      }
      app_subnet = {
        name = "Subnet12"
        cidr = "10.1.2.0/24"
        hosts = ["app (${var.app_ip})"]
      }
      db_subnet = {
        name = "Subnet13"
        cidr = "10.1.3.0/24"
        hosts = ["db (${var.db_ip})"]
      }
    }
    nat_gateways = {
      web_nat = "Available after deployment"
      app_nat = "Available after deployment"
      db_nat = "Available after deployment"
    }
  }
}

output "security_information" {
  description = "Security configuration"
  value = {
    security_groups = ["bastionSG", "webSG", "appSG", "dbSG"]
    firewall_rules = {
      inbound = [
        "RDP to bastion (${var.user_public_ip} -> ${var.bastion_ip}:3389)",
        "HTTP to web (${var.user_public_ip} -> ${var.web_ip}:80)"
      ]
      outbound = [
        "HTTP/HTTPS from all VMs to Internet"
      ]
    }
    ssh_access = "All Linux VMs accessible via bastion host"
  }
}

output "application_status" {
  description = "Application deployment status"
  value = {
    note = "All servers are configured with userdata scripts for automatic installation"
    db_server = {
      service = "PostgreSQL"
      port = var.database_port
      database = var.database_name
      status = "Will be installed automatically via userdata_db.sh"
    }
    app_server = {
      service = "Node.js Application"
      port = var.app_server_port
      status = "Will be installed automatically via userdata_app.sh"
    }
    web_server = {
      service = "Nginx Web Server"
      port = var.nginx_port
      status = "Will be installed automatically via userdata_web.sh"
    }
  }
}

output "next_steps" {
  description = "Next steps after deployment"
  value = [
    "1. Run 'terraform init' to initialize the configuration",
    "2. Run 'terraform plan' to review the deployment plan",
    "3. Run 'terraform apply' to deploy the infrastructure",
    "4. Wait 10-15 minutes for all services to be automatically installed via userdata scripts",
    "5. RDP to bastion server using the public IP (will be shown after deployment)",
    "6. Access web application via: http://[WEB_SERVER_PUBLIC_IP]/ (PIP2 will be shown after deployment)",
    "7. Alternative access via private IP: http://${var.web_ip}/ (from within VPC)",
    "8. Monitor installation logs in /var/log/userdata_*.log on each server"
  ]
}