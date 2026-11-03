# UFS 刷写约束（写盘前必读）

这台机器的存储栈有几条反直觉的规则，踩中任何一条都可能把系统写到一半失败，
最严重的一条会把分区表抹掉。

## 1. `userdata` 是一个分区，不是一块盘

- UFS 暴露 96 个 BlockIo 句柄（6 个物理 LUN + 约 90 个逻辑分区），**逻辑块 4096 字节**
- `userdata` 是主 LUN GPT 上的**一个分区**（`/dev/sda15`，27,385,299 个块）
- `fastboot flash userdata` 写的是这个分区内部的偏移 0，不是物理盘开头

## 2. 分区不会被递归解析

UEFI 的 PartitionDxe **不会解析分区里的分区表**。在 `userdata` 里再套一个 GPT/ESP，
系统永远看不到。真正的 ESP 必须是主 LUN GPT 里的分区 —— 这也是为什么这套方案
把根文件系统直接铺在 `userdata` 上、不依赖 ESP。

## 3. 大镜像必须 `-S 16M`

单次下载的载荷在 256–768MB 之间就已经不稳：

- `-S 128M`：写超时并把设备卡死
- **`-S 16M` 稳定可用**，整盘/大镜像一律用它

## 4. sparse 的 `DONT_CARE` 段不清零

Android sparse 的 `0xCAC3` 段语义是"这区域是垃圾，可以直接跳过"，**目标区域不会清零**。
需要"必须为 0"的结构（如将来的分区表），得显式写 `0xCAC1` 的 RAW 零块。

## 5. 千万不要写 LBA1

- 主 GPT 位于物理盘 LBA1。写坏它 = 容量和分区全丢
- **这台机器没有 EDL 退路**：`fastboot oem edl` 返回 unknown，救不回来
- 备份 GPT 在盘尾最后一个 LBA，不用它来恢复就相当于没有备份

实测教训：曾经写入 LBA1 把主 GPT 覆盖，分区全部消失，最后靠 Android 工具链重建
才恢复。任何 `dd`/`sgdisk`/`fastboot flash` 命令执行前，先打印目标盘确认。

## 6. 镜像尺寸参考

| 项目 | 值 |
|---|---|
| `userdata` 总块数 | 27,385,299（× 4096 = 约 104 GiB） |
| 根文件系统实际占用 | 约 9 GiB |
| 打包后（zstd -3） | 3.15 GiB |

镜像的完整打包流程见 [image-packaging.md](image-packaging.md)。
