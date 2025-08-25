# Variable-Management.ps1
# Samsung Cloud Platform v2 - Variable Management Module
# Handles all variable processing, validation, and management operations

# Initialize script-level variables for caching
$script:variablesContent = $null
$script:masterConfigContent = $null
$script:allVariablesCache = $null
$script:variablesCacheValid = $false
$script:userInputCache = $null
$script:userInputCacheValid = $false
$script:cewebRequiredCache = $null
$script:cewebRequiredCacheValid = $false
$script:terraformInfraCache = $null
$script:terraformInfraCacheValid = $false

#region Variable Parsing and JSON Conversion
function ConvertTo-VariablesJson {
    param(
        [string]$VariablesTfPath = "variables.tf",
        [string]$OutputJsonPath = "variables.json"
    )
    
    if ($global:ValidationMode) {
        Write-Host "🔄 Parsing variables.tf to JSON..." -ForegroundColor Cyan
    }
    $parseStartTime = Get-Date
    
    if (-not (Test-Path $VariablesTfPath)) {
        throw "$VariablesTfPath file not found."
    }
    
    # Read variables.tf content
    $content = Get-Content $VariablesTfPath -Raw
    
    # Initialize variables structure
    $variables = @{
        USER_INPUT = @{}
        CEWEB_REQUIRED = @{}
        TERRAFORM_INFRA = @{}
        metadata = @{
            parsed_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            source_file = $VariablesTfPath
            total_variables = 0
        }
    }
    
    # Helper function to extract default value from variable body
    function Extract-DefaultValue {
        param([string]$VarBody)
        
        if ($VarBody -notmatch 'default\s*=') {
            return $null
        }
        
        $lines = $VarBody -split '\r?\n'
        $defaultStartIndex = -1
        
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -match '^\s*default\s*=\s*(.*)') {
                $defaultStartIndex = $i
                break
            }
        }
        
        if ($defaultStartIndex -eq -1) {
            return $null
        }
        
        # Extract default value handling multiline structures
        $defaultPart = $matches[1]
        $defaultPart = $defaultPart.Trim()
        
        # Handle single line values
        if ($defaultPart -match '^"([^"]*)"$' -or $defaultPart -match '^([^{}\[\]]+)$') {
            return $defaultPart.Trim('"')
        }
        
        # Handle multiline structures
        $braceCount = 0
        $bracketCount = 0
        $fullDefaultValue = $defaultPart
        
        for ($j = $defaultStartIndex + 1; $j -lt $lines.Length; $j++) {
            $line = $lines[$j].Trim()
            $fullDefaultValue += "`n" + $line
            
            $openBraces = @($line.ToCharArray() | Where-Object { $_ -eq '{' })
            $closeBraces = @($line.ToCharArray() | Where-Object { $_ -eq '}' })
            $openBrackets = @($line.ToCharArray() | Where-Object { $_ -eq '[' })
            $closeBrackets = @($line.ToCharArray() | Where-Object { $_ -eq ']' })
            
            $braceCount += $openBraces.Count
            $braceCount -= $closeBraces.Count
            $bracketCount += $openBrackets.Count
            $bracketCount -= $closeBrackets.Count
            
            if ($braceCount -eq 0 -and $bracketCount -eq 0 -and $line.EndsWith('}')) {
                break
            }
        }
        
        return $fullDefaultValue.Trim()
    }
    
    # Parse variable blocks
    $variablePattern = 'variable\s+"([^"]+)"\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}'
    $matches = [regex]::Matches($content, $variablePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value.Trim()
        $varBody = $match.Groups[2].Value.Trim()
        
        # Extract description
        $descMatch = [regex]::Match($varBody, 'description\s*=\s*"([^"]*)"')
        $description = if ($descMatch.Success) { $descMatch.Groups[1].Value.Trim() } else { "" }
        
        # Extract default value
        $defaultValue = Extract-DefaultValue $varBody
        
        # Categorize based on tags in comments
        $category = "TERRAFORM_INFRA"  # Default
        if ($varBody -match '\[USER_INPUT\]') {
            $category = "USER_INPUT"
        }
        elseif ($varBody -match '\[CEWEB_REQUIRED\]') {
            $category = "CEWEB_REQUIRED"
        }
        
        $variables[$category][$varName] = @{
            description = $description
            default = $defaultValue
            type = if ($varBody -match 'type\s*=\s*([^\n]+)') { $matches[1].Trim() } else { "string" }
        }
    }
    
    # Update metadata
    $totalVars = $variables.USER_INPUT.Count + $variables.CEWEB_REQUIRED.Count + $variables.TERRAFORM_INFRA.Count
    $variables.metadata.total_variables = $totalVars
    
    # Save to JSON file
    $variables | ConvertTo-Json -Depth 10 | Out-File $OutputJsonPath -Encoding UTF8
    
    if ($global:ValidationMode) {
        $parseTime = (Get-Date) - $parseStartTime
        Write-Host "✓ Parsed $totalVars variables in $($parseTime.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
        Write-Host "  - USER_INPUT: $($variables.USER_INPUT.Count)" -ForegroundColor White
        Write-Host "  - CEWEB_REQUIRED: $($variables.CEWEB_REQUIRED.Count)" -ForegroundColor White  
        Write-Host "  - TERRAFORM_INFRA: $($variables.TERRAFORM_INFRA.Count)" -ForegroundColor White
        Write-Host ""
    }
}

function Get-VariablesFromJson {
    param(
        [string]$JsonPath = "variables.json",
        [string]$Category = "ALL"
    )
    
    if (-not (Test-Path $JsonPath)) {
        throw "$JsonPath file not found. Run ConvertTo-VariablesJson first."
    }
    
    $jsonContent = Get-Content $JsonPath -Raw | ConvertFrom-Json
    
    if ($Category -eq "ALL") {
        $result = @{}
        foreach ($cat in @("USER_INPUT", "CEWEB_REQUIRED", "TERRAFORM_INFRA")) {
            $categoryVars = $jsonContent.$cat
            foreach ($varName in $categoryVars.PSObject.Properties.Name) {
                $result[$varName] = $categoryVars.$varName.default
            }
        }
        return $result
    } else {
        $result = @{}
        $categoryVars = $jsonContent.$Category
        foreach ($varName in $categoryVars.PSObject.Properties.Name) {
            $result[$varName] = $categoryVars.$varName.default
        }
        return $result
    }
}
#endregion

#region Terraform Variable Operations
function Get-TerraformVariable {
    param($VarName)
    try {
        $result = echo "var.$VarName" | terraform console 2>$null
        if ($LASTEXITCODE -eq 0 -and $result -and $result -ne "null") {
            $cleanResult = $result.Trim().Trim('"')
            return $cleanResult
        }
        return $null
    } catch {
        return $null
    }
}

function Get-TerraformVariablesBatch {
    param([string[]]$VarNames)
    
    $result = @{}
    foreach ($varName in $VarNames) {
        $value = Get-TerraformVariable $varName
        if ($null -ne $value) {
            $result[$varName] = $value
        }
    }
    return $result
}

function Get-VariablesByCategory {
    param(
        [ValidateSet("USER_INPUT", "CEWEB_REQUIRED", "TERRAFORM_INFRA")]
        [string]$Category
    )
    
    if (-not (Test-Path "variables.json")) {
        ConvertTo-VariablesJson | Out-Null
    }
    
    $jsonData = Get-Content "variables.json" -Raw | ConvertFrom-Json
    $categoryVars = $jsonData.$Category
    $varNames = $categoryVars.PSObject.Properties.Name
    
    if ($varNames.Count -eq 0) {
        return @{}
    }
    
    return Get-TerraformVariablesBatch $varNames
}

function Update-VariableInFile {
    param(
        [string]$FilePath = "variables.tf",
        [string]$VariableName,
        [string]$NewValue
    )
    
    $content = Get-Content $FilePath -Raw
    $pattern = "(variable\s+`"$VariableName`"\s*\{[^}]*default\s*=\s*)(`"[^`"]*`"|[^`n\r}]+)"
    $replacement = "`${1}`"$NewValue`""
    $newContent = $content -replace $pattern, $replacement
    
    Set-Content $FilePath $newContent -Encoding UTF8
    return ($content -ne $newContent)
}
#endregion

#region Variable Cache Management
function Get-AllVariablesForDeployment {
    if ($global:ValidationMode) {
        Write-Host "🔄 Loading all variables for deployment..." -ForegroundColor Cyan
    }
    
    # Load from JSON if not cached
    if (-not $script:variablesCacheValid) {
        $script:allVariablesCache = Get-VariablesFromJson
        $script:variablesCacheValid = $true
    }
    
    # Get current terraform values
    $userInputVars = Get-VariablesFromJson -Category "USER_INPUT"
    $cewebRequiredVars = Get-VariablesFromJson -Category "CEWEB_REQUIRED" 
    $terraformInfraVars = Get-VariablesFromJson -Category "TERRAFORM_INFRA"
    
    # Combine all variables
    $allVars = @{}
    foreach ($var in $userInputVars.GetEnumerator()) {
        $terraformValue = Get-TerraformVariable $var.Key
        $allVars[$var.Key] = if ($terraformValue) { $terraformValue } else { $var.Value }
    }
    foreach ($var in $cewebRequiredVars.GetEnumerator()) {
        $terraformValue = Get-TerraformVariable $var.Key
        $allVars[$var.Key] = if ($terraformValue) { $terraformValue } else { $var.Value }
    }
    foreach ($var in $terraformInfraVars.GetEnumerator()) {
        $terraformValue = Get-TerraformVariable $var.Key
        $allVars[$var.Key] = if ($terraformValue) { $terraformValue } else { $var.Value }
    }
    
    if ($global:ValidationMode) {
        Write-Host "✓ Loaded $($allVars.Count) variables" -ForegroundColor Green
    }
    
    return $allVars
}

function Reset-VariablesCache {
    $script:variablesContent = $null
    $script:masterConfigContent = $null
    $script:allVariablesCache = $null
    $script:variablesCacheValid = $false
    $script:userInputCache = $null
    $script:userInputCacheValid = $false
    $script:cewebRequiredCache = $null
    $script:cewebRequiredCacheValid = $false
    $script:terraformInfraCache = $null
    $script:terraformInfraCacheValid = $false
    
    if ($global:ValidationMode) {
        Write-Host "✓ Variable cache cleared" -ForegroundColor Yellow
    }
}

function Update-VariableInCache {
    param([string]$VarName, [string]$NewValue)
    
    if ($script:allVariablesCache) {
        $script:allVariablesCache[$VarName] = $NewValue
    }
}
#endregion

#region Variable Consistency and Validation
function Get-MasterConfigVariables {
    param([string]$Category)
    
    if (-not (Test-Path "scripts/master_config.json.tpl")) {
        return @{}
    }
    
    $content = Get-Content "scripts/master_config.json.tpl" -Raw
    $pattern = '\$\{([^}]+)\}'
    $matches = [regex]::Matches($content, $pattern)
    
    $variables = @{}
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value.Trim()
        $variables[$varName] = $true
    }
    
    return $variables.Keys
}

function Test-VariableConsistency {
    param([string]$Category)
    
    if ($global:ValidationMode) {
        Write-Host "🔍 Testing variable consistency for ${Category}..." -ForegroundColor Cyan
    }
    
    $variablesTfVars = Get-VariablesByCategory $Category
    $masterConfigVars = Get-MasterConfigVariables $Category
    
    $inconsistencies = @()
    
    # Check for variables in master_config.json.tpl but not in variables.tf
    foreach ($masterVar in $masterConfigVars) {
        if (-not $variablesTfVars.ContainsKey($masterVar)) {
            $inconsistencies += "Missing in variables.tf: $masterVar"
        }
    }
    
    # Check for variables in variables.tf but not used in master_config.json.tpl
    foreach ($tfVar in $variablesTfVars.Keys) {
        if ($tfVar -notin $masterConfigVars) {
            $inconsistencies += "Unused in master_config.json.tpl: $tfVar"
        }
    }
    
    if ($inconsistencies.Count -gt 0 -and $global:ValidationMode) {
        Write-Host "⚠️  Found $($inconsistencies.Count) inconsistencies in ${Category}:" -ForegroundColor Yellow
        foreach ($inconsistency in $inconsistencies) {
            Write-Host "  - $inconsistency" -ForegroundColor Gray
        }
        Write-Host ""
    }
    elseif ($global:ValidationMode) {
        Write-Host "✓ No inconsistencies found in ${Category}" -ForegroundColor Green
    }
    
    return $inconsistencies
}
#endregion