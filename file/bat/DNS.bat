@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
echo === NETWORK TUNING START ===
echo.
fltmc >nul 2>&1 || (echo Run as Admin! & pause & exit /b 1)
echo [OK] Admin
set "IDX="
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceType -in @(6,71,144) } | Sort-Object {if($_.MediaType -eq '802.3'){0}else{1}} | Select-Object -First 1).InterfaceIndex" 2^>nul`) do set "IDX=%%a"
if not defined IDX for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).InterfaceIndex" 2^>nul`) do set "IDX=%%a"
if not defined IDX set "IDX=0"
echo [OK] AdapterIndex=%IDX%
ipconfig /flushdns >nul 2>&1
echo [OK] FlushDNS
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global windowsscaling=enabled >nul 2>&1
netsh int tcp set global sack=enabled >nul 2>&1
netsh int tcp set global fack=enabled >nul 2>&1
netsh int tcp set global fastretransmit=enabled >nul 2>&1
netsh int tcp set global maxsynretransmissions=4 >nul 2>&1
netsh int tcp set global initialRto=300 >nul 2>&1
netsh int tcp set global rss=enabled >nul 2>&1
netsh int tcp set global dca=enabled >nul 2>&1
netsh int tcp set global fastopen=enabled >nul 2>&1
netsh int tcp set global congestionprovider=cubic >nul 2>&1
netsh int tcp set supplemental internet congestionprovider=cubic >nul 2>&1
echo [OK] TCP base parameters
set "BW_MODE=medium"
if not "%IDX%"=="0" for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "$s=(Get-NetAdapter -InterfaceIndex %IDX% -ErrorAction SilentlyContinue).Speed; if($s -gt 1000000000){'large'}elseif($s -gt 100000000){'medium'}else{'small'}" 2^>nul`) do set "BW_MODE=%%a"
echo.
echo Bandwidth mode detected: %BW_MODE%
echo.
if "%BW_MODE%"=="large" goto BW_LARGE
if "%BW_MODE%"=="small" goto BW_SMALL
goto BW_MEDIUM
:BW_LARGE
echo Applying HIGH-BANDWIDTH profile...
netsh int tcp set global rsc=enabled >nul 2>&1
netsh int tcp set global timestamps=enabled >nul 2>&1
netsh int tcp set global ecncapability=enabled >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 10485760 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v InitialCongestionWindow /t REG_DWORD /d 10 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort /t REG_DWORD /d 65534 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNumConnections /t REG_DWORD /d 16777214 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f >nul 2>&1
if not "%IDX%"=="0" powershell -NoProfile -Command "$n=(Get-NetAdapter -InterfaceIndex %IDX% -ErrorAction SilentlyContinue).Name; if($n){ foreach($k in @('*LsoV2IPv4','*LsoV2IPv6','*LsoV1IPv4')){ try{ Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword $k -DisplayValue 'Enabled' -ErrorAction Stop }catch{} } }" >nul 2>&1
echo [OK] High-bandwidth profile applied
goto BW_DONE
:BW_SMALL
echo Applying LOW-BANDWIDTH profile...
netsh int tcp set global rsc=disabled >nul 2>&1
netsh int tcp set global timestamps=disabled >nul 2>&1
netsh int tcp set global ecncapability=disabled >nul 2>&1
netsh int tcp set global initialRto=200 >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 262144 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v InitialCongestionWindow /t REG_DWORD /d 4 /f >nul 2>&1
if not "%IDX%"=="0" powershell -NoProfile -Command "$n=(Get-NetAdapter -InterfaceIndex %IDX% -ErrorAction SilentlyContinue).Name; if($n){ foreach($k in @('*LsoV2IPv4','*LsoV2IPv6','*LsoV1IPv4')){ try{ Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword $k -DisplayValue 'Disabled' -ErrorAction Stop }catch{} }; try{ Set-NetAdapterPowerManagement -Name $n -SelectiveSuspend Disabled -ErrorAction SilentlyContinue }catch{} }" >nul 2>&1
echo [OK] Low-bandwidth profile applied
goto BW_DONE
:BW_MEDIUM
echo Applying MEDIUM-BANDWIDTH profile...
netsh int tcp set global rsc=enabled >nul 2>&1
netsh int tcp set global timestamps=enabled >nul 2>&1
netsh int tcp set global ecncapability=enabled >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 1048576 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v InitialCongestionWindow /t REG_DWORD /d 6 /f >nul 2>&1
if not "%IDX%"=="0" powershell -NoProfile -Command "$n=(Get-NetAdapter -InterfaceIndex %IDX% -ErrorAction SilentlyContinue).Name; if($n){ foreach($k in @('*LsoV2IPv4','*LsoV2IPv6','*LsoV1IPv4')){ try{ Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword $k -DisplayValue 'Enabled' -ErrorAction Stop }catch{} } }" >nul 2>&1
echo [OK] Medium-bandwidth profile applied
goto BW_DONE
:BW_DONE
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS" /v InboundThroughputLevel /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xFFFFFFFF /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Low" /v "Scheduling Category" /t REG_SZ /d "Idle" /f >nul 2>&1
echo [OK] QoS / throttle
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v BranchReadinessLevel /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v AllowAutoWindowsUpdateDownloadOverMeteredNetwork /t REG_DWORD /d 0 /f >nul 2>&1
echo [OK] Update / P2P limited
if not "%IDX%"=="0" powershell -NoProfile -Command "Set-DnsClientServerAddress -InterfaceIndex %IDX% -ServerAddresses @('1.1.1.1','8.8.8.8','2606:4700:4700::1111','2001:4860:4860::8888') -ErrorAction SilentlyContinue" >nul 2>&1
echo [OK] DNS set
powershell -NoProfile -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object { try{ Set-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue }catch{} }" >nul 2>&1
powershell -NoProfile -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object { try{ Set-ItemProperty -Path ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\DefaultMediaCost\' ) -Name (Get-NetConnectionProfile -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue | ForEach-Object { if($_.InterfaceAlias-like '*Ethernet*'){'Ethernet'}elseif($_.InterfaceAlias-like '*Wi-Fi*' -or $_.InterfaceAlias-like '*WLAN*'){'Wifi'}else{$null} }) -Value 2 -ErrorAction SilentlyContinue }catch{} }" >nul 2>&1
echo [OK] Network category / metered
echo.
echo === DONE ===
echo IPv4 DNS: 1.1.1.1 / 8.8.8.8
echo IPv6 DNS: 2606:4700:4700::1111 / 2001:4860:4860::8888
echo Profile: %BW_MODE%
echo.
echo QQ:2185006560
echo mail:Su@TianBIN.org
echo Copyright 2007 - 2026 TianBIN.NET  All Rights Reserved. 
echo.
pause
