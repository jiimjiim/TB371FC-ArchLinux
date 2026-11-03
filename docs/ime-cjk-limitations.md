# 中文输入法：GTK/Qt 能用，Chromium/Electron 不能

## 结论

| 应用类型 | 例子 | 中文输入 |
|---|---|---|
| GTK3 / GTK4 | Firefox、Epiphany | ✅ fcitx5 |
| Qt6 | Kate、Konsole | ✅ fcitx5 |
| Chromium / Electron | Qoder CN、Chrome | ❌ 无通道 |

## 原因（两条独立的死路）

### X11 下

Qoder CN 这个 Electron 构建**不带 ibus 客户端**：二进制里搜不到任何
`org.freedesktop.IBus` 字符串。`config/qoder-cn-launch` 里那段拼 `IBUS_ADDRESS` 的逻辑
因此是无效的 —— 保留只是为了说明排查过程。

### Wayland 下

Chromium 走 compositor 的 text-input 协议，需要 compositor 实现输入法协议：

- **KWin 6.8 没有实现 `zwp_input_method_v2`**。fcitx5 日志明确写着
  `Using Wayland native input method protocol: 0`
- KWin 的输入法槽位被 Plasma 自带的虚拟键盘占着（`kwinrc` 的
  `[Wayland] InputMethod=...plasma.keyboard.desktop`），它没有拼音引擎

所以 Wayland 原生输入法这条路在这套组合下是断的。

## 已经试过、确认无效的方向

- 在 `.config/environment.d` / `plasma-workspace/env` 里设置 `GTK_IM_MODULE`、
  `QT_IM_MODULE`、`XMODIFIERS`（对 GTK/Qt 有效，对 Chromium 无效）
- 用 `--ozone-platform=x11` 让 Electron 走 X11（仍然没有 ibus 客户端）
- 用 `--force-device-scale-factor` 同时解决缩放（缩放有效，输入法无效）

## 可能的后续方向（未验证）

- 等 KWin 实现 `zwp_input_method_v2` 并释放虚拟键盘槽位
- 换一个带 ibus 客户端的 Chromium/Electron 构建
- 用 `fcitx5` 的 XIM 通道（Chromium 已不推荐，且这台机器上是 Wayland 会话）
