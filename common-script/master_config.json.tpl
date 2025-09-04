{
  "_variable_classification": {
    "description": "ceweb application variable classification system",
    "categories": {
      "user_input": "Variables that users input interactively during deployment",
      "ceweb_required": "Variables required by ceweb application for business logic and database connections"
    }
  },
  "config_metadata": {
    "version": "2.0.0",
    "created": "${timestamp()}",
    "description": "Samsung Cloud Platform 3-Tier Architecture Master Configuration",
    "usage": "This file contains all environment-specific settings for the application deployment",
    "generator": "deploy_scp_lab_environment.ps1",
    "template_source": "master_config.json.tpl"
  },
  "user_input_variables": {
    "_comment": "Variables that users input interactively during deployment",
    "_source": "variables.tf USER_INPUT category",
    "private_domain_name": "${private_domain_name}",
    "private_hosted_zone_id": "${private_hosted_zone_id}",
    "public_domain_name": "${public_domain_name}",
    "keypair_name": "${keypair_name}",
    "user_public_ip": "${user_public_ip}",
    "object_storage_access_key_id": "${object_storage_access_key_id}",
    "object_storage_secret_access_key": "${object_storage_secret_access_key}",
    "object_storage_bucket_string": "${object_storage_bucket_string}"
  },
  "ceweb_required_variables": {
    "_comment": "Variables required by ceweb application for business logic and functionality",
    "_source": "variables.tf CEWEB_REQUIRED category + load_master_config.sh exports",
    "app_server_port": "3000",
    "database_port": "2866",
    "database_name": "cedb",
    "database_user": "cedbadmin",
    "nginx_port": "80",
    "ssl_enabled": false,
    "object_storage_bucket_name": "ceweb",
    "object_storage_region": "kr-west1",
    "git_repository": "https://github.com/SCPv2/ceweb.git",
    "git_branch": "main",
    "timezone": "Asia/Seoul",
    "web_lb_service_ip": "10.1.1.100",
    "app_lb_service_ip": "10.1.2.100",
    "node_env": "production",
    "session_secret": "your-secret-key-change-in-production",
    "db_type": "postgresql",
    "db_max_connections": 100,
    "object_storage_private_endpoint": "https://object-store.private.kr-west1.e.samsungsdscloud.com",
    "object_storage_public_endpoint": "https://object-store.kr-west1.e.samsungsdscloud.com",
    "object_storage_media_folder": "media/img",
    "object_storage_audition_folder": "files/audition",
    "auto_deployment": true,
    "rollback_enabled": true,
    "backup_retention_days": 30,
    "company_name": "Creative Energy",
    "admin_email": "ars4mundus@gmail.com",
    "web_primary_ip": "${web_ip}",
    "web_secondary_ip": "${web_ip2}",
    "app_primary_ip": "${app_ip}",
    "app_secondary_ip": "${app_ip2}",
    "db_primary_ip": "${db_ip}",
    "bastion_ip": "${bastion_ip}",
    "vpc_cidr": "${vpc_cidr}",
    "web_subnet_cidr": "${web_subnet_cidr}",
    "app_subnet_cidr": "${app_subnet_cidr}",
    "db_subnet_cidr": "${db_subnet_cidr}",
    "_database_connection": {
      "database_password": "cedbadmin123",
      "db_ssl_enabled": false,
      "db_pool_min": 20,
      "db_pool_max": 100,
      "db_pool_idle_timeout": 30000,
      "db_pool_connection_timeout": 60000
    }
  }
}