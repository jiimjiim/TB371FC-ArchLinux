# 设备信息 / Device notes

Lenovo TB371FC（高通 kona / SM8250），一台官方只提供 Android 的平板。
以下参数都是在这台机器上实测得到的，供移植参考。

| 项目 | 值 |
|---|---|
| SoC | Qualcomm kona (SM8250)，8 核 |
| RAM | 8 GB |
| 屏幕 | NT36532，2944×1840，双 DSI |
| 触摸 | NT36532，IRQ 68，复位 GPIO 1156 |
| 背光 | 双 KTZ8866，分别挂在 i2c-2 和 i2c-4 |
| 音频 | TFA9894 智能功放，四单元 |
| 蓝牙 / Wi-Fi | QCA6390（UART + hci_qca） |
| 存储 | UFS，逻辑块 4096 字节 |
| 根文件系统所在 | `userdata` = `/dev/sda15`，27,385,299 个块 |
| 看门狗 | `/dev/watchdog` 可用 |
| EDL | **没有**，`fastboot oem edl` 返回 unknown |

几个和 Linux 移植直接相关的点：

- 屏幕 60 Hz 是唯一稳定档位；120/144 Hz 在这块屏上有问题，需要改 DRM 模式时钟。
- 背光是两颗独立芯片，只写一颗会出现右半边闪烁；必须同步写 i2c-2 和 i2c-4。
- `userdata` 是主 LUN GPT 里的一个分区，不是独立磁盘；这决定了根文件系统怎么放，
  详见 [ufs-flashing-constraints.md](ufs-flashing-constraints.md)。
- 解锁 bootloader 是前提（`fastboot oem device-info` 里 `unlocked: true`）。
