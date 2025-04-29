#!/bin/bash

# 检查是否以管理员身份运行
if [[ $EUID -ne 0 ]]; then
    echo "请以管理员身份运行此脚本"
    exit 1
fi

# 定义 IP 列表的第三段（xx 值）
ipThirdOctets=(122 137 134 136 202 131 105)
lastOctetDevice=".17"
outfile="output_$(date +'%Y%m%d_%H%M%S').log"

# 开始记录日志
exec > >(tee -a "$outfile") 2>&1

# 获取所有状态为 UP 的适配器，并排除特定适配器（例如 ens65f0）
adapters=$(ip -o link show | awk -F': ' '/state UP/ {print $2}' | grep -E '^ens|^eth' | grep -v 'ens65f0')

# 检查是否找到适配器
if [[ -z "$adapters" ]]; then
    echo "未找到状态为 UP 的适配器"
    exit 1
fi

# 遍历所有适配器
for adapter in $adapters; do
    echo "正在处理适配器: $adapter"

    # 遍历 IP 列表（使用索引遍历，以便动态修改列表）
    for ((i = 0; i < ${#ipThirdOctets[@]}; i++)); do
        xx=${ipThirdOctets[i]}
        newIP="192.168.$xx.1"
        echo "正在设置: $newIP"

        # 设置新的 IP 地址
        if ip addr add "$newIP/24" dev "$adapter" 2>/dev/null; then
            echo "IP 已修改为: $newIP"
        else
            echo "无法设置 IP 地址: $newIP"
            continue
        fi

        # 提取 IP 前三段，并拼接设备 IP
        newIPDevice="192.168.$xx$lastOctetDevice"

        # 测试 Ping
        if ping -c 2 "$newIPDevice" >/dev/null 2>&1; then
            echo "Ping 成功: $newIPDevice"
            echo "固定 IP: $newIP"
            # 从 ipThirdOctets 中移除该 xx 值
            unset "ipThirdOctets[i]"
            # 重新索引数组
            ipThirdOctets=("${ipThirdOctets[@]}")
            # 跳出当前适配器的循环，处理下一个适配器
            break
        else
            echo "Ping 失败: $newIPDevice"
            # 删除未使用的 IP 地址
            ip addr del "$newIP/24" dev "$adapter" 2>/dev/null
        fi

        # 暂停 2 秒
        # sleep 2
    done
done
