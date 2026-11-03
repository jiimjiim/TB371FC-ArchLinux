#!/bin/sh
n=0
while [ $n -lt 150 ]; do
  if [ -e /dev/dri/renderD128 ] && [ -r /dev/ion ]; then
    exit 0
  fi
  sleep 0.2
  n=$((n+1))
done
exit 0
