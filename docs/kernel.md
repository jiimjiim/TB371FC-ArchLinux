# 内核来源与对应源码

## 结论

Release 里 `boot_a.img` 的内核，是下面三样东西编出来的：

1. **上游源码**：`smith-dog/kernel-tb371fc` @ `2c25a63a541dc6b98cf25212fbac7d2a4c687351`
   （`v2.1-2-g2c25a63a5`，GPL-2.0）
2. **本仓库补丁**：[tb371fc-4.19-linux.patch](tb371fc-4.19-linux.patch)
   （61 个文件，+846 / −227，含 4 个新增源文件）
3. **本仓库配置**：[tb371fc-4.19.325.config](tb371fc-4.19.325.config)
   （sha256 `3790154fe2ec0b4e4cb456849bcab19c2ac0b372ed484703537a25095a2f53e4`）

上游又基于联想公开的 GPL 源码和
[lss4/android_kernel_lenovo_paladin](https://github.com/lss4/android_kernel_lenovo_paladin)。

## 证据链

| 事实 | 值 |
|---|---|
| 发布镜像里内核段的 sha256 | `177d80a36dab1999044983f1b9afaf1646783ba36261b4054a531e87d80a9113` |
| 构建产物 `build-419-display2/arch/arm64/boot/Image` | 同 sha256，逐字节一致 |
| 该 build 目录的 srctree | `/opt/kernel-tb371fc`（kbuild `mkmakefile` 生成） |
| 源树 HEAD | `2c25a63a541dc6b98cf25212fbac7d2a4c687351`（上游 v2.1-2） |
| 源树工作区状态 | 57 个修改 + 4 个新增源码文件（即本仓库补丁） |
| 源码最后修改时间 | 2026-11-03 10:10:36，镜像构建时间 10:11:22 |
| 构建配置 | 与镜像内嵌 `IKCONFIG` 完全一致（上面的 sha256） |
| 工具链 | AOSP clang `r353983c`（9.0.3），`kernel.release` = `4.19.325-perf++` |

也就是说：`/opt/kernel-tb371fc` 当时的工作区状态 = 上游 `2c25a63` + 本仓库补丁，
用它和本仓库的 config 编出来的 Image，与发布镜像里的内核段**逐字节相同**。
源码树里没有其他未提交改动（`drivers/staging` 下的 qcacld 三仓在上游是 tracked 的）。

## 补丁改了什么

按子系统：

- **显示**：`techpack/display` 下的 DSI/DPU/DSC（时钟一致性、60 Hz、earlydump）、
  PLL v4.0、SDE 若干
- **kexec**：`arch/arm64/kernel` 的 kexec/relocate、`proc.S`、`cpu-reset.h`
- **触控**：`nt36532` 的 resume 重新绑定（配合 `tb371fc-touch-rebind.sh`）
- **音频**：`techpack/audio` 的 TFA98xx / TFA9894 校准、ADSP loader、kona machine
- **蓝牙**：`hci_qca` / `btqca`
- **电源**：`qpnp-smb5`、`smb5-lib`、`power_supply_sysfs`（充电上限、电源键）
- **USB**：`dwc3` debugfs
- **syscall/fs**：`stat`、`statx`、`open`、`file` 等，为 4.19 补上 glibc 需要的接口
- **新增文件**：`drivers/misc/tb371fc_stubs.c`、`techpack/display/msm/tb371fc_earlydump.c`、
  以及两个构建期补丁脚本 `tb371fc/scripts/p199-*`、`p220-*`

`.orig*` 备份文件没有包含在补丁里（它们是改动前的副本，不是源码）。

## 复现

```bash
git clone https://github.com/smith-dog/kernel-tb371fc
cd kernel-tb371fc
git checkout 2c25a63a541dc6b98cf25212fbac7d2a4c687351
git apply /path/to/tb371fc-4.19-linux.patch

# 工具链：AOSP clang r353983c（9.0.3）
export PATH=/path/to/clang-r353983c/bin:$PATH

cp /path/to/tb371fc-4.19.325.config .config
make O=/tmp/build ARCH=arm64 olddefconfig
make O=/tmp/build -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
     CC=clang CLANG_TRIPLE=aarch64-linux-gnu- AS=aarch64-linux-gnu-as Image
```

然后按 AOSP boot image 格式打包：`Image` + 自己的 initramfs + 下面的 cmdline，
得到 `boot_a.img`（96 MB 的镜像里内核段约 41.8 MB）。

```
rdinit=/init root=/dev/ram0 rw console=ttyMSM0,115200n8 console=tty0 loglevel=3
clk_ignore_unused pd_ignore_unused regulator_ignore_unused
earlycon=qcom_geni,0x988000 msm_drm.fbdev=0
```

`dtbo_a.img` 同样来自这棵树；构建时 `arch/arm64/boot/dts` 下没有未提交改动。

## GPL 说明

- 上游协议是 `GPL-2.0 WITH Linux-syscall-note`（见上游 `COPYING`）。
- 本仓库发布的补丁和配置是这份二进制的**完整对应源码**的一部分，
  与上游 `2c25a63` 一起即可重建内核，因此不再依赖单独的“书面提供源码”承诺。
- 补丁和配置本身也按 GPL-2.0 提供；本仓库其他代码仍是 MIT（见 [../LICENSE](../LICENSE)）。
- 工具链是公开的 AOSP 预编译 clang（r353983c），不属于内核源码分发范围。

如果你发现重建结果与镜像不一致，请开 Issue，我们继续核对（比如 dtbo 的构建脚本）。
