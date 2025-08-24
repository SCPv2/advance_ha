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
      name = samsungcloudplatformv2_virtualserver_server.vm_bastion.name
      private_ip = var.bastion_ip
      public_ip = samsungcloudplatformv2_vpc_publicip.publicips["PIP1"].address
      os = "Windows Server 2022"
      access = "RDP"
    }
    web_server = {
      name = samsungcloudplatformv2_virtualserver_server.vm_web.name
      private_ip = var.web_ip
      os = "Rocky Linux 9.4"
      service_port = 80
      access = "SSH via bastion"
      ready_file = "z_ready2install_go2web-server"
    }
    app_server = {
      name = samsungcloudplatformv2_virtualserver_server.vm_app.name
      private_ip = var.app_ip
      os = "Rocky Linux 9.4"
      service_port = 3000
      access = "SSH via bastion"
      ready_file = "z_ready2install_go2app-server"
    }
    db_server = {
      name = samsungcloudplatformv2_virtualserver_server.vm_db.name
      private_ip = var.db_ip
      os = "Rocky Linux 9.4"
      service_port = 2866
      access = "SSH via bastion"
      ready_file = "z_ready2install_go2db-server"
    }
  }
}

output "dns_information" {
  description = "DNS configuration"
  value = {
    private_domain = var.private_domain_name
    public_domain = var.public_domain_name
    dns_records = {
      www = "www.${var.private_domain_name} -> ${var.web_ip}"
      app = "app.${var.private_domain_name} -> ${var.app_ip}"
      db = "db.${var.private_domain_name} -> ${var.db_ip}"
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
      web_nat = samsungcloudplatformv2_vpc_publicip.publicips["PIP2"].address
      app_nat = samsungcloudplatformv2_vpc_publicip.publicips["PIP3"].address
      db_nat = samsungcloudplatformv2_vpc_publicip.publicips["PIP4"].address
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

output "installation_commands" {
  description = "Manual installation commands to run on each server"
  value = {
    installation_order = ["DB Server", "App Server", "Web Server"]
    db_server = {
      ssh_command = "ssh -i your-key.pem rocky@${var.db_ip} # via bastion"
      install_command = "cd /home/rocky/ceweb/db-server/vm_db && sudo bash install_postgresql_vm.sh"
      ready_check = "cat /home/rocky/z_ready2install_go2db-server"
    }
    app_server = {
      ssh_command = "ssh -i your-key.pem rocky@${var.app_ip} # via bastion"
      install_command = "cd /home/rocky/ceweb/app-server && sudo bash install_app_server.sh"
      ready_check = "cat /home/rocky/z_ready2install_go2app-server"
    }
    web_server = {
      ssh_command = "ssh -i your-key.pem rocky@${var.web_ip} # via bastion"
      install_command = "cd /home/rocky/ceweb/web-server && sudo bash install_web_server.sh"
      ready_check = "cat /home/rocky/z_ready2install_go2web-server"
    }
  }
}

output "next_steps" {
  description = "Next steps after deployment"
  value = [
    "1. Wait 5-10 minutes for system preparation to complete",
    "2. RDP to bastion server using: ${samsungcloudplatformv2_vpc_publicip.publicips["PIP1"].address}",
    "3. SSH to each server and check ready files in /home/rocky/",
    "4. Install services in order: DB -> App -> Web",
    "5. Access web application via: http://${var.web_ip}/ (after installation)",
    "6. Monitor logs in /var/log/userdata_*.log on each server"
  ]
}