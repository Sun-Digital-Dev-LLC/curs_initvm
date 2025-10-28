#!/usr/bin/env bash
set -euo pipefail

# 參數（依你的環境調整）
TEMPLATE_ID=9002
TEMPLATE_NAME="ub24.04-cloudimg"
NODE="pve"
BRIDGE="vmbr0"
DISK_STORE="local-4T-HDD"         # 也可用 local-4T-HDD
EFI_STORE="local-lvm"
MEM_MB=2048
CORES=2
DISK_SIZE="32G"                # 系統碟大小（留空則使用 cloud image 原始大小，例如: "32G", "50G", "100G"）
SSH_AUTH_KEYS_FILE="/root/authorized_keys"  # 事先準備好你的公鑰
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_FILE="/var/lib/vz/template/iso/ubuntu24.04-lts-cloudimg-amd64.img"

# 檢查本地是否已有 image，沒有才下載
if [[ ! -f "${IMG_FILE}" ]]; then
    echo "本地找不到 ${IMG_FILE}，開始下載..."
    mkdir -p "$(dirname "${IMG_FILE}")"
    curl -L -o "${IMG_FILE}" "${IMG_URL}"
else
    echo "使用本地已存在的 image: ${IMG_FILE}"
fi

# 建立模板 VM (不掛安裝 ISO，直接用 cloud image)
qm create ${TEMPLATE_ID} \
  --name "${TEMPLATE_NAME}-$(date +%Y%m%d)" \
  --memory ${MEM_MB} --cores ${CORES} \
  --net0 virtio,bridge=${BRIDGE} \
  --scsihw virtio-scsi-single

# 匯入 cloud image 成為磁碟
qm importdisk ${TEMPLATE_ID} "${IMG_FILE}" ${DISK_STORE}

# 將匯入磁碟接到 scsi0，並設為第一開機
qm set ${TEMPLATE_ID} --scsi0 ${DISK_STORE}:vm-${TEMPLATE_ID}-disk-0,iothread=1,ssd=1,discard=on
qm set ${TEMPLATE_ID} --boot order=scsi0

# 如果有設定 DISK_SIZE，則擴展系統碟
if [[ -n "${DISK_SIZE}" ]]; then
    echo "擴展系統碟到 ${DISK_SIZE}..."
    qm resize ${TEMPLATE_ID} scsi0 ${DISK_SIZE}
else
    echo "使用 cloud image 原始大小（約 2-3GB）"
fi

# 設定 Cloud-Init、序列主控台與 QEMU GA
qm set ${TEMPLATE_ID} --ide2 ${DISK_STORE}:cloudinit
qm set ${TEMPLATE_ID} --serial0 socket --vga serial0
qm set ${TEMPLATE_ID} --agent enabled=1

# 改為 UEFI + q35，並建立 EFI disk（關閉預載金鑰）
qm set ${TEMPLATE_ID} --bios ovmf
qm set ${TEMPLATE_ID} --machine q35
qm set ${TEMPLATE_ID} --efidisk0 ${EFI_STORE}:${TEMPLATE_ID}-efidisk0,format=raw,pre-enrolled-keys=0

# 放入 SSH 公鑰（或改用 --ciuser/--cipassword，建議SSH更安全）
test -f "${SSH_AUTH_KEYS_FILE}" && qm set ${TEMPLATE_ID} --sshkeys "${SSH_AUTH_KEYS_FILE}"

# 可選：預設使用者與網路（依你的網段調整）
# qm set ${TEMPLATE_ID} --ciuser ubuntu
# qm set ${TEMPLATE_ID} --ipconfig0 ip=192.168.1.200/24,gw=192.168.1.1

# 模板化：之後用 clone 建新 VM
qm template ${TEMPLATE_ID}

echo "Template ${TEMPLATE_ID} ready."
