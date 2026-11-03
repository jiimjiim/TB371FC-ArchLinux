#!/bin/sh
CONF=/etc/tb371fc/chglimit.conf
PS=/sys/class/power_supply/battery
ENABLE=0
END=80
START=75
POLL=30

[ -r "$CONF" ] && . "$CONF"

ENABLE=${CHG_LIMIT_ENABLE:-0}
END=${CHG_LIMIT_END:-80}
START=${CHG_LIMIT_START:-75}
POLL=${CHG_LIMIT_POLL:-30}

[ -e "$PS/charging_enabled" ] || exit 0

while :; do
    cap=$(cat "$PS/capacity" 2>/dev/null)
    case "$cap" in
        ''|*[!0-9]*) sleep "$POLL"; continue ;;
    esac
    en=$(cat "$PS/charging_enabled" 2>/dev/null)
    if [ "$ENABLE" = "1" ]; then
        if [ "$cap" -ge "$END" ] && [ "$en" != "0" ]; then
            echo 0 > "$PS/charging_enabled"
        elif [ "$cap" -le "$START" ] && [ "$en" != "1" ]; then
            echo 1 > "$PS/charging_enabled"
        fi
    fi
    sleep "$POLL"
done
