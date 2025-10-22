#!/bin/bash

echo "================================"
echo "主機初始化..."
echo "================================"

# 更新系统
echo "正在更新系统套件..."
sudo apt update && sudo apt upgrade -y
echo "系统套件更新完成。"

# 安装 qemu-guest-agent
echo "正在安装 Proxmox Guest Agent..."
sudo apt install -y qemu-guest-agent

echo "檢查是否有 snap 套件..."
if ! command -v snap &> /dev/null; then
    echo "未找到 snap 套件，正在安裝..."
    sudo apt install -y snapd
else
    echo "snap 套件已安裝。"
fi
echo "正在安裝 btop 監控工具..."
sudo snap install btop
echo "btop 安裝完成。"

# 安装其他常用套件
echo "正在安装其他常用套件..."
sudo apt install -y \
    net-tools \
    
echo "啟用 qemu-guest-agent 中..."
sudo systemctl enable --now qemu-guest-agent

echo "設定 ufw 防火牆中..."
sudo ufw allow 22
sudo ufw enable

echo "================================"
echo "系统初始化完成！"
echo "================================"
