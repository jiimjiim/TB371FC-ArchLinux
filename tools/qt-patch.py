#!/usr/bin/env python3
"""Qt 6.12 (Arch qt6-base 6.12.0 构建) 在 Linux 4.19 上的 pidfd 补丁。

背景：Qt 6.12 的 forkfd 使用 clone(CLONE_VM|CLONE_PIDFD|CLONE_VFORK|SIGCHLD)，
4.19 内核没有 CLONE_PIDFD -> EINVAL；表现为 Xwayland 起不来、QProcess 报
"fork failure: Invalid argument"。

做法：把 setUnixProcessParameters 里的 UseVFork(0x20) 掩掉，让 forkfd 退回普通 fork。
两处 4 字节指令：
  0x46d644  mov  w3, w1                  ->  and  w3, w1, #0xffffffdf
  0x46d654  str  w1, [x0, #32]           ->  str  w3, [x0, #32]

注意：偏移只对 Arch Linux ARM qt6-base 6.12.0 的 libQt6Core.so.6.12.0 成立；
Qt 升级后必须重新定位（脚本会校验原始字节，不匹配就拒绝改动）。
"""
import glob
import os
import shutil
import sys

ORIG_A = bytes.fromhex("2a0103e3")   # mov w3, w1
NEW_A  = bytes.fromhex("121a7823")   # and w3, w1, #0xffffffdf
ORIG_B = bytes.fromhex("b9002001")   # str w1, [x0, #32]
NEW_B  = bytes.fromhex("b9002003")   # str w3, [x0, #32]
OFF_A = 0x46d644
OFF_B = 0x46d654


def pick_lib():
    cands = sorted(glob.glob("/usr/lib/libQt6Core.so.6.12.*"))
    cands = [c for c in cands if not c.endswith(".orig")]
    if not cands:
        cands = sorted(glob.glob("/usr/lib/libQt6Core.so.6*"))
        cands = [c for c in cands if not c.endswith(".orig")]
    if not cands:
        sys.exit("找不到 libQt6Core.so.6*")
    for c in cands:
        if os.path.getsize(c) > 1_000_000:
            return c
    return cands[0]


def status(path):
    with open(path, "rb") as f:
        f.seek(OFF_A); a = f.read(4)
        f.seek(OFF_B); b = f.read(4)
    if a == NEW_A and b == NEW_B:
        return "patched"
    if a == ORIG_A and b == ORIG_B:
        return "original"
    return "unknown(%s/%s)" % (a.hex(), b.hex())


def fix_symlink(path):
    link = "/usr/lib/libQt6Core.so.6"
    want = os.path.basename(path)
    if os.path.islink(link) and os.readlink(link) != want:
        os.remove(link)
        os.symlink(want, link)
        print("已修正软链 %s -> %s" % (link, want))


def main():
    lib = pick_lib()
    st = status(lib)
    print("目标: %s" % lib)
    print("当前状态: %s" % st)
    if "--apply" not in sys.argv:
        print("（只检查，未修改；加 --apply 执行）")
        return 0
    if st == "patched":
        fix_symlink(lib)
        print("已经是打过补丁的状态，无需重复操作。")
        return 0
    if st != "original":
        print("!! 关键字节与预期不符（Qt 版本可能变了），已中止。")
        print("   请按 docs/折腾记录.md 2.1 用 objdump 重新定位后再改。")
        return 1
    backup = lib + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(lib, backup)
        print("备份 -> %s" % backup)
    with open(lib, "r+b") as f:
        f.seek(OFF_A); f.write(NEW_A)
        f.seek(OFF_B); f.write(NEW_B)
    print("补丁已写入。")
    fix_symlink(lib)
    print("建议顺手跑一次 ldconfig，然后重启 KWin/会话。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
