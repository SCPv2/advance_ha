# Simple test script
Write-Host "Testing variables from variables.tf..."

# Test variables loading
$variables = @{}
$variables.public_domain_name = "test123"
$variables.private_domain_name = "test456" 
$variables.user_public_ip = "1.2.3.4"
$variables.keypair_name = "testkey"
$variables.private_hosted_zone_id = "testzone"

Write-Host "Variables loaded successfully"

# Test Update-UserdataFiles function
. .\deploy_scp_lab_environment.ps1
Write-Host "Script loaded, calling Update-UserdataFiles..."

Update-UserdataFiles $variables
Write-Host "Update complete!"