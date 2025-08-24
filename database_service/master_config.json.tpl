{
  "config_metadata": {
    "version": "1.0.0",
    "created": "${timestamp()}",
    "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
    "usage": "This file contains all environment-specific settings for the application deployment"
  },
  "infrastructure": {
    "domain": {
      "public_domain_name": "${public_domain_name}",
      "private_domain_name": "${private_domain_name}",
      "private_hosted_zone_id": "${private_hosted_zone_id}"
    },
    "network": {
      "vpc_cidr": "${vpc_cidr}",
      "web_subnet_cidr": "${web_subnet_cidr}",
      "app_subnet_cidr": "${app_subnet_cidr}",
      "db_subnet_cidr": "${db_subnet_cidr}"
    },
    "load_balancer": {
      "web_lb_service_ip": "${web_lb_service_ip}",
      "app_lb_service_ip": "${app_lb_service_ip}"
    },
    "servers": {
      "web_primary_ip": "${web_primary_ip}",
      "web_secondary_ip": "${web_secondary_ip}",
      "app_primary_ip": "${app_primary_ip}",
      "app_secondary_ip": "${app_secondary_ip}",
      "db_primary_ip": "${db_primary_ip}",
      "bastion_ip": "${bastion_ip}"
    }
  },
  "application": {
    "web_server": {
      "nginx_port": 80,
      "ssl_enabled": false,
      "upstream_target": "app.${private_domain_name}:3000",
      "fallback_target": "${app_secondary_ip}:3000",
      "health_check_path": "/health",
      "api_proxy_path": "/api"
    },
    "app_server": {
      "port": 3000,
      "node_env": "production",
      "database_host": "db.${private_domain_name}",
      "database_port": 2866,
      "database_name": "creative_energy_db",
      "session_secret": "your-secret-key-change-in-production"
    },
    "database": {
      "type": "postgresql",
      "port": 2866,
      "max_connections": 100,
      "shared_buffers": "256MB",
      "effective_cache_size": "1GB"
    }
  },
  "security": {
    "firewall": {
      "allowed_public_ips": [
        "${user_public_ip}/32"
      ],
      "ssh_key_name": "${keypair_name}"
    },
    "ssl": {
      "certificate_path": "/etc/ssl/certs/certificate.crt",
      "private_key_path": "/etc/ssl/private/private.key"
    }
  },
  "object_storage": {
    "access_key_id": "${object_storage_access_key_id}",
    "secret_access_key": "${object_storage_secret_access_key}",
    "region": "kr-west1",
    "bucket_name": "ceweb",
    "bucket_string": "${object_storage_bucket_string}",
    "private_endpoint": "https://object-store.private.kr-west1.e.samsungsdscloud.com",
    "public_endpoint": "https://object-store.kr-west1.e.samsungsdscloud.com",
    "folders": {
      "media": "media/img",
      "audition": "files/audition"
    }
  },
  "deployment": {
    "git_repository": "https://github.com/SCPv2/ceweb.git",
    "git_branch": "main",
    "auto_deployment": true,
    "rollback_enabled": true
  },
  "monitoring": {
    "log_level": "info",
    "health_check_interval": 30,
    "metrics_enabled": true
  },
  "user_customization": {
    "_comment": "아래 섹션은 사용자가 직접 수정하는 영역입니다",
    "company_name": "Creative Energy",
    "admin_email": "admin@company.com",
    "timezone": "Asia/Seoul",
    "backup_retention_days": 30
  }
}