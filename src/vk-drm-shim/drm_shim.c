#include <vulkan/vulkan.h>
#include <vulkan/vk_layer.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define LAYER_NAME "VK_LAYER_TB371FC_drm_shim"

static PFN_vkGetInstanceProcAddr g_next_gipa;
static VkInstance g_instance;
static PFN_vkGetPhysicalDeviceProperties2 g_p2;
static PFN_vkGetDeviceProcAddr g_next_gdpa;
static unsigned g_major = 226, g_minor = 128;
static unsigned g_pmaj = 226, g_pmin = 0;

static void read_env(void)
{
    const char *r = getenv("TB_DRM_RENDER");
    const char *p = getenv("TB_DRM_PRIMARY");
    if (r) sscanf(r, "%u:%u", &g_major, &g_minor);
    if (p) sscanf(p, "%u:%u", &g_pmaj, &g_pmin);
}

static void fill_drm(VkPhysicalDeviceProperties2 *p2)
{
    for (VkBaseOutStructure *s = (VkBaseOutStructure *)p2->pNext; s; s = s->pNext) {
        if (s->sType == VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRM_PROPERTIES_EXT) {
            VkPhysicalDeviceDrmPropertiesEXT *d = (VkPhysicalDeviceDrmPropertiesEXT *)s;
            if (d->renderMajor == 0 && d->primaryMajor == 0) {
                d->hasPrimary = VK_TRUE;
                d->primaryMajor = g_pmaj;
                d->primaryMinor = g_pmin;
                d->hasRender = VK_TRUE;
                d->renderMajor = g_major;
                d->renderMinor = g_minor;
            }
        }
    }
}

static VKAPI_ATTR void VKAPI_CALL shim_props2(VkPhysicalDevice pd, VkPhysicalDeviceProperties2 *p2)
{
    if (!g_p2 && g_next_gipa)
        g_p2 = (PFN_vkGetPhysicalDeviceProperties2)g_next_gipa(g_instance, "vkGetPhysicalDeviceProperties2");
    if (g_p2) g_p2(pd, p2);
    fill_drm(p2);
}

static VKAPI_ATTR VkResult VKAPI_CALL shim_CreateInstance(const VkInstanceCreateInfo *ci,
        const VkAllocationCallbacks *ac, VkInstance *out)
{
    VkLayerInstanceCreateInfo *chain = (VkLayerInstanceCreateInfo *)ci->pNext;
    while (chain && !(chain->sType == VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO &&
                      chain->function == VK_LAYER_LINK_INFO))
        chain = (VkLayerInstanceCreateInfo *)chain->pNext;
    if (!chain) return VK_ERROR_INITIALIZATION_FAILED;
    PFN_vkGetInstanceProcAddr next_gipa = chain->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    chain->u.pLayerInfo = chain->u.pLayerInfo->pNext;
    PFN_vkCreateInstance next = (PFN_vkCreateInstance)next_gipa(NULL, "vkCreateInstance");
    VkResult r = next(ci, ac, out);
    if (r == VK_SUCCESS) {
        g_next_gipa = next_gipa;
        g_instance = *out;
        read_env();
        fprintf(stderr, "[drm-shim] active render=%u:%u primary=%u:%u\n", g_major, g_minor, g_pmaj, g_pmin);
    }
    return r;
}

static VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL shim_gipa(VkInstance inst, const char *name);
static VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL shim_gdpa(VkDevice dev, const char *name)
{
    return g_next_gdpa ? g_next_gdpa(dev, name) : NULL;
}

static VKAPI_ATTR VkResult VKAPI_CALL shim_CreateDevice(VkPhysicalDevice pd,
        const VkDeviceCreateInfo *ci, const VkAllocationCallbacks *ac, VkDevice *out)
{
    VkLayerDeviceCreateInfo *chain = (VkLayerDeviceCreateInfo *)ci->pNext;
    while (chain && !(chain->sType == VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO &&
                      chain->function == VK_LAYER_LINK_INFO))
        chain = (VkLayerDeviceCreateInfo *)chain->pNext;
    if (!chain) return VK_ERROR_INITIALIZATION_FAILED;
    g_next_gdpa = chain->u.pLayerInfo->pfnNextGetDeviceProcAddr;
    chain->u.pLayerInfo = chain->u.pLayerInfo->pNext;
    PFN_vkCreateDevice next = (PFN_vkCreateDevice)g_next_gipa(g_instance, "vkCreateDevice");
    return next(pd, ci, ac, out);
}

static VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL shim_gipa(VkInstance inst, const char *name)
{
    if (!strcmp(name, "vkGetInstanceProcAddr")) return (PFN_vkVoidFunction)shim_gipa;
    if (!strcmp(name, "vkCreateInstance")) return (PFN_vkVoidFunction)shim_CreateInstance;
    if (!strcmp(name, "vkCreateDevice")) return (PFN_vkVoidFunction)shim_CreateDevice;
    if (!strcmp(name, "vkGetPhysicalDeviceProperties2")) return (PFN_vkVoidFunction)shim_props2;
    if (!strcmp(name, "vkGetPhysicalDeviceProperties2KHR")) return (PFN_vkVoidFunction)shim_props2;
    return g_next_gipa ? g_next_gipa(inst, name) : NULL;
}

VKAPI_ATTR VkResult VKAPI_CALL vkNegotiateLoaderLayerInterfaceVersion(VkNegotiateLayerInterface *pvi)
{
    if (pvi->sType != LAYER_NEGOTIATE_INTERFACE_STRUCT) return VK_ERROR_INITIALIZATION_FAILED;
    if (pvi->loaderLayerInterfaceVersion > 2) pvi->loaderLayerInterfaceVersion = 2;
    pvi->pfnGetInstanceProcAddr = shim_gipa;
    pvi->pfnGetDeviceProcAddr = shim_gdpa;
    pvi->pfnGetPhysicalDeviceProcAddr = NULL;
    return VK_SUCCESS;
}
