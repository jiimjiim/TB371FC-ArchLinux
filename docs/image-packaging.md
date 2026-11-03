# 把跑着的系统做成可刷镜像

整合包里的 `userdata.img.zst` 就是这么来的。设备上没法停机，只能**热抓**，
所以必须做离线修复，否则别人刷完可能一开机就 fsck。

## 1. 抓分区

rootfs 直接铺在 `userdata`（`/dev/sda15`，27,385,299 个 4096 字节块）上。
先清掉个人数据，然后 `fstrim /`，让空闲块真正读回 0：

```bash
sudo sh -c 'sync; fstrim -v /'
```

再分段抓，8 GiB 一段，每段一个独立 zstd 帧，断了只要从断点续（Wi-Fi 会掉）：

```bash
sudo sh -c 'dd if=/dev/sda15 bs=4096 skip=<起始块号> count=2097152 iflag=fullblock \
  | zstd -3 -T2 -c' > p001.zst
```

每段记下起始块号。段被截断时，把已解压的字节数向下取整到 4096 的倍数，
作为下一段的起点（用 `zstd -dc p001.zst | wc -c` 算）。

## 2. 拼成 sparse，再展开成带空洞的 raw

按段解压、用 `head -c 块数*4096` 裁掉截断的尾巴，拼起来直接喂给编码器：

```bash
( zstd -dc p000.zst | head -c $((765517*4096)); \
  zstd -dc p001.zst | head -c $((2097152*4096)); ... ) \
  | python3 tools/mksparse.py userdata.simg 27385299
```

再展开成 raw 检查（空洞不占磁盘，112 GB 只落约 9 GB）：

```bash
python3 tools/simg2sparseraw.py userdata.simg raw.img
losetup -f --show raw.img && e2fsck -fn /dev/loopN
```

## 3. 修 + 清

热抓出来的 ext4 一定有目录计数、位图校验和不一致（差别只有几百字节），
`e2fsck -fy` 修掉，再用 `-fn` 复检到一条错都不报。

要删登录态/缓存就在挂载后删。**先清零文件内容再删**，否则旧数据还躺在镜像里：

```bash
mount /dev/loopN /mnt/x
find .qoder .qoder-cn -type f -exec shred -n 1 -z -u {} \;
rm -rf .qoder .qoder-cn
umount /mnt/x && e2fsck -fy /dev/loopN && e2fsck -fn /dev/loopN
```

## 4. 重新编码 + 压缩

```bash
python3 tools/mksparse.py userdata.simg 27385299 < raw.img
zstd -3 -T0 userdata.img     # 9.0 GB sparse -> 3.15 GB
```

`simg2sparseraw.py` 反向也用它验：换成 raw 挂 loop，`e2fsck -fn` 干净、关键文件还在才发。

## 5. 刷

```bash
fastboot flash -S 16M userdata userdata.img
```

`-S 16M` 不能省：单次传输超过 16 MiB，设备会停止读端点，被主机判超时。
完整的刷写约束见 [ufs-flashing-constraints.md](ufs-flashing-constraints.md)。

## 6. 发布前检查

- 镜像里的用户密码、host key、shell 历史、浏览器 cookie 都清干净
- 发布 `SHA256SUMS`
- rootfs 镜像里包含 Arch 各软件包，**不要把它塞进 git**；GitHub Release 单资产上限
  2 GB，3.15 GB 需要分卷（`7z a -v1500m`）或放到别处
