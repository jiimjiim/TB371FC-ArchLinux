#!/bin/sh
d="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
n=0
while [ $n -lt 100 ]; do
  if [ -S "$d/wayland-0" ] || [ -S "$d/wayland-1" ]; then
    exit 0
  fi
  sleep 0.1
  n=$((n+1))
done
exit 0
