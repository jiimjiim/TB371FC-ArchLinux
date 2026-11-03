#!/bin/sh
# TB371FC Arch Linux ARM + Plasma 6 flashing script (Linux host)
set -eu
cd "$(dirname "$0")"

echo "!! 这会覆盖 userdata 分区全部内容"
printf "继续? [y/N] "; read -r a; [ "$a" = y ] || exit 1

fastboot devices
echo "[1/4] boot_a";  fastboot flash boot_a boot/boot_a.img
echo "[2/4] dtbo_a";  fastboot flash dtbo_a boot/dtbo_a.img

if [ ! -f rootfs/userdata.img ]; then
    echo "rootfs/userdata.img 不存在，先解压： zstd -d rootfs/userdata.img.zst -o rootfs/userdata.img"
    exit 1
fi

echo "[3/4] userdata（sparse，必须 -S 16M）"
fastboot flash -S 16M userdata rootfs/userdata.img

echo "[4/4] 槽位 + 重启"
fastboot --set-active=a
fastboot reboot
echo "完成，首次启动较慢。"
