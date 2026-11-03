#!/bin/sh
# TB371FC: hand the real logind graphical session to the user manager so that
# kwin_wayland can TakeDevice/card0 from plasma-kwin_wayland.service.
# Keep the PAM session alive across startplasma exits: restarting inside this
# loop avoids logind tearing down user@1000 and everything in it.
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
SID="$XDG_SESSION_ID"
if [ -z "$SID" ]; then
    SID=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v p="$$" '$5==p {print $1; exit}')
fi
echo "session id: '$SID' (env: '$XDG_SESSION_ID') leader $$" >> /tmp/plasma-session.log
[ -n "$SID" ] && systemctl --user set-environment XDG_SESSION_ID="$SID"

while :; do
    if [ -S /run/user/1000/bus ]; then
        systemctl --user set-environment XDG_SESSION_ID="$SID" 2>/dev/null
    fi
    setsid -w /usr/bin/startplasma-wayland
    echo "startplasma exited rc=$? at $(date '+%F %T'), restarting" >> /tmp/plasma-session.log
    sleep 2
done
