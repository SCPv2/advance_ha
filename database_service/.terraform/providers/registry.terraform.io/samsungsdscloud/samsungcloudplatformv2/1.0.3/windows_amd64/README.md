# Terraform Provider for Samsung Cloud Platform V2

## Directory structure
  - docs : Auto-generated documentation 
  - examples : Example samsungcloudplatformv2 terraform files for testing & documentation 
  - internal : Internal functions 
  - samsungcloudplatform : Samsungcloudplatformv2 terraform provider source code 
  - tools : Tool modules

## Build Requirements
Reference development environment 
  - Terraform 1.1.11 
  - Go v1.22.5

Prepare third-party libraries : go mod tidy

## Setup credentials

### Create local setting file
Create .scpconf directory in your OS account home


```
cd %USERPROFILE%
mkdir ".scpconf"
```

Create config.json and credentials.json in .scpconf directory

### Add Samsungcloudplatform configuration
Insert following parameters in ```.scpconf/config.json``` file
```
{
    "auth-url": "https://iam.dev2.samsungsdscloud.com/v1",
    "default-region": "kr-west1"
}
```

### auth-url example

| **Environment**     | **env value** | **Example Service URL**              |
|---------------|---------------|--------------------------------------|
| for Samsung   | s             | https://iam.s.samsungsdscloud.com/v1 |
| for Sovereign | g             | https://iam.g.samsungsdscloud.com/v1 |


### Add your credentials
Insert following parameters in ```.scpconf/credentials.json``` file
```
{
    "access-key": "xxxxxxxxxxxxxx",
    "secret-key": "xxxxxxxxxxxxxx"
}
```

## Schema

### Optional

- `access_key` (String) Access key for calling samsungcloudplatformv2 API. May also be provided via SCP_TF_ACCESS_KEY environment variable.
- `auth_url` (String) Authentication URL for calling samsungcloudplatformv2 API. May also be provided via SCP_TF_AUTH_URL environment variable.
- `default_region` (String) Default region configuration for calling samsungcloudplatformv2 API. May also be provided via SCP_TF_DEFAULT_REGION environment variable.
- `secret_key` (String) Secret key for calling samsungcloudplatformv2 API. May also be provided via SCP_TF_SECRET_KEY environment variable.