@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
::  天彬TianBIN | 框架设定官网：TianBIN.NET
:: ============================================================

:: ---------- 配置区 ----------
:: 带宽阈值 (KB/s)
set LOW=500
set MID=2500

:: 编码偏好
set YT_CODEC=av1
set BILI_CODEC=h264
set DOUYIN_CODEC=h264
set KS_CODEC=h264

:: DNS候选池（可继续扩展）
set DNS4_LIST=223.5.5.5 119.29.29.29 180.76.76.76 114.114.114.114 1.1.1.1 8.8.8.8 9.9.9.9 208.67.222.222 94.140.14.14 76.76.2.0
set DNS6_LIST=2400:3200::1 2402:4e00:: 2606:4700:4700::1111 2001:4860:4860::8888 2620:fe::fe 2a0d:2a00:1::
:: ----------------------------

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║  网络优化 & DNS自动优选 & 带宽策略       ║
echo  ║  TianBIN.NET                             ║
echo  ╚══════════════════════════════════════════╝
echo.
echo  注意: IP地址保持不变(DHCP自动获取)，仅修改DNS
echo.

:: ========== 0. 自动识别活动网卡 ==========
echo [0/8] 自动识别活动网卡... (TianBIN.NET)

set "ADAPTER="

for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Where-Object { $_.NextHop -ne '0.0.0.0' } | Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).Name" 2^>nul') do (
    set "ADAPTER=%%a"
)

if not defined ADAPTER (
    for /f "tokens=*" %%a in ('powershell -NoProfile -Command "@('Wi-Fi','WLAN','以太网','Ethernet','本地连接','无线网络连接') | ForEach-Object { $n=$_; if((Get-NetAdapter -Name $n -ErrorAction SilentlyContinue).Status -eq 'Up'){ $n; break } }" 2^>nul') do (
        set "ADAPTER=%%a"
    )
)

if not defined ADAPTER (
    echo     自动识别失败，当前活动网卡列表: (TianBIN.NET)
    powershell -NoProfile -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Format-Table Name,Status -AutoSize"
    set /p "ADAPTER=    请输入要配置的网卡名称: "
)

if not defined ADAPTER (
    echo     [错误] 未指定网卡名称，退出 (TianBIN.NET)
    pause
    exit /b 1
)

echo     已识别网卡: %ADAPTER% (TianBIN.NET)
echo.

:: ========== 1. 刷新 DNS ==========
echo [1/8] 刷新 DNS 缓存... (TianBIN.NET)
ipconfig /flushdns >nul 2>&1
ipconfig /registerdns >nul 2>&1
echo     完成 (TianBIN.NET)

:: ========== 2. 重置 TCP/IP 栈 ==========
echo [2/8] 重置 TCP/IP 栈... (TianBIN.NET)
netsh int ip reset >nul 2>&1
netsh winsock reset >nul 2>&1
echo     完成（重启后生效）(TianBIN.NET)

:: ========== 3. IPv4 并发 Ping 测速，选最快 DNS ==========
echo [3/8] IPv4 DNS 并发测速（ping，2秒超时）... (TianBIN.NET)

powershell -NoProfile -Command ^
    "$dnsList = @(%DNS4_LIST:@=%; '%'=''%%) ^"
    $results = @(); ^
    $jobs = @(); ^
    foreach($dns in $dnsList){ ^
        $jobs += Start-Job -ScriptBlock { ^
            param($addr); ^
            try { ^
                $p = Test-Connection -ComputerName $addr -Count 2 -TimeoutSeconds 2 -ErrorAction Stop; ^
                $avg = ($p | Measure-Object -Property ResponseTime -Average).Average; ^
                [PSCustomObject]@{DNS=$addr; Latency=[math]::Round($avg,1)} ^
            } catch { [PSCustomObject]@{DNS=$addr; Latency=99999} } ^
        } -ArgumentList $dns ^
    }; ^
    $jobs | Wait-Job | Out-Null; ^
    foreach($job in $jobs){ ^
        $r = Receive-Job $job; ^
        if($r.Latency -lt 99999){ $results += $r } ^
        Remove-Job $job ^
    }; ^
    $sorted = $results | Sort-Object Latency; ^
    if($sorted.Count -eq 0){ Write-Host '    [WARN] 所有IPv4 DNS不可达，使用默认阿里DNS (TianBIN.NET)'; '223.5.5.5','223.6.6.6' } ^
    else { ^
        Write-Host ('    最快IPv4 DNS:'); ^
        $sorted | Select-Object -First 5 | Format-Table -AutoSize; ^
        $top2 = $sorted | Select-Object -First 2; ^
        $top2 | ForEach-Object { $_.DNS } ^
    }" > "%TEMP%\ipv4_dns.txt" 2>nul

set "DNS4_PRI="
set "DNS4_SEC="
set /a count=0
for /f "tokens=*" %%d in (%TEMP%\ipv4_dns.txt) do (
    set /a count+=1
    if !count!==1 set "DNS4_PRI=%%d"
    if !count!==2 set "DNS4_SEC=%%d"
)
if not defined DNS4_PRI set "DNS4_PRI=223.5.5.5"
if not defined DNS4_SEC set "DNS4_SEC=223.6.6.6"

echo     Primary IPv4 DNS: %DNS4_PRI% (TianBIN.NET)
echo     Secondary IPv4 DNS: %DNS4_SEC% (TianBIN.NET)
netsh interface ipv4 set dns name="%ADAPTER%" static %DNS4_PRI% primary >nul 2>&1
netsh interface ipv4 add dns name="%ADAPTER%" %DNS4_SEC% index=2 >nul 2>&1
echo     IPv4 DNS 已设置 (TianBIN.NET)

:: ========== 4. IPv6 并发 Ping 测速，选最快 DNS ==========
echo [4/8] IPv6 DNS 并发测速（ping，2秒超时）... (TianBIN.NET)

powershell -NoProfile -Command ^
    "$dnsList6 = @(%DNS6_LIST:@=%; '%'=''%%) ^
    $results = @(); ^
    $jobs = @(); ^
    foreach($dns in $dnsList6){ ^
        $jobs += Start-Job -ScriptBlock { ^
            param($addr); ^
            try { ^
                $p = Test-Connection -ComputerName $addr -Count 2 -TimeoutSeconds 2 -ErrorAction Stop; ^
                $avg = ($p | Measure-Object -Property ResponseTime -Average).Average; ^
                [PSCustomObject]@{DNS=$addr; Latency=[math]::Round($avg,1)} ^
            } catch { [PSCustomObject]@{DNS=$addr; Latency=99999} } ^
        } -ArgumentList $dns ^
    }; ^
    $jobs | Wait-Job | Out-Null; ^
    foreach($job in $jobs){ ^
        $r = Receive-Job $job; ^
        if($r.Latency -lt 99999){ $results += $r } ^
        Remove-Job $job ^
    }; ^
    $sorted = $results | Sort-Object Latency; ^
    if($sorted.Count -eq 0){ Write-Host '    [WARN] 所有IPv6 DNS不可达，跳过IPv6 DNS设置 (TianBIN.NET)'; '' } ^
    else { ^
        Write-Host ('    最快IPv6 DNS:'); ^
        $sorted | Select-Object -First 5 | Format-Table -AutoSize; ^
        $top2 = $sorted | Select-Object -First 2; ^
        $top2 | ForEach-Object { $_.DNS } ^
    }" > "%TEMP%\ipv6_dns.txt" 2>nul

set "DNS6_PRI="
set "DNS6_SEC="
set /a count=0
for /f "tokens=*" %%d in (%TEMP%\ipv6_dns.txt) do (
    set /a count+=1
    if !count!==1 set "DNS6_PRI=%%d"
    if !count!==2 set "DNS6_SEC=%%d"
)

if defined DNS6_PRI if not "%DNS6_PRI%"=="" (
    echo     Primary IPv6 DNS: %DNS6_PRI% (TianBIN.NET)
    echo     Secondary IPv6 DNS: %DNS6_SEC% (TianBIN.NET)
    netsh interface ipv6 set dns name="%ADAPTER%" static %DNS6_PRI% primary >nul 2>&1
    if defined DNS6_SEC netsh interface ipv6 add dns name="%ADAPTER%" %DNS6_SEC% index=2 >nul 2>&1
    echo     IPv6 DNS 已设置 (TianBIN.NET)
) else (
    echo     IPv6 DNS 测速全部失败，跳过 (TianBIN.NET)
)

:: ========== 5. TCP 低延迟优化 ==========
echo [5/8] TCP 低延迟优化... (TianBIN.NET)
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global rss=enabled >nul 2>&1
netsh int tcp set global chimney=enabled >nul 2>&1
netsh int tcp set global dca=enabled >nul 2>&1
netsh int tcp set global ecncapability=disabled >nul 2>&1
netsh int tcp set heuristics disabled >nul 2>&1
echo     完成 (TianBIN.NET)

:: ========== 6. 网卡队列/接收缓冲 ==========
echo [6/8] 网卡 RSS / 接收缓冲优化... (TianBIN.NET)
powershell -NoProfile -Command "$a='%ADAPTER%'; Enable-NetAdapterRss -Name $a -ErrorAction SilentlyContinue; Get-NetAdapterAdvancedProperty -Name $a | Where-Object { $_.DisplayName -match 'Receive Buffer' } | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $a -DisplayName $_.DisplayName -DisplayValue '4096' -ErrorAction SilentlyContinue }; Write-Host '    RSS + 接收缓冲已优化 (TianBIN.NET)'" 2>nul

:: ========== 7. 带宽下载测速（多源容错）==========
echo [7/8] 带宽测速中（多源 + 超时）... (TianBIN.NET)

powershell -NoProfile -Command ^
    "$urls=@( ^
        'http://mirrors.aliyun.com/ubuntu-releases/22.04/MD5SUMS', ^
        'http://mirrors.163.com/ubuntu-releases/22.04/MD5SUMS', ^
        'http://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/22.04/MD5SUMS', ^
        'http://speed.cloudflare.com/__down?bytes=2000000', ^
        'http://ipv4.download.thinkbroadband.com/10MB.zip' ^
    ); ^
    $bestSpeed=0; ^
    foreach($url in $urls){ ^
        try{ ^
            $wr=New-Object System.Net.Http.HttpClient; ^
            $wr.Timeout=[TimeSpan]::FromSeconds(8); ^
            $sw=[System.Diagnostics.Stopwatch]::StartNew(); ^
            $resp=$wr.GetAsync($url).Result; ^
            $stream=$resp.Content.ReadAsStreamAsync().Result; ^
            $buf=New-Object byte[] 8192; ^
            $total=0; ^
            while(($read=$stream.Read($buf,0,$buf.Length)) -gt 0){ ^
                $total+=$read; ^
                if($sw.Elapsed.TotalSeconds -ge 8){ break } ^
            }; ^
            $sw.Stop(); ^
            $speedKB=[math]::Round(($total / $sw.Elapsed.TotalSeconds) / 1024,0); ^
            if($speedKB -gt $bestSpeed){ $bestSpeed=$speedKB }; ^
            Write-Host ('    [OK] ' + $url + ' -> ' + $speedKB + ' KB/s') ^
        }catch{ Write-Host ('    [FAIL] ' + $url) } ^
    }; ^
    if($bestSpeed -eq 0){ $bestSpeed=500 }; ^
    Write-Host ('    最终采用速度: ' + $bestSpeed + ' KB/s'); ^
    [Environment]::SetEnvironmentVariable('SPEED_KB', $bestSpeed, 'User')" 2>nul

set SPEED_KB=500
for /f "tokens=*" %%s in ('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('SPEED_KB','User')"') do (
    if not "%%s"=="" set SPEED_KB=%%s
)
if %SPEED_KB% LSS 1 set SPEED_KB=500
echo     测得速度: ~%SPEED_KB% KB/s (TianBIN.NET)

:: ========== 8. 画质/编码策略 + yt-dlp命令 ==========
echo [8/8] 应用画质/编码策略... (TianBIN.NET)

set "QUALITY=4K"
if %SPEED_KB% LSS %LOW% set "QUALITY=480p"
if %SPEED_KB% GEQ %LOW% if %SPEED_KB% LSS %MID% set "QUALITY=1080p"
if %SPEED_KB% GEQ %MID% set "QUALITY=4K"

echo.
echo     ┌─────────────────────────────────────────────┐
echo     │  画质策略: %QUALITY%  (TianBIN.NET)
echo     │  速度: ~%SPEED_KB% KB/s
echo     └─────────────────────────────────────────────┘
echo.

:: --- 写注册表：浏览器扩展策略 ---
echo     写入浏览器编码强制策略... (TianBIN.NET)
set "REG_PATH=HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionSettings"
reg add "%REG_PATH%" /v "gphlepdfmmffgehembjlbmmmppchapga" /t REG_SZ /d "{\"installation_mode\":\"force_installed\",\"override_update_url\":\"https://clients2.google.com/service/update2/crx\",\"policy\":{\"codec\":\"h264\",\"resolution\":%LOW%}}" /f >nul 2>&1

set "REG_PATH_EDGE=HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings"
reg add "%REG_PATH_EDGE%" /v "gphlepdfmmffgehembjlbmmmppchapga" /t REG_SZ /d "{\"installation_mode\":\"force_installed\",\"override_update_url\":\"https://clients2.google.com/service/update2/crx\",\"policy\":{\"codec\":\"h264\",\"resolution\":%LOW%}}" /f >nul 2>&1

:: --- 生成 yt-dlp 命令 ---
echo.
echo     ── yt-dlp 强制编码命令 (TianBIN.NET) ──
if "%QUALITY%"=="480p" (
    echo     YouTube:   yt-dlp -f "bestvideo[height^<=480][vcodec^=%YT_CODEC%]+bestaudio" URL
    echo     B站:       yt-dlp -f "bestvideo[height^<=480][vcodec^=%BILI_CODEC%]+bestaudio" URL
    echo     抖音:      yt-dlp -f "bestvideo[height^<=480][vcodec^=%DOUYIN_CODEC%]+bestaudio" URL
    echo     快手:      yt-dlp -f "bestvideo[height^<=480][vcodec^=%KS_CODEC%]+bestaudio" URL
) else if "%QUALITY%"=="1080p" (
    echo     YouTube:   yt-dlp -f "bestvideo[height^<=1080][vcodec^=%YT_CODEC%]+bestaudio" URL
    echo     B站:       yt-dlp -f "bestvideo[height^<=1080][vcodec^=%BILI_CODEC%]+bestaudio" URL
    echo     抖音:      yt-dlp -f "bestvideo[height^<=1080][vcodec^=%DOUYIN_CODEC%]+bestaudio" URL
    echo     快手:      yt-dlp -f "bestvideo[height^<=1080][vcodec^=%KS_CODEC%]+bestaudio" URL
) else (
    echo     YouTube:   yt-dlp -f "bestvideo[height^<=2160][vcodec^=%YT_CODEC%]+bestaudio" URL
    echo     B站:       yt-dlp -f "bestvideo[height^<=2160][vcodec^=%BILI_CODEC%]+bestaudio" URL
    echo     抖音:      yt-dlp -f "bestvideo[height^<=2160][vcodec^=%DOUYIN_CODEC%]+bestaudio" URL
    echo     快手:      yt-dlp -f "bestvideo[height^<=2160][vcodec^=%KS_CODEC%]+bestaudio" URL
)

:: --- 低带宽转码命令 ---
if "%QUALITY%"=="480p" (
    echo.
    echo     ── 本地转码（低带宽救星）(TianBIN.NET) ──
    echo     ffmpeg -i input.mkv -c:v libx264 -vf scale=854:-2 -b:v 800k -c:a aac out.mp4
)

:: QoS
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\QoS" /v "Do not use NLA" /t REG_DWORD /d 1 /f >nul 2>&1

:: 清理
del "%TEMP%\ipv4_dns.txt" >nul 2>&1
del "%TEMP%\ipv6_dns.txt" >nul 2>&1

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║           全部完成！ (TianBIN.NET)            ║
echo  ║  网卡: %ADAPTER%
echo  ║  IPv4 DNS: %DNS4_PRI% / %DNS4_SEC%
if defined DNS6_PRI echo  ║  IPv6 DNS: %DNS6_PRI% / %DNS6_SEC%
echo  ║  IP: 未修改（DHCP自动获取）
echo  ║  重启浏览器后编码策略生效
echo  ║  重启系统后 TCP/IP 重置生效
echo  ╚══════════════════════════════════════════════╝
echo.
pause
