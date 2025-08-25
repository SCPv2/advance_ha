#ps1_sysnative
# 실행 로그 경로
$Log = "C:\Windows\Temp\userdata-putty-install.log"
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Log($msg) {
  "[{0}] {1}" -f (Get-Date -Format o), $msg | Out-File -FilePath $Log -Append
}

try {
  Write-Log "=== PuTTY silent install start ==="

  # 네트워크/TLS 설정 (구버전 호환)
  try {
    [System.Net.ServicePointManager]::SecurityProtocol =
      [System.Net.SecurityProtocolType]::Tls12 `
      -bor [System.Net.SecurityProtocolType]::Tls11 `
      -bor [System.Net.SecurityProtocolType]::Tls
  } catch {}

  # MSI 다운로드
  $Url = "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.83-installer.msi"
  $DestDir = "C:\lab-files"
  if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }
  $Out = Join-Path $DestDir "putty-64bit-0.83-installer.msi"

  Write-Log "Downloading: $Url -> $Out"
  Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing

  if (-not (Test-Path $Out) -or (Get-Item $Out).Length -le 0) {
    throw "Downloaded file missing or zero-byte: $Out"
  }

  # 조용히 설치 (UI 없음, 재부팅 금지)
  $msi = $Out
  $logFile = (Join-Path $DestDir "putty-install.log")
  $arg = '/i "{0}" /qn /norestart /L*V "{1}"' -f $msi, $logFile

  Write-Log "Installing MSI silently: msiexec $arg"
  $proc = Start-Process -FilePath msiexec.exe `
                        -ArgumentList $arg `
                        -Verb RunAs `
                        -Wait `
                        -PassThru

  Write-Log ("msiexec exit code: {0}" -f $proc.ExitCode)

  # 0 = 성공, 3010 = 성공(재부팅 필요)
  if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw "msiexec failed with code $($proc.ExitCode)"
  }

  # 설치 확인
  $PuTTY = "C:\Program Files\PuTTY\putty.exe"
  if (Test-Path $PuTTY) {
    Write-Log "PuTTY installed: $PuTTY"
    Write-Log "=== Completed successfully ==="
    exit 0
  } else {
    throw "PuTTY not found after install."
  }

} catch {
  Write-Log ("ERROR: {0}" -f $_.Exception.Message)
  exit 1
}