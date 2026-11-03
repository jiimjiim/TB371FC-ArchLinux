CC ?= gcc
CFLAGS ?= -O2 -fPIC -Wall -Wextra
PREFIX ?= /usr/local
LAYERDIR ?= /usr/share/vulkan/explicit_layer.d

all: libvk_drm_shim.so

libvk_drm_shim.so: drm_shim.c
	$(CC) -shared $(CFLAGS) -o $@ $<

install: libvk_drm_shim.so
	install -Dm755 libvk_drm_shim.so $(DESTDIR)$(PREFIX)/lib/libvk_drm_shim.so
	install -Dm644 VK_LAYER_TB371FC_drm_shim.json $(DESTDIR)$(LAYERDIR)/VK_LAYER_TB371FC_drm_shim.json

clean:
	rm -f libvk_drm_shim.so

.PHONY: all install clean
