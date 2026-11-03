# 内核来源与 GPL 合规

## 结论

Release 里的 `boot_a.img` 是**重打包的镜像**（内核 + 自己的 initramfs + Linux cmdline），
内核来自 [smith-dog/kernel-tb371fc](https://github.com/smith-dog/kernel-tb371fc)，
协议 **GPL-2.0**（`COPYING`：`GPL-2.0 WITH Linux-syscall-note`，继承联想 GPL 发布）。

上游本身又基于联想公开的 GPL 源码，以及
[lss4/android_kernel_lenovo_paladin](https://github.com/lss4/android_kernel_lenovo_paladin)。

## 判定依据

1. 内核版本串（从镜像里读）：

   ```
   Linux version 4.19.325-perf++ (root@DESKTOP-C88FCL3)
   (Android (5484270 based on r353983c) clang version 9.0.3 ...)
   ```

2. boot 镜像里带 `IKCFG_ST`，能取出完整 `.config`（见下），其中包含这棵树的特征项：

   ```
   CONFIG_LOCALVERSION="-perf+"
   CONFIG_KSU=m
   CONFIG_SDCARD_FS=y
   CONFIG_CNSS_QCA6390=y
   CONFIG_TOUCHSCREEN_NT36532=y
   ```

3. 把取出的 config 和上游 v2.1 release 附带的 `config-v2.1.txt` 对比，只有约 300 项差异
   （主要是调试、DVB、蓝牙串口驱动），核心设备项完全一致 —— 同一棵树、自行配置的构建。

4. cmdline 是 Linux 用的（`rdinit=/init root=/dev/ram0 console=tty0 ...`），
   不是 Android 那套 `androidboot.*`，说明镜像是在原内核上重新打包的。

## 仓库里为此提供了什么

| 内容 | 位置 |
|---|---|
| 本次二进制对应的内核配置 | [kernel/tb371fc-4.19.325.config](kernel/tb371fc-4.19.325.config) |
| 配置 SHA-256 | `efd76dc1aeddbfe7ae4214a29f24b0602ea2f7e0214ad68f4f0d11ebfed02f88` |
| 上游源码 | https://github.com/smith-dog/kernel-tb371fc |
| 第三方组件声明 | [../NOTICE](../NOTICE) |

配置是从发布镜像里用 `IKCFG_ST` / `IKCFG_ED` 提取的（内核开了 `CONFIG_IKCONFIG=y`），
不是事后补写，能保证和二进制一致。

## 复现

```bash
git clone https://github.com/smith-dog/kernel-tb371fc
cd kernel-tb371fc
cp /path/to/tb371fc-4.19.325.config .config
make ARCH=arm64 olddefconfig
# 上游 README 用的参数（v1.10+ 是 Ubuntu clang 21，本二进制是 AOSP clang 9.0.3 r353983c）
make -j6 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CC=clang \
     CLANG_TRIPLE=aarch64-linux-gnu- AS=aarch64-linux-gnu-as \
     DYNAMIC_SINGLE_CHIP=qca6390 Image modules
```

再把 `Image` 和自己的 initramfs、cmdline 按 AOSP boot image 格式打包成 `boot_a.img`
（这台机器上 `-S 16M` 刷写，见 [ufs-flashing-constraints.md](ufs-flashing-constraints.md)）。

`dtbo_a.img` 里的设备树同样来自这棵树（联想板级 DTS + 上游 bring-up 补丁），
源文件在 `arch/arm64/boot/dts/vendor/` 下。

## 如果当时改过源码

GPL-2.0 要求分发二进制时提供**完整对应源码**。本仓库目前只发布了构建配置；
如果构建时除了 `.config` 还改过内核源码或 DTS（例如面板时序、USB、亮度），
应该把这些 diff 也提交到 `docs/kernel/` 下。

如果源码树已经不在，最省事的做法是：

- 以上游对应版本的源码 + 本仓库的 config 为准；
- 在 Issue 里保留一个书面提供源码的承诺（`NOTICE` 里已经写了）。

## 注意

- 上游 v2.2 使用 clang 21 构建，与本镜像（clang 9.0.3）不是同一次构建；
  用公开 config + 上游源码重编得到的二进制不会逐字节相同，但功能等价。
- 内核里的厂商固件（`linux-firmware`）在 rootfs 里，按各自许可分发，
  许可文本保留在镜像的 `/usr/share/licenses/` 下。
