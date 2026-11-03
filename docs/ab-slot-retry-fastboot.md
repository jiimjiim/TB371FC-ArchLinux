# A/B 槽位重试耗尽 → 开机跌进 fastboot

**这是最容易翻车的一条。** 设备不会变砖，但会突然"只能进 fastboot"，看起来像刷坏了。

## 原理

高通 ABL 每启动一次消耗一次 `slot-retry-count`。Android 开机后会写"启动成功"标记，
把额度补回 7。我们跑的不是 Android，**没有人补**，所以每重启一次就少一次：

```
slot-unbootable:a: yes
slot-retry-count:a: 0
```

7 次启动后设备直接停在 fastboot。

## 恢复（3 秒）

```bash
fastboot --set-active=a        # 同时清 unbootable、retry 复位成 7
fastboot reboot
```

Windows 上跑 `tools/fix-fastboot.cmd`（需要 platform-tools；可以把它放进 PATH，
或设置 `PLATFORM_TOOLS_DIR` 指向 platform-tools 目录）。

**注意**：`fastboot reboot` 在个别状态下不会离开 fastboot，但 `--set-active` 本身是
有效的 —— 重跑一次或手动长按电源键即可。

## 永久修复（没做）

需要在系统启动后往 misc/devinfo 写"启动成功"标记。实测：

- `misc` 偏移 2048（AOSP `bootloader_control` 的标准位置）是空的
- `devinfo` 开头是 `ANDROID-BOOT!`，是高通自有结构

定位方法只能是：`fastboot --set-active` 前后各 dump 一次，逐字节对比。
**写错位置有变砖风险**（这台机器没有 EDL 退路），所以这个修复一直没做。

## 实践建议

- 反复实验时，每隔几轮手动 `fastboot --set-active=a` 一次
- 别连续重启超过 5 次不检查
- 刷入镜像的脚本本身已经带 `fastboot --set-active=a`，正常流程不会耗尽
