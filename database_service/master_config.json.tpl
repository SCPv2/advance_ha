{
  "config_metadata": {
    "version": "1.0.0",
    "created": "${timestamp()}",
    "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
    "usage": "This file contains all environment-specific settings for the application deployment"
  },
  "user_input_variables": {
    "_comment": "사용자가 대화형으로 수정 가능한 필수 입력 항목 - variables.tf USER_INPUT 순서",
    "private_domain_name": null,
    "private_hosted_zone_id": null,
    "public_domain_name": null,
    "keypair_name": null,
    "user_public_ip": null,
    "object_storage_access_key_id": null,
    "object_storage_secret_access_key": null,
    "object_storage_bucket_string": null
  },
  "ceweb_required_variables": {
    "_comment": "ceweb 애플리케이션이 master_config.json에서 요구하는 변수들 - variables.tf CEWEB_REQUIRED 순서",
    "app_server_port": null,
    "database_port": null,
    "database_name": null,
    "database_user": null,
    "nginx_port": null,
    "ssl_enabled": null,
    "object_storage_bucket_name": null,
    "object_storage_region": null,
    "certificate_path": null,
    "private_key_path": null,
    "git_repository": null,
    "git_branch": null,
    "timezone": null,
    "web_lb_service_ip": null,
    "app_lb_service_ip": null,
    "node_env": null,
    "session_secret": null,
    "db_type": null,
    "db_max_connections": null,
    "object_storage_private_endpoint": null,
    "object_storage_public_endpoint": null,
    "object_storage_media_folder": null,
    "object_storage_audition_folder": null,
    "auto_deployment": null,
    "rollback_enabled": null,
    "backup_retention_days": null,
    "company_name": null,
    "admin_email": null
  },
  "infrastructure": {
    "_comment": "인프라 구조 정보 (Terraform에서 자동 생성)",
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
      "web_primary_ip": "${web_ip}",
      "web_secondary_ip": "${web_ip2}",
      "app_primary_ip": "${app_ip}",
      "app_secondary_ip": "${app_ip2}",
      "db_primary_ip": "${db_ip}",
      "bastion_ip": "${bastion_ip}"
    }
  },
  "application": {
    "_comment": "애플리케이션 설정 (ceweb_required_variables 참조)",
    "web_server": {
      "nginx_port": "${nginx_port}",
      "ssl_enabled": "${ssl_enabled}",
      "upstream_target": "app.${private_domain_name}:${app_server_port}",
      "fallback_target": "${app_ip2}:${app_server_port}",
      "health_check_path": "/health",
      "api_proxy_path": "/api"
    },
    "app_server": {
      "port": "${app_server_port}",
      "node_env": "${node_env}",
      "database_host": "db.${private_domain_name}",
      "database_port": "${database_port}",
      "database_name": "${database_name}",
      "session_secret": "${session_secret}"
    },
    "database": {
      "type": "${db_type}",
      "port": "${database_port}",
      "max_connections": "${db_max_connections}",
      "shared_buffers": "256MB",
      "effective_cache_size": "1GB"
    }
  },
  "security": {
    "_comment": "보안 설정",
    "firewall": {
      "allowed_public_ips": ["${user_public_ip}/32"],
      "ssh_key_name": "${keypair_name}"
    },
    "ssl": {
      "certificate_path": "${certificate_path}",
      "private_key_path": "${private_key_path}"
    }
  },
  "object_storage": {
    "_comment": "Object Storage 설정 (선택사항)",
    "access_key_id": "${object_storage_access_key_id}",
    "secret_access_key": "${object_storage_secret_access_key}",
    "region": "${object_storage_region}",
    "bucket_name": "${object_storage_bucket_name}",
    "bucket_string": "${object_storage_bucket_string}",
    "private_endpoint": "${object_storage_private_endpoint}",
    "public_endpoint": "${object_storage_public_endpoint}",
    "folders": {
      "media": "${object_storage_media_folder}",
      "audition": "${object_storage_audition_folder}"
    }
  },
  "deployment": {
    "_comment": "배포 설정",
    "git_repository": "${git_repository}",
    "git_branch": "${git_branch}",
    "auto_deployment": "${auto_deployment}",
    "rollback_enabled": "${rollback_enabled}"
  },
  "monitoring": {
    "_comment": "모니터링 설정",
    "log_level": "info",
    "health_check_interval": 30,
    "metrics_enabled": true
  },
  "user_customization": {
    "_comment": "사용자 커스터마이제이션",
    "company_name": "${company_name}",
    "admin_email": "${admin_email}",
    "timezone": "${timezone}",
    "backup_retention_days": "${backup_retention_days}"
  }
}