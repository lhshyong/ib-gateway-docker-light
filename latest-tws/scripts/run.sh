#!/bin/sh
set -x

export DISPLAY=:1

rm -f /tmp/.X1-lock
# 24-bit, not 16: TWS bundles JxBrowser (Chromium), which expects 24/32-bit colour.
# The Gateway image was already moved 16 -> 24 for the same rendering reasons.
Xvfb :1 -ac -screen 0 1280x800x24 &

# With no window manager, TWS maps its windows wherever it likes and nothing on screen
# can be moved or resized over VNC - the point of the VNC session is for a human to
# drive TWS, so a WM is required. blackbox is small (~11MB) and gives titlebars,
# drag and resize. Retried for the same reason as x11vnc below: it exits at once if
# :1 isn't up yet, which would otherwise leave windows unmanaged for the whole session.
( while true; do
    pgrep -x blackbox >/dev/null 2>&1 || blackbox
    sleep 15
  done ) &

if [ -n "$VNC_SERVER_PASSWORD" ]; then
  echo "Starting VNC server"
  # x11vnc exits immediately (and never retries) if :1 isn't up yet, which loses VNC
  # for the whole life of the container. Retry so it survives both that startup race
  # and any later crash - VNC is the only way in to complete the login.
  ( while true; do
      pgrep -x x11vnc >/dev/null 2>&1 || /root/scripts/run_x11_vnc.sh
      sleep 15
    done ) &
fi

envsubst < "${IBC_INI}.tmpl" > "${IBC_INI}"

/root/scripts/fork_ports_delayed.sh &

# exec so this shell is replaced by ibcstart.sh: SIGTERM from tini then lands on IBC's
# own TERM trap, which stops TWS cleanly instead of it being SIGKILLed at teardown.
# No -g: this image runs TWS, not Gateway.
exec /root/ibc/scripts/ibcstart.sh "${TWS_MAJOR_VRSN}" \
     "--tws-path=${TWS_PATH}" \
     "--ibc-path=${IBC_PATH}" "--ibc-ini=${IBC_INI}" \
     "--user=${TWS_USERID}" "--pw=${TWS_PASSWORD}" "--mode=${TRADING_MODE}" \
     "--on2fatimeout=${TWOFA_TIMEOUT_ACTION}"


# uncomment this to keep image alive.
# exec tail -f /dev/null
