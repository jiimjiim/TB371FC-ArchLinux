# Qt 6.12 在 4.19 内核上：QProcess 全部失效（Xwayland 起不来）

## 现象

KWin 日志：

```
Xwayland process failed to start
```

任何 `QProcess` 报：

```
Process error 0: fork failure: Invalid argument
```

## 根因

Qt 6.12 的 forkfd 在 `UseVFork` 分支里使用：

```
clone(CLONE_VM | CLONE_PIDFD | CLONE_VFORK | SIGCHLD)
```

而 4.19 内核没有 `CLONE_PIDFD`，直接返回 `EINVAL`。

补充一个容易误判的点：带 `childProcessModifier` 的调用 Qt 会走普通 fork（能用），
所以不是"所有子进程都挂"，只有纯 `QProcess` 路径必挂 —— Xwayland 正好走后者。

## 修法

在 `setUnixProcessParameters` 里把 `UseVFork (0x20)` 掩掉，让 forkfd 退回普通 fork。
针对 Arch Linux ARM `qt6-base 6.12.0` 的 `libQt6Core.so.6.12.0`，两处 4 字节：

```
0x46d644: 2a0103e3 (mov w3, w1)              -> 121a7823 (and w3, w1, #0xffffffdf)
0x46d654: b9002001 (str w1, [x0, #32])       -> b9002003 (str w3, [x0, #32])
```

脚本 `tools/qt-patch.py` 会自动定位库、校验原始字节、备份 `.orig` 再改：

```bash
python3 tools/qt-patch.py           # 只检查状态
sudo python3 tools/qt-patch.py --apply
```

## 注意事项

- **偏移只对 `qt6-base 6.12.0` 成立**。脚本校验失败会拒绝修改；Qt 升级后要用
  `objdump` 重新定位（思路：找 `setUnixProcessParameters` 里对 processParameters
  的位操作，把 0x20 掩掉）。
- 升级 Qt 会覆盖 `libQt6Core.so.6.12.0`，补丁随之失效；`pacman` 升级后需要重打。
- 确认软链没被打回备份：

  ```bash
  ls -l /usr/lib/libQt6Core.so.6
  # 必须指向 libQt6Core.so.6.12.0，指向 .orig 会导致 Xwayland 又起不来
  ```

  脚本在打补丁后会顺手修正软链。
- 验证程序思路：写一个最小 Qt 程序，用 `QProcess` 跑 `/bin/echo`，
  四种组合（vfork × childProcessModifier）各跑一次，看哪些返回 `EINVAL`。
