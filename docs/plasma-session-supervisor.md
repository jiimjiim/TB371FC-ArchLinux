# KDE 会话自愈 + 电源键行为

## 为什么需要

这套系统不是 systemd 会话管理的标准安装：Plasma 由系统级服务拉起，
一旦 `startplasma-wayland` 退出，没有东西会把它拉回来，表现为"桌面没了、SSH 还在"。

## 会话看护

`config/systemd/tb371fc-plasma.service`（装到 `/etc/systemd/system/`）：

- `User=alarm`、`PAMName=login`、`TTYPath=/dev/tty7` → 拿到真实的 logind 图形会话，
  KWin 才能通过 `plasma-kwin_wayland.service` 去 `TakeDevice` `/dev/dri/card0`
- `Restart=always`、`RestartSec=10s`
- `ExecStartPre=+/usr/bin/chvt 7`

`config/bin/tb371fc-plasma.sh`（装到 `/usr/local/bin/`）：

- 设置 `DBUS_SESSION_BUS_ADDRESS`
- 从环境或 `loginctl list-sessions` 拿到 `XDG_SESSION_ID`，
  再用 `systemctl --user set-environment` 注入
- 死循环 `setsid -w startplasma-wayland`：进程内重启，避免 logind 把
  `user@1000` 整个拆掉

**必须开 linger**：

```bash
loginctl enable-linger alarm
```

否则没有活跃 logind 会话时 `user@1000` 会退出，`plasma-kwin_wayland.service`
等子单元起不来 —— 这是"重启后黑屏但服务看着正常"的最常见原因。

## 电源键会"注销"，看起来像 GUI 崩溃

PowerDevil 默认 `PowerButtonAction=16` = **显示注销屏幕**。短按电源键会结束整个
Plasma 会话，10 秒后自愈服务重开 —— 用户看到的是"桌面闪一下，应用全没了"。

`config/powerdevilrc.sample` 已改为 **32（仅关屏）**：

```
0 无 / 1 睡眠 / 2 休眠 / 4 关机 / 8 锁屏 / 16 注销屏 / 32 关屏
```

`apply-all.sh` 会把现有 `powerdevilrc` 里的 `=16` 原地改成 `=32`。

## 其余的 drop-in

- `config/kwin/kwin_wayland.d/10-noams.conf`：`KWIN_DRM_NO_AMS=1`
- `15-swcursor.conf`：强制软件光标（GPU 走 zink 时硬件光标会有问题）
- `20-direct.conf`：让 kwin 自己启动 Xwayland、剥离 `WAYLAND_DISPLAY`/`DISPLAY`
  （否则 kwin 会按嵌套后端启动）；`ExecStartPre` 等 GPU 就绪
- `25-restart.conf`：取消启动频率限制，失败 5 秒后重试
- `35-vk-drm-shim.conf`：启用 Vulkan DRM 伪装层
- `40-debug.conf`：需要排查时打开 drm/kwin 调试日志
- `config/plasmashell.d/60-wait-wayland.conf`：等 Wayland socket 就绪
- `70-restart.conf`：plasmashell 挂了 3 秒后重拉
- `config/systemd-user/plasma-wayland-ready.service` + `config/bin/wait-wayland-socket.sh`：
  带超时的 oneshot，等 `wayland-0` / `wayland-1` 出现
- `config/plasmashell.d` 之外，`config/plasma.service.d/20-zink.conf` 负责把
  会话服务的渲染后端切到 zink（见 [system-services.md](system-services.md)）
