#!/bin/sh
# TB371FC Arch Linux (4.19 + Plasma 6) patch installer
# 适用前提：同一台机器上已经跑起 Arch Linux ARM + KDE Plasma 6（4.19.325-perf++ 内核）
set -eu

[ "$(id -u)" -eq 0 ] || { echo "请用 root 运行：sudo sh apply-all.sh"; exit 1; }
SRC=$(cd "$(dirname "$0")/.." && pwd)
TARGET_USER=${TARGET_USER:-alarm}
HOMEDIR=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[ -n "$HOMEDIR" ] || { echo "找不到用户 $TARGET_USER（可用 TARGET_USER=xxx sudo sh apply-all.sh）"; exit 1; }

echo "[1/9] 系统服务"
install -m 644 "$SRC"/config/systemd/*.service /etc/systemd/system/
systemctl daemon-reload
for u in tb371fc-plasma tb371fc-touch-rebind kona-audio-init tb-powerkeyd \
         tb371fc-zram tb371fc-chglimit tb371fc-battery tb371fc-wlan \
         qrtr-ns adsp-boot tb-loadwatch; do
    systemctl enable "$u.service" >/dev/null 2>&1 || echo "    !! 启用 $u.service 失败（可能缺依赖）"
done

echo "[2/9] KWin / plasmashell 用户单元"
install -d /etc/systemd/user/plasma-kwin_wayland.service.d \
           /etc/systemd/user/plasma-plasmashell.service.d \
           /etc/systemd/system/tb371fc-plasma.service.d
cp -f "$SRC"/config/kwin/kwin_wayland.d/*.conf /etc/systemd/user/plasma-kwin_wayland.service.d/
cp -f "$SRC"/config/plasmashell.d/*.conf /etc/systemd/user/plasma-plasmashell.service.d/
install -m 644 "$SRC/config/plasma.service.d/20-zink.conf" /etc/systemd/system/tb371fc-plasma.service.d/
install -m 644 "$SRC/config/systemd-user/plasma-wayland-ready.service" /etc/systemd/user/

echo "[3/9] 辅助脚本"
install -m 755 "$SRC"/config/bin/* /usr/local/bin/
install -m 755 "$SRC"/config/sbin/* /usr/local/sbin/
install -m 755 "$SRC/prebuilt/kona-ctl" /usr/local/bin/kona-ctl
command -v qrtr-ns >/dev/null 2>&1 || echo "    !! 未找到 qrtr-ns（qrtr 包），Wi-Fi/BT 需要它"

echo "[4/9] udev 规则（kgsl / ion 权限、wlan 命名）"
install -m 644 "$SRC"/config/udev/*.rules /etc/udev/rules.d/
udevadm control --reload-rules

echo "[5/9] 充电上限配置"
install -d /etc/tb371fc
[ -f /etc/tb371fc/chglimit.conf ] || \
    install -m 644 "$SRC/config/device/chglimit.conf" /etc/tb371fc/chglimit.conf

echo "[6/9] Vulkan DRM 伪装层（让 zink 选中 Turnip）"
SHIM="$SRC/src/vk-drm-shim/prebuilt/libvk_drm_shim.so"
if [ ! -f "$SHIM" ]; then
    echo "    未找到预编译库，尝试现场编译（需要 gcc + vulkan-headers）"
    ( cd "$SRC/src/vk-drm-shim" && make )
    SHIM="$SRC/src/vk-drm-shim/libvk_drm_shim.so"
fi
install -m 755 "$SHIM" /usr/local/lib/libvk_drm_shim.so
install -m 644 "$SRC/src/vk-drm-shim/VK_LAYER_TB371FC_drm_shim.json" /usr/share/vulkan/explicit_layer.d/

echo "[7/9] Turnip kgsl 补丁（mesa 升级后需要重打）"
sh "$SRC/tools/tb371fc-turnip-kgsl-patch" || echo "    !! Turnip 补丁未应用，见 docs/gpu-zink-turnip-drm-shim.md"

echo "[8/9] 电源键动作 + 会话环境 + linger"
if grep -q 'PowerButtonAction=16' "$HOMEDIR/.config/powerdevilrc" 2>/dev/null; then
    sed -i 's/PowerButtonAction=16/PowerButtonAction=32/g' "$HOMEDIR/.config/powerdevilrc"
    echo "    已修改 $HOMEDIR/.config/powerdevilrc"
else
    echo "    未发现 =16 的配置，跳过（可参照 config/powerdevilrc.sample 手动设置）"
fi
install -d -m 755 "$HOMEDIR/.config/environment.d" "$HOMEDIR/.config/plasma-workspace/env"
install -m 644 "$SRC/config/environment.d/10-wayland.conf" "$HOMEDIR/.config/environment.d/10-wayland.conf"
install -m 644 "$SRC/config/plasma-workspace/ime.sh" "$HOMEDIR/.config/plasma-workspace/env/ime.sh"
chown -R "$TARGET_USER":"$TARGET_USER" "$HOMEDIR/.config/environment.d" "$HOMEDIR/.config/plasma-workspace/env"
loginctl enable-linger "$TARGET_USER"

echo "[9/9] Qt 6.12 pidfd 二进制补丁（Xwayland / QProcess 必需）"
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
$PY "$SRC/tools/qt-patch.py" --apply || echo "!! Qt 补丁未应用，请按 docs/qt612-pidfd-xwayland.md 手动处理"

cat <<'EOF'

完成。
- 重启生效：systemctl reboot
- 验证 zink：eglinfo -B | grep -i renderer   （应为 zink / Turnip）
- 验证 Xwayland：pgrep -a Xwayland
- 验证音频：speaker-test -c 2 -t wav / 播放一段音乐
- 触屏如果没反应：systemctl restart tb371fc-touch-rebind.service
- A/B 槽位只有 7 次启动预算，反复重启后用 tools/fix-fastboot.cmd 复位
EOF
