# ksystemstats Adreno GPU 插件

KDE System Monitor 的 GPU 传感器插件，直接读 `/sys/class/kgsl/kgsl-3d0/`：

| 传感器 | sysfs |
|---|---|
| usage | `gpu_busy_percentage` |
| coreFrequency | `gpuclk`（Hz → MHz） |
| temperature | `temp`（毫摄氏度 → ℃） |

自带的 GPU 插件只认 AMD/NVIDIA/Xe，这台机器上拿不到数据。

## 编译

需要 Plasma 6.8 的 `ksystemstats` 开发头文件（`systemstats/Sensor*.h`）和 KF6。
在 `ksystemstats` 源码树里编译时把本文件作为新插件加入即可；独立编译时需要把
`systemstats` 头文件的 include 路径指到 `ksystemstats/src/`。

```bash
moc adrenogpu.cpp -o adrenogpu.moc   # 末尾 #include "adrenogpu.moc"
```

安装位置通常是 `/usr/lib/qt6/plugins/ksystemstats/`，文件名必须是
`ksystemstats_plugin_gpu.so` —— 也就是**覆盖自带的 GPU 插件**（自带插件只认
AMD/NVIDIA/Xe，在这台机器上拿不到数据）。

## 一个坑

`K_PLUGIN_FACTORY_WITH_JSON` 展开后 moc 抓不到 `Q_PLUGIN_METADATA`，插件不会被加载。
这里改成手写 `KPluginFactory` 子类并显式写：

```cpp
class AdrenoGpuPluginFactory : public KPluginFactory
{
    Q_OBJECT
    Q_INTERFACES(KPluginFactory)
    Q_PLUGIN_METADATA(IID "org.kde.KPluginFactory" FILE "ksystemstats_plugin_adreno.json")
```

同目录的 `ksystemstats_plugin_adreno.json` 是这个元数据文件。
