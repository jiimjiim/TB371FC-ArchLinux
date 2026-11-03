# zink 选不中 GPU：Turnip 在 kgsl 下不发 DRM 属性

## 现象

KWin 起不来硬件合成，Mesa 日志：

```
MESA: error: ZINK: failed to choose pdev
```

所有渲染回退到 llvmpipe，`eglinfo -B` 里 renderer 是 `llvmpipe` 而不是 `zink (Turnip)`。

## 根因

zink 通过 `VK_EXT_physical_device_drm` 里的 render major/minor 去匹配 EGL 打开的
DRM 设备。Turnip 在 kgsl 平台上把该扩展的填充关掉了：

```c
.EXT_physical_device_drm = !is_kgsl(...)
```

于是这个属性永远是 0:0，zink 永远匹配不上 `/dev/dri/card0`。

## 修法

一个极小的 Vulkan 层，在 `vkGetPhysicalDeviceProperties2` 返回后，把
`VkPhysicalDeviceDrmPropertiesEXT` 补上（**只在驱动返回 0 时才填**，不覆盖真实值）：

- render：`226:128`
- primary：`226:0`
- 可用 `TB_DRM_RENDER` / `TB_DRM_PRIMARY` 覆盖（格式 `major:minor`）

文件：

```
src/vk-drm-shim/drm_shim.c
src/vk-drm-shim/VK_LAYER_TB371FC_drm_shim.json
src/vk-drm-shim/prebuilt/libvk_drm_shim.so   # aarch64 预编译，可直接用
```

## 编译与安装

```bash
pacman -S vulkan-headers
cd src/vk-drm-shim && make          # 或直接用 prebuilt/
sudo make install                   # 装到 /usr/local/lib + /usr/share/vulkan/explicit_layer.d
```

层是 explicit 类型，需要显式启用：

```bash
export VK_INSTANCE_LAYERS=VK_LAYER_TB371FC_drm_shim
```

KWin 的 drop-in `config/kwin/kwin_wayland.d/35-vk-drm-shim.conf` 已经带了这个变量。

## 验证

```bash
eglinfo -B | grep -i renderer
# 期望：OpenGL renderer string: zink (Turnip)

journalctl -b | grep -i "Added render device"
# 期望：Added render device /dev/dri/card0: zink Vulkan 1.3
```

层激活时 stderr 会打印一行 `[drm-shim] active render=226:128 primary=226:0`。

## 同一条链路上的另外两个补丁

### Turnip 拒绝 `VK_KHR_display`

Mesa 的 KGSL 后端在启用 `VK_KHR_display` 时会把整个设备判为不可用。
`tools/tb371fc-turnip-kgsl-patch` 把 `libvulkan_freedreno.so` 里 `0x125354`
处的条件跳转改成无条件分支：

```
0x125354: 98020036 (tbz ...)  ->  14000014 (b ...)
```

- 只针对 oibaf 的 `mesa 25.0~git2501270600.dea4b4~oibaf-turnip-kgsl~n arm64`
- 脚本校验原始字节，不匹配就拒绝改动；**mesa 升级后需要重新定位**
- 备份为 `libvulkan_freedreno.so.ppa-orig`

### 权限和 ICD

- `config/udev/50-kgsl.rules`：`kgsl-3d0` 归 `render` 组、0660
- `config/udev/51-ion.rules`：`ion` 0666
- `config/plasma.service.d/20-zink.conf`：给会话注入
  `MESA_LOADER_DRIVER_OVERRIDE=zink`、`GALLIUM_DRIVER=zink`、
  `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.json`

## 说明

- 这个坑不限于 TB371FC：任何 kgsl 平台 + Turnip + zink 的组合都会撞上。
- 数值 226 是 DRM 的 major，128/0 是这台机器上 renderD128 和 card0 的 minor；
  换设备时按 `ls -l /dev/dri/` 改环境变量即可。
- 只有 KWin 拿到了 GPU；其它应用仍是 llvmpipe，见 [known-issues.md](known-issues.md)。
