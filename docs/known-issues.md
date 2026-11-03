# 已知问题 / 没做完

按"日常使用会不会被影响到"排序。

## 1. 只有 KWin 走 GPU，其它应用全软件渲染

KWin 通过 zink/Turnip 拿到硬件合成，但 Electron、Firefox 等仍走 llvmpipe。
缩放 2.75 时像素量约为 1x 的 7.5 倍，八核很容易被压满 → 桌面卡死、SSH 无响应。

实测：

- **缩放 2.0**（逻辑 1472×920）日常可用
- 2.25 勉强可用
- 2.75 不可用

另外 **KWin 不会把缩放应用到 Xwayland**（`xdpyinfo` 始终 2944×1840@96dpi），
X11 应用要单独加 `--force-device-scale-factor=2`。

## 2. 睡眠/唤醒没接

`suspend` 链路没做，只能关屏。`powerdevilrc` 里的电源键动作因此设成 32（仅关屏），
见 [plasma-session-supervisor.md](plasma-session-supervisor.md)。

## 3. 偶发整体卡死

`tools/tb-loadwatch.sh` 是取证脚本（每 10 秒记录负载、可用内存、CPU 前五）。
抓到的典型现场：

- `MemAvailable` 掉到约 690 MB
- `kswapd` CPU 占用 67%
- qoder 的 gpu 进程 / upowerd / udevd 卡在 D 状态

看起来是软件渲染 + 小内存余量下的连锁反应，没有根治。

## 4. 中文输入法（部分应用不可用）

Chromium/Electron 无法输入中文，详见 [ime-cjk-limitations.md](ime-cjk-limitations.md)。

## 5. 没有 EDL 退路

任何写盘操作出错都可能变砖。详见
[ufs-flashing-constraints.md](ufs-flashing-constraints.md)。
