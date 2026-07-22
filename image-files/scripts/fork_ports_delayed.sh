#!/bin/sh

sleep 30

if [ "$TRADING_MODE" = "paper" ]; then
  PORT=4002
else
  PORT=4001
fi

printf "Forking :::4000 onto 0.0.0.0:%s\n" "$PORT"

# Kept alive in a loop: socat used to be run once, so if it ever exited the API port
# was gone for the rest of the container's life while everything else kept running.
# reuseaddr lets it rebind immediately instead of failing on a socket in TIME_WAIT.
# nodelay disables Nagle on both sides, which otherwise stalls the small writes the
# TWS API makes. The initial sleep is kept deliberately: it holds the port closed
# during startup so early clients get a clean "connection refused" instead of being
# accepted and immediately dropped. (The Gateway itself only begins listening on
# 4000 after a successful login, which with manual 2FA can be much later than this.)
while true; do
  socat TCP-LISTEN:${PORT},fork,reuseaddr,nodelay TCP:127.0.0.1:4000,nodelay
  printf "socat exited (rc=%s), restarting in 5s\n" "$?"
  sleep 5
done
