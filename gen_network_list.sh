#!/bin/bash

# 检查是否以管理员身份运行
if [[ $EUID -ne 0 ]]; then
    echo "请以管理员身份运行此脚本"
    exit 1
fi

# 定义网络配置文件存放目录
networkDir="/etc/systemd/network"

# 检查目录是否存在，如果不存在则创建
if [[ ! -d "$networkDir" ]]; then
    mkdir -p "$networkDir"
fi

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

    # 生成 .network 文件名
    networkFile="$networkDir/$adapter.network"

    # 如果文件已存在，跳过
    if [[ -f "$networkFile" ]]; then
        echo "配置文件已存在: $networkFile"
        continue
    fi

    # 获取当前适配器的 IP 地址
    ipAddress=$(ip -o -4 addr show "$adapter" | awk '{print $4}')

    # 检查是否获取到 IP 地址
    if [[ -z "$ipAddress" ]]; then
        echo "未找到适配器 $adapter 的 IP 地址，将使用 DHCP"
        ipAddress="dhcp"
    fi

    # 写入 .network 文件内容
    {
        echo "[Match]"
        echo "Name=$adapter"
        echo ""
        echo "[Network]"
        echo "Address=$ipAddress"
    } > "$networkFile"

    echo "已生成配置文件: $networkFile"
done

# 重启 systemd-networkd 服务以应用配置
systemctl restart systemd-networkd.service
echo "已重启 systemd-networkd 服务"
