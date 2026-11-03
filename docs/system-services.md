# 设备专用小服务

这些单元都不大，但缺一个就会表现成"某个硬件不工作"。全部由
`scripts/apply-all.sh` 安装并 enable。

| 单元 | 脚本 | 作用 |
|---|---|---|
| `tb371fc-plasma.service` | `config/bin/tb371fc-plasma.sh` | 拉起并看护 Plasma 会话，见 [plasma-session-supervisor.md](plasma-session-supervisor.md) |
| `tb371fc-touch-rebind.service` | `config/bin/tb371fc-touch-rebind.sh` | Novatek 触控冷启动后不扫描，等 KWin 起来 + DPMS On 再 `unbind/bind spi0.0` 一次 |
| `kona-audio-init.service` | `config/bin/kona-audio-init` | 等 `controlC0` 出现（ADSP 启动后才有），设置 TDM/TFA9894 混音参数 |
| `adsp-boot.service` | — | `echo 1 > /sys/kernel/boot_adsp/boot`，让 ADSP 提前启动 |
| `tb-powerkeyd.service` | `config/bin/tb-powerkeyd` | 直接读 evdev 电源键，切换背光 0 / 上次亮度 |
| `tb371fc-zram.service` | `config/sbin/tb371fc-zram.sh` | zram swap，容量为一半内存，算法 lzo |
| `tb371fc-chglimit.service` | `config/sbin/tb371fc-chglimit.sh` | 充电上限：>= 80% 停充，<= 75% 恢复 |
| `tb371fc-battery.service` | — | MM8013 电量计（i2c3）；老内核需要 `insmod /usr/local/lib/tb371fc/mm8013.ko` |
| `tb371fc-wlan.service` | — | `modprobe wlan`，依赖 `qrtr-ns.service` |
| `qrtr-ns.service` | — | Qualcomm IPC Router 名字服务，WiFi/BT 都依赖 |
| `tb-loadwatch.service` | `config/bin/tb-loadwatch.sh` | 卡死取证，每 10 秒记录负载/内存/CPU 前五 |

## 充电上限

配置文件 `/etc/tb371fc/chglimit.conf`：

```
CHG_LIMIT_ENABLE=1
CHG_LIMIT_END=80
CHG_LIMIT_START=75
CHG_LIMIT_POLL=30
```

脚本靠 `/sys/class/power_supply/battery/charging_enabled` 开关充电；没有这个节点就直接退出。

## kona-ctl

`kona-audio-init` 依赖 `/usr/local/bin/kona-ctl`（`prebuilt/kona-ctl`），
一个做 ALSA control `list/info/get/set` 的小工具，**没有源码，只有 aarch64 预编译**。
它只用到 `cset name=... value` 这一类操作，理论上可以用 `amixer -c 0 cset name=...`
替代（未在设备上验证）。

## udev 规则

| 规则 | 内容 |
|---|---|
| `50-kgsl.rules` | `kgsl-3d0` 归 `render` 组、0660 —— Turnip 访问 `/dev/kgsl-3d0` 需要 |
| `51-ion.rules` | `ion` 0666 —— Adreno 的图形缓冲分配 |
| `70-tb371fc-wlan.rules` | 把无线网卡稳定命名为 `wlan0` |

## 20-zink.conf

`config/plasma.service.d/20-zink.conf` 给会话服务注入：

```
MESA_LOADER_DRIVER_OVERRIDE=zink
GALLIUM_DRIVER=zink
LIBGL_ALWAYS_SOFTWARE=0
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.json
```

服务本体里是 `LIBGL_ALWAYS_SOFTWARE=1`（保证没有 GPU 时也能起来），这个 drop-in
在服务层把它覆盖回 0，只让 KWin 走 zink。其它应用仍按各自的默认走 llvmpipe，
见 [known-issues.md](known-issues.md)。

