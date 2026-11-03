#!/bin/sh
# TB371FC: the Novatek touch controller does not start scanning after a cold
# boot (its IRQ line stays silent until the SPI driver is re-probed once the
# panel is powered). Re-init it automatically after the display is up.
i=0
while [ $i -lt 60 ]; do
    dpms=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)
    if pgrep -x kwin_wayland >/dev/null 2>&1 && [ "$dpms" = "On" ]; then
        break
    fi
    i=$((i + 1))
    sleep 1
done
sleep 8
if [ -e /sys/bus/spi/drivers/NVT-ts/spi0.0 ]; then
    echo spi0.0 > /sys/bus/spi/drivers/NVT-ts/unbind
    sleep 1
    echo spi0.0 > /sys/bus/spi/drivers/NVT-ts/bind
fi
