# 检查是否以管理员身份运行
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "请以管理员身份运行此脚本"
    exit 1
}

# 定义 IP 列表的第三段（xx 值）
$ipThirdOctets = @(100..101)#@(122, 137, 134, 136, 202, 131, 105)
$lastOctetDevice = ".17"
$outfile = "output_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# 开始记录日志
Start-Transcript -Path $outfile

# 获取所有状态为 UP 的网络适配器，并排除特定适配器（例如 ens65f0）
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -notmatch "ens65f0" }

# 检查是否找到适配器
if (-not $adapters) {
    Write-Host "未找到状态为 UP 的适配器"
    Stop-Transcript
    exit 1
}

# 遍历所有适配器
foreach ($adapter in $adapters) {
    Write-Host "正在处理适配器: $($adapter.Name)"
    # 遍历 IP 列表
    for ($i = 0; $i -lt $ipThirdOctets.Count; $i++) {
        $xx = $ipThirdOctets[$i]
        $newIP = "192.168.$xx.1"
        Write-Host "正在设置: $newIP"
        # 设置新的 IP 地址
        try {
            New-NetIPAddress -IPAddress $newIP -PrefixLength 24 -InterfaceAlias $adapter.Name -ErrorAction Stop
            Write-Host "IP 已修改为: $newIP"
        } catch {
            Write-Host "无法设置 IP 地址: $newIP"
            continue
        }
        # 提取 IP 前三段，并拼接设备 IP
        $newIPDevice = "192.168.$xx$lastOctetDevice"
        # 测试 Ping
        if (Test-Connection -ComputerName $newIPDevice -Count 2 -Quiet) {
            Write-Host "Ping 成功: $newIPDevice"
            Write-Host "固定 IP: $newIP"
            # 从 ipThirdOctets 中移除该 xx 值
            $ipThirdOctets = $ipThirdOctets | Where-Object { $_ -ne $xx }
            # 跳出当前适配器的循环，处理下一个适配器
            break
        } else {
            Write-Host "Ping 失败: $newIPDevice"
            # 删除未使用的 IP 地址
            Remove-NetIPAddress -IPAddress $newIP -Confirm:$false
        }
        # 暂停 2 秒
        # Start-Sleep -Seconds 2
    }
}

# 停止记录日志
Stop-Transcript