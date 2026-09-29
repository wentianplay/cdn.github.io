@echo off
chcp 936 >nul
setlocal EnableDelayedExpansion
echo === START ===
echo.
fltmc >nul 2>&1 || (
    echo Run as Admin!
    pause
    exit /b 1
)
echo Admin OK
echo.
echo Find Adapter...
set "ADAPTER_IDX="
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).InterfaceIndex" 2^>nul') do (
    set "ADAPTER_IDX=%%a"
)
if not defined ADAPTER_IDX set "ADAPTER_IDX=0"
echo Adapter Index: %ADAPTER_IDX%
echo.
echo Flush DNS...
ipconfig /flushdns
echo.
echo TCP Optimize...
echo Optimizing TCP...
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global rss=enabled
netsh int tcp set global dca=enabled
netsh int tcp set global ecncapability=disabled
netsh int tcp set global timestamps=disabled
netsh int tcp set global fastopen=enabled
netsh int tcp set supplemental template=internet congestionprovider=cubic
echo.
echo Set IPv4 + IPv6 DNS...
powershell -NoProfile -Command "Set-DnsClientServerAddress -InterfaceIndex %ADAPTER_IDX% -ServerAddresses '1.1.1.1','8.8.8.8','2606:4700:4700::1111','2001:4860:4860::8888' -ErrorAction Stop; Write-Host 'DNS Set OK'"
echo.
echo === DONE ===
echo IPv4 DNS: 1.1.1.1 / 8.8.8.8
echo IPv6 DNS: 2606:4700:4700::1111 / 2001:4860:4860::8888
echo.
echo Copyright 2007 - 2026 TianBIN.NET All Rights Reserved. 
echo.
pause
