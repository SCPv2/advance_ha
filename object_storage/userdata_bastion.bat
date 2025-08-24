@echo off
REM Creative Energy Bastion Server 초기화 스크립트
REM Windows Server 2022 Standard 기본 설정 및 필수 도구 설치
REM Samsung Cloud Platform용 Terraform UserData 스크립트

REM 로그 파일 설정
set "LogFile=C:\Windows\Temp\bastion_init.log"
echo ==================== >> "%LogFile%" 2>&1
echo Bastion Server 초기화 시작: %date% %time% >> "%LogFile%" 2>&1
echo ==================== >> "%LogFile%" 2>&1

echo [1/7] Windows 기본 설정 구성 중... >> "%LogFile%" 2>&1

REM 시간대 설정 (한국 시간)
tzutil /s "Korea Standard Time" >> "%LogFile%" 2>&1
echo 시간대를 한국 표준시로 설정했습니다. >> "%LogFile%" 2>&1

REM Windows 업데이트 서비스 설정
sc config wuauserv start= demand >> "%LogFile%" 2>&1
echo Windows Update 서비스를 수동으로 설정했습니다. >> "%LogFile%" 2>&1

echo [2/7] Chocolatey 패키지 관리자 설치 중... >> "%LogFile%" 2>&1

REM PowerShell 실행 정책 설정
powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force" >> "%LogFile%" 2>&1

REM Chocolatey 설치
powershell -Command "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" >> "%LogFile%" 2>&1

REM PATH 환경변수 새로고침
set "PATH=%PATH%;C:\ProgramData\chocolatey\bin"
echo Chocolatey 설치가 완료되었습니다. >> "%LogFile%" 2>&1

echo [3/7] PuTTY SSH 클라이언트 설치 중... >> "%LogFile%" 2>&1

REM PuTTY 설치 시도
choco install putty -y --force >> "%LogFile%" 2>&1

REM PuTTY 설치 확인 및 직접 다운로드
if not exist "C:\ProgramData\chocolatey\lib\putty.portable\tools\putty.exe" (
    echo Chocolatey PuTTY 설치 실패, 직접 다운로드 시도... >> "%LogFile%" 2>&1
    
    REM 직접 다운로드 디렉토리 생성
    if not exist "C:\Tools\PuTTY" mkdir "C:\Tools\PuTTY" >> "%LogFile%" 2>&1
    
    REM PuTTY 다운로드
    powershell -Command "Invoke-WebRequest -Uri 'https://the.earth.li/~sgtatham/putty/latest/w64/putty.exe' -OutFile 'C:\Tools\PuTTY\putty.exe'" >> "%LogFile%" 2>&1
    
    REM PuTTYgen 다운로드
    powershell -Command "Invoke-WebRequest -Uri 'https://the.earth.li/~sgtatham/putty/latest/w64/puttygen.exe' -OutFile 'C:\Tools\PuTTY\puttygen.exe'" >> "%LogFile%" 2>&1
    
    REM Pageant 다운로드
    powershell -Command "Invoke-WebRequest -Uri 'https://the.earth.li/~sgtatham/putty/latest/w64/pageant.exe' -OutFile 'C:\Tools\PuTTY\pageant.exe'" >> "%LogFile%" 2>&1
    
    REM PATH에 추가
    setx PATH "%PATH%;C:\Tools\PuTTY" /M >> "%LogFile%" 2>&1
    echo PuTTY 직접 설치 완료: C:\Tools\PuTTY\ >> "%LogFile%" 2>&1
) else (
    echo PuTTY Chocolatey 설치가 완료되었습니다. >> "%LogFile%" 2>&1
)

echo [4/7] 기본 관리 도구 설치 중... >> "%LogFile%" 2>&1

REM Git 설치
choco install git -y >> "%LogFile%" 2>&1
echo Git 설치 완료 >> "%LogFile%" 2>&1

REM Notepad++ 설치
choco install notepadplusplus -y >> "%LogFile%" 2>&1
echo Notepad++ 설치 완료 >> "%LogFile%" 2>&1

REM 7-Zip 설치
choco install 7zip -y >> "%LogFile%" 2>&1
echo 7-Zip 설치 완료 >> "%LogFile%" 2>&1

REM Google Chrome 설치
choco install googlechrome -y >> "%LogFile%" 2>&1
echo Google Chrome 설치 완료 >> "%LogFile%" 2>&1

echo [5/7] PowerShell 모듈 설치 중... >> "%LogFile%" 2>&1

REM Posh-SSH 모듈 설치
powershell -Command "Install-Module -Name Posh-SSH -Force -AllowClobber" >> "%LogFile%" 2>&1
echo Posh-SSH 모듈 설치 완료 >> "%LogFile%" 2>&1

echo [6/7] 바탕화면 바로가기 생성 중... >> "%LogFile%" 2>&1

REM 바탕화면 경로 설정
set "DesktopPath=C:\Users\Administrator\Desktop"

REM PuTTY 바로가기 생성
if exist "C:\ProgramData\chocolatey\lib\putty.portable\tools\putty.exe" (
    powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DesktopPath%\PuTTY.lnk'); $Shortcut.TargetPath = 'C:\ProgramData\chocolatey\lib\putty.portable\tools\putty.exe'; $Shortcut.Save()" >> "%LogFile%" 2>&1
    echo PuTTY 바로가기: Chocolatey 버전 사용 >> "%LogFile%" 2>&1
) else (
    powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DesktopPath%\PuTTY.lnk'); $Shortcut.TargetPath = 'C:\Tools\PuTTY\putty.exe'; $Shortcut.Save()" >> "%LogFile%" 2>&1
    echo PuTTY 바로가기: 직접 설치 버전 사용 >> "%LogFile%" 2>&1
)

REM PuTTYgen 바로가기 생성
if exist "C:\ProgramData\chocolatey\lib\putty.portable\tools\puttygen.exe" (
    powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DesktopPath%\PuTTYgen.lnk'); $Shortcut.TargetPath = 'C:\ProgramData\chocolatey\lib\putty.portable\tools\puttygen.exe'; $Shortcut.Save()" >> "%LogFile%" 2>&1
) else (
    powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DesktopPath%\PuTTYgen.lnk'); $Shortcut.TargetPath = 'C:\Tools\PuTTY\puttygen.exe'; $Shortcut.Save()" >> "%LogFile%" 2>&1
)

REM Pageant 바로가기 생성
if exist "C:\ProgramData\chocolatey\lib\putty.portable\tools\pageant.exe" (
    powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DesktopPath%\Pageant.lnk'); $Shortcut.TargetPath = 'C:\ProgramData\chocolatey\lib\putty.portable\tools\pageant.exe'; $Shortcut.Save()" >> "%LogFile%" 2>&1
) else (
    powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DesktopPath%\Pageant.lnk'); $Shortcut.TargetPath = 'C:\Tools\PuTTY\pageant.exe'; $Shortcut.Save()" >> "%LogFile%" 2>&1
)

echo PuTTY, PuTTYgen, Pageant 바탕화면 바로가기 생성 완료 >> "%LogFile%" 2>&1

echo [7/7] 네트워크 및 보안 설정 구성 중... >> "%LogFile%" 2>&1

REM Windows Firewall에서 RDP 허용
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes >> "%LogFile%" 2>&1
echo RDP 방화벽 규칙 활성화 완료 >> "%LogFile%" 2>&1

REM RDP 연결 허용 설정
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >> "%LogFile%" 2>&1
echo RDP 연결 허용 설정 완료 >> "%LogFile%" 2>&1

REM 완료 마커 파일 생성
echo Bastion Server 초기화 완료 > "%DesktopPath%\Bastion_Server_Ready.txt"
echo ========================= >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 완료 시간: %date% %time% >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 서버 역할: Windows Bastion Server >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 설치된 도구: >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - PuTTY SSH Client (바탕화면 바로가기 또는 C:\Tools\PuTTY\) >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - PuTTYgen (키 변환 도구) >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - Pageant (SSH 에이전트) >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - Git >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - Notepad++ >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - 7-Zip >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - Google Chrome >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - PowerShell Posh-SSH 모듈 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo. >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 사용 방법: >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 1. PuTTYgen으로 키페어 파일(.pem)을 .ppk 형식으로 변환 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 2. Pageant 실행 후 변환된 .ppk 키를 로드 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 3. PuTTY로 SSH 연결: rocky@내부IP (예: rocky@10.1.1.111) >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 4. 포트: 22, Pageant가 자동으로 인증 처리 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 5. 다중 서버 접속 시 Pageant가 키 관리 자동화 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo. >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo 내부 서버 IP 주소: >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - Web Server 1: 10.1.1.111 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - Web Server 2: 10.1.1.112 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - App Server 1: 10.1.2.121 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - App Server 2: 10.1.2.122 >> "%DesktopPath%\Bastion_Server_Ready.txt"
echo - DB Server: 10.1.3.131 >> "%DesktopPath%\Bastion_Server_Ready.txt"

echo ==================== >> "%LogFile%" 2>&1
echo Bastion Server 초기화 완료: %date% %time% >> "%LogFile%" 2>&1
echo 설치된 도구: PuTTY, PuTTYgen, Pageant, Git, Notepad++, 7-Zip, Chrome >> "%LogFile%" 2>&1
echo 완료 마커: %DesktopPath%\Bastion_Server_Ready.txt >> "%LogFile%" 2>&1
echo ==================== >> "%LogFile%" 2>&1

echo Bastion initialization completed successfully! >> "%LogFile%" 2>&1