#!/bin/sh
set -x

export DISPLAY=:1

rm -f /tmp/.X1-lock
Xvfb :1 -ac -screen 0 1280x800x16 &

if [ -n "$VNC_SERVER_PASSWORD" ]; then
  echo "Starting VNC server"
  /root/scripts/run_x11_vnc.sh &
fi

envsubst < "${IBC_INI}.tmpl" > "${IBC_INI}"

/root/scripts/fork_ports_delayed.sh &

/root/ibc/scripts/ibcstart.sh "${TWS_MAJOR_VRSN}" \
     "--tws-path=${TWS_PATH}" \
     "--ibc-path=${IBC_PATH}" "--ibc-ini=${IBC_INI}" \
     "--user=${TWS_USERID}" "--pw=${TWS_PASSWORD}" "--mode=${TRADING_MODE}" \
     "--on2fatimeout=${TWOFA_TIMEOUT_ACTION}"


# uncomment this to keep image alive.
# exec tail -f /dev/null