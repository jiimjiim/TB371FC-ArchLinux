# TB371FC: Arch Linux ARM + KDE Plasma 6

在 Lenovo TB371FC（高通 kona / SM8250，8 GB RAM，2944×1840 NT36532 双 DSI 屏）上跑
**Arch Linux ARM aarch64 + KDE Plasma 6 Wayland** 的补丁集合。

> 跑在原生 vendor **4.19.325-perf++** 内核上。这台机器官方只提供 Android，
> Linux 侧的坑基本都要自己填。
>
> 本仓库只放**补丁、配置、自写源码和踩坑记录**，不含系统镜像。
> 2026-11 存档：作者已停止开发，未完成的部分见 [docs/known-issues.md](docs/known-issues.md)。

> English: patches (systemd units, KDE drop-ins, a small Vulkan DRM layer for
> zink/Turnip, a Qt 6.12 binary patch for the 4.19 kernel, helper tools) and notes for
> running Arch Linux ARM + Plasma 6 Wayland on a Lenovo TB371FC (SM8250, 2944×1840).
> No system images are distributed here.

## 跑通了什么

| 项目 | 状态 | 入口 |
|---|---|---|
| 内部 UFS 引导 Arch（内核在 `boot_a`，根文件系统在 `userdata`） | ✅ | [docs/ufs-flashing-constraints.md](docs/ufs-flashing-constraints.md) |
| 屏幕 / 触摸（NT36532） | ✅ | [docs/device.md](docs/device.md) |
| 亮度（双 KTZ8866 同步写入） | ✅ | [docs/device.md](docs/device.md) |
| 60 Hz 固定 | ✅ | [docs/device.md](docs/device.md) |
| 音频（TFA9894） | ✅ | [docs/system-services.md](docs/system-services.md) |
| 蓝牙 QCA6390 | ✅ | [docs/system-services.md](docs/system-services.md) |
| 看门狗 | ✅ | — |
| 触屏冷启动自动重绑 | ✅ | [docs/system-services.md](docs/system-services.md) |
| 充电上限（80/75）、zram、电源键直接切背光 | ✅ | [docs/system-services.md](docs/system-services.md) |
| GPU 传感器（ksystemstats 插件） | ✅ | [src/ksystemstats-adrenogpu](src/ksystemstats-adrenogpu) |
| **zink GPU 加速**（Vulkan DRM 伪装层） | ✅ | [docs/gpu-zink-turnip-drm-shim.md](docs/gpu-zink-turnip-drm-shim.md) |
| Xwayland（Qt 6.12 pidfd 二进制补丁） | ✅ | [docs/qt612-pidfd-xwayland.md](docs/qt612-pidfd-xwayland.md) |
| 会话自愈（Plasma 退出后自动重开） | ✅ | [docs/plasma-session-supervisor.md](docs/plasma-session-supervisor.md) |
| 中文输入法 | ⚠️ 仅 GTK/Qt | [docs/ime-cjk-limitations.md](docs/ime-cjk-limitations.md) |
| 睡眠 / 唤醒 | ❌ | [docs/known-issues.md](docs/known-issues.md) |

## 快速开始

前提：已解锁 bootloader，已经能在同一台机器上启动 4.19 内核 + Arch rootfs + Plasma 6。

```bash
git clone <this repo> TB371FC-ArchLinux
cd TB371FC-ArchLinux
sudo TARGET_USER=alarm sh scripts/apply-all.sh
sudo systemctl reboot
```

脚本会安装：11 个设备服务、KWin/plasmashell 的 drop-in、udev 规则、会话环境与
linger、Vulkan DRM 层、Turnip 和 Qt 两个二进制补丁；并把电源键动作从"注销屏"
改成"仅关屏"。各个单元的职责见 [docs/system-services.md](docs/system-services.md)。

验证：

```bash
eglinfo -B | grep -i renderer      # 期望 zink (Turnip)
pgrep -a Xwayland                  # 期望有进程
```

## 文档

| 文档 | 内容 |
|---|---|
| [device.md](docs/device.md) | 硬件参数（屏幕、触摸 IRQ/GPIO、背光、UFS 等） |
| [gpu-zink-turnip-drm-shim.md](docs/gpu-zink-turnip-drm-shim.md) | 为什么 zink 选不中 GPU，以及那个 Vulkan 层 |
| [qt612-pidfd-xwayland.md](docs/qt612-pidfd-xwayland.md) | 4.19 没有 `CLONE_PIDFD` 导致 Xwayland 起不来 |
| [plasma-session-supervisor.md](docs/plasma-session-supervisor.md) | 会话自愈、linger、电源键行为 |
| [ab-slot-retry-fastboot.md](docs/ab-slot-retry-fastboot.md) | 7 次启动预算耗尽跌进 fastboot 的恢复 |
| [ufs-flashing-constraints.md](docs/ufs-flashing-constraints.md) | 写盘前必读：分区、`-S 16M`、LBA1、无 EDL |
| [ime-cjk-limitations.md](docs/ime-cjk-limitations.md) | Chromium/Electron 为什么打不了中文 |
| [system-services.md](docs/system-services.md) | 触控重绑、音频初始化、充电上限、zram、电源键、udev 等小服务 |
| [known-issues.md](docs/known-issues.md) | 已知硬伤与未完成项 |
| [image-packaging.md](docs/image-packaging.md) | 热抓 rootfs → sparse → 可刷镜像的完整流程 |

## 目录结构

```
config/
  systemd/          系统级单元（会话看护、触控重绑、音频、zram、充电上限、wlan…）
  systemd-user/     用户单元（plasma-wayland-ready）
  bin/              装到 /usr/local/bin 的辅助脚本
  sbin/             装到 /usr/local/sbin 的辅助脚本
  udev/             kgsl / ion 权限、wlan 命名
  device/           chglimit.conf 示例
  plasma.service.d/ 20-zink.conf（会话渲染后端）
  kwin/             kwinrc.sample、kwin_wayland.d/*.conf
  plasmashell.d/    plasmashell 的等待与重启策略
  environment.d/    会话环境变量
  plasma-workspace/ 输入法环境
  powerdevilrc.sample
src/
  vk-drm-shim/      Vulkan DRM 伪装层源码 + prebuilt
  ksystemstats-adrenogpu/  GPU 传感器插件源码
prebuilt/
  kona-ctl          ALSA control 工具（无源码，aarch64 预编译）
tools/
  qt-patch.py       Qt 6.12 pidfd 二进制补丁
  tb371fc-turnip-kgsl-patch  Turnip 的 kgsl 补丁
  mksparse.py       raw ext4 → Android sparse
  simg2sparseraw.py Android sparse → 带空洞的 raw
  fix-fastboot.cmd  A/B 重试耗尽后的一键恢复
scripts/
  apply-all.sh      安装以上全部补丁
  flash-linux.sh / flash-windows.bat   刷写脚本（配合自行准备的镜像使用）
docs/
```

## 镜像去哪了

`rootfs` 是约 3.15 GB 的 zst，超过 GitHub 单文件/单资产限制，而且包含 Arch 各软件包
和厂商内核 —— 再分发有许可证和隐私问题，所以**不随仓库发布**。

自己从跑着的系统打包的完整流程在 [image-packaging.md](docs/image-packaging.md)。
`scripts/flash-*.sh` 按下面的目录布局工作：

```
boot/boot_a.img
boot/dtbo_a.img
rootfs/userdata.img        # 由 userdata.img.zst 解压而来
```

`boot_a.img` 里是 GPL 内核二进制；如果分发它，请同时提供对应的内核源码与 config。

## 免责声明

- 这台机器**没有 EDL 退路**（`fastboot oem edl` 返回 unknown），写错 GPT 基本等于变砖
- A/B 槽位只有 7 次启动预算，见 [docs/ab-slot-retry-fastboot.md](docs/ab-slot-retry-fastboot.md)
- 所有配置来自一台具体设备的一次实践，内核/发行版版本变化后补丁偏移、服务名都可能不同

## License

代码 MIT；`docs/` 下文档 CC BY-SA 4.0。见 [LICENSE](LICENSE)。
