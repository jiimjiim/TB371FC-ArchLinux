#!/bin/sh
exec >>/var/log/tb-loadwatch.log 2>&1
while true; do
  printf '%s load=%s ' "$(date '+%F %T')" "$(cut -d' ' -f1-3 /proc/loadavg)"
  awk '/MemAvailable|SwapFree/ {printf "%s=%dMB ", $1, int($2/1024)}' /proc/meminfo
  printf '
'
  top -b -n1 -o %CPU 2>/dev/null | sed -n '8,13p'
  sleep 10
done
