#!/bin/sh
set -x

export DISPLAY=:1

rm -f /tmp/.X1-lock
Xvfb :1 -ac -screen 0 1024x768x24 &

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
# own TERM trap, which stops Gateway cleanly instead of it being SIGKILLed at teardown.
exec /root/ibc/scripts/ibcstart.sh "${TWS_MAJOR_VRSN}" -g \
     "--tws-path=${TWS_PATH}" \
     "--ibc-path=${IBC_PATH}" "--ibc-ini=${IBC_INI}" \
     "--user=${TWS_USERID}" "--pw=${TWS_PASSWORD}" "--mode=${TRADING_MODE}" \
     "--on2fatimeout=${TWOFA_TIMEOUT_ACTION}"


# uncomment this to keep image alive.
# exec tail -f /dev/null