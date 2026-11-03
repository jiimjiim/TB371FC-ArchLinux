# vk-drm-shim

一个极小的 Vulkan 层，给 Turnip（kgsl 后端）补上 `VkPhysicalDeviceDrmPropertiesEXT`，
让 Mesa 的 zink 能选中 GPU 而不是回退 llvmpipe。

背景与验证方法见 [docs/gpu-zink-turnip-drm-shim.md](../../docs/gpu-zink-turnip-drm-shim.md)。

```bash
make                 # 生成 libvk_drm_shim.so
sudo make install    # /usr/local/lib + /usr/share/vulkan/explicit_layer.d
```

需要 `vulkan-headers`。层是 explicit 类型，必须通过
`VK_INSTANCE_LAYERS=VK_LAYER_TB371FC_drm_shim` 启用。

`prebuilt/libvk_drm_shim.so` 是 aarch64 预编译版本，内容和本目录源码一致，
方便没装编译工具链的设备直接用。

| 环境变量 | 默认 | 说明 |
|---|---|---|
| `TB_DRM_RENDER` | `226:128` | render node 的 major:minor |
| `TB_DRM_PRIMARY` | `226:0` | primary node 的 major:minor |

只在驱动返回 0 时填充，不会覆盖真实值。
