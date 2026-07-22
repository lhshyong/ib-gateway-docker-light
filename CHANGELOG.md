# Changelog

All notable changes to this project are documented here.

## [Unreleased] - stable

IB Gateway `10.37.1r` -> `10.45.1h`, plus a stability and image-size pass over the
`stable` image. Target: a container that runs unattended for a week or more, with the
Gateway performing its own daily restart and no human intervention in between.

Image size `1.21GB` -> `~1.0GB`; installed packages `402` -> `268`.

### Added

- `tini` as `ENTRYPOINT`. As PID 1 a plain shell ignores `SIGTERM` outright (the kernel
  does not apply default signal handlers to PID 1), so every `docker stop` previously
  ended in `SIGKILL` and exit code `137`. The container now terminates on request and
  exits `143`, which also lets monitoring tell a normal stop apart from a crash.
- `procps`, `fontconfig`, `fonts-dejavu-core` as explicit dependencies. All three were
  present only transitively (fontconfig/dejavu via `libpango`, procps via
  `dconf-service`). Swing renders the login dialog through fontconfig and IBC's scripts
  call `pgrep`, so a future dependency change could have silently broken VNC login.
- `libasound2t64`. The bundled JRE's `libjsound.so` and `libgstreamer-lite.so` had an
  unresolved `libasound.so.2`, causing Java sound initialisation to fail.
- `xfonts-base` for x11vnc's core X11 bitmap fonts (`/usr/share/fonts/X11` was absent).
- `ca-certificates` in the runtime stage. Java TLS uses the JRE's own truststore so
  nothing was broken, but nothing else in the image had a CA bundle.
- Watchdog for `x11vnc` in `run.sh`, see Fixed below.
- Supervision loop for `socat` in `fork_ports_delayed.sh`, see Fixed below.

### Changed

- **JVM GC threads.** The installer hardcodes `-XX:ParallelGCThreads=20` and
  `-XX:ConcGCThreads=5` into `ibgateway.vmoptions`, sized for a desktop. Explicit flags
  override the JVM's container-aware ergonomics, so these were honoured verbatim even
  under a 2-CPU limit (verified: the JVM would otherwise have chosen 2 and 1). On a
  small host this runs the GC ~10x oversubscribed, lengthening stop-the-world pauses and
  burning CPU quota, which under a cgroup limit can trigger throttling. Pinned to `8`/`2`
  as a value that suits all target environments and caps the case where no CPU limit is
  set at all (ergonomics would otherwise scale to the whole node).
  Heap is left at the installer's `-Xmx768m`.
- **Runtime package set.** Removed `libgtk-3-dev`, `libxslt-dev` and `libgtk2.0-bin`.
  The first two are development packages — headers and toolchain, pulled in for no
  runtime benefit, and responsible for most of the size reduction. Replaced with the
  runtime equivalents `libgtk-3-0t64` and `libxslt1.1`. `libgtk-3-0` was also renamed to
  `libgtk-3-0t64`, the real package on Ubuntu 24.04 rather than the transitional stub.
  Verified: Gateway starts, login dialog opens, no font/AWT/sound errors.
- `run.sh` now `exec`s `ibcstart.sh` instead of running it as a child. Without this,
  tini's `SIGTERM` stopped at `run.sh` and never reached Java, so the Gateway was still
  killed at teardown. IBC already had a `TERM` trap waiting for a signal that never
  arrived. Shutdown now logs `IBC returned exit status 143` / `Gateway finished`.
- `socat` now runs with `reuseaddr` (rebinds immediately rather than failing on a socket
  in `TIME_WAIT`) and `nodelay` on both sides (Nagle otherwise delays the small writes
  the TWS API makes).
- Merged the `apt-get update`/`install` layers and added `rm -rf /var/lib/apt/lists/*`,
  removing a stale-cache trap and the package lists from the image.
- `IB_GATEWAY_VERSION`, `IB_GATEWAY_RELEASE_CHANNEL` and `IBC_VERSION` are now global
  `ARG`s declared once before the first `FROM`, instead of being repeated per stage.
- Added `ENV TZ=Etc/UTC` and `ENV NO_AT_BRIDGE=1`, the latter skipping GTK3's at-spi
  accessibility bus lookup, which otherwise waits for a timeout as no dbus daemon runs.

### Fixed

- **VNC intermittently unavailable for the entire life of a container.** `x11vnc` exits
  immediately and never retries if the X display is not yet up, and `run.sh` started it
  with zero delay after `Xvfb`. On a loaded host `Xvfb` loses the race, `x11vnc` dies at
  startup, and VNC is gone until the container is recreated — while the Gateway starts
  and trades normally, so nothing appears wrong. `run.sh` now retries every 15s, which
  covers both this startup race and any later crash. Verified both cases.
- **API port lost permanently if `socat` exited.** It was started once; if it stopped,
  the port stayed dead for the rest of the container's life while the container remained
  healthy and the Gateway kept running. Now supervised in a loop that restarts it after
  5s and logs the event, so a flapping proxy is visible instead of silent.

### Known issues / not yet addressed

- `set -x` in `run.sh` writes `TWS_PASSWORD` and `VNC_SERVER_PASSWORD` in cleartext to
  the Docker log stream (confirmed: one occurrence each, `--pw=<password>`). Not written
  to any on-disk log.
- Gateway, IBC and x11vnc logs accumulate in the container's writable layer with no
  rotation. Acceptable for a weekly recreate; a slow disk fill beyond that.
- `update.sh` regenerates `stable/` from `Dockerfile.template` and overwrites
  `stable/scripts/` from `image-files/`, so the next version bump reverts everything
  above. The template is also still on `ubuntu:22.04` with IBC `3.20.0`. Changes need
  porting to those sources.
- Only `stable/` was updated. `latest/`, `stable-tws/`, `latest-tws/` and `image-files/`
  still carry the original scripts.

### Deployment notes

- Java takes ~6s to shut down cleanly. Docker's default 10s stop timeout works but is
  not much margin — consider `--stop-timeout 30` / `stop_grace_period: 30s`
  (Kubernetes' default `terminationGracePeriodSeconds: 30` is already sufficient).
- `ENTRYPOINT` is now set, so a command override on `docker run` is appended to tini
  rather than replacing the entrypoint.
- Dropping the pre-`socat` delay was considered and rejected: the initial `sleep 30` is
  kept so early clients get a clean connection refusal rather than being accepted and
  immediately dropped. Note the Gateway only listens on 4000 after a successful login,
  which with manual 2FA can be well beyond 30s.
