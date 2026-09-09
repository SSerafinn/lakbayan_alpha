#!/bin/sh
# Start a virtual X display, then run the command.
#
# MapLibre Native opens an X display through GLFW even when it renders
# offscreen. Without one it aborts with "Failed to open X display" and a core
# dump — a failure that reads as a broken install rather than a missing
# display, which is why this is the entrypoint and not a prefix somebody has
# to remember.
#
# **Not `xvfb-run`.** That wrapper deadlocks when it is PID 1: it backgrounds
# the server and then waits, and as PID 1 it is also responsible for reaping,
# so the container hangs before the command runs at all — no output, no error.
# It works fine as a child, which is what makes the failure so confusing to
# reproduce by hand. Starting Xvfb directly and exec'ing the command keeps the
# real work as PID 1 and leaves signals intact.
set -eu

DISPLAY_NUM="${XVFB_DISPLAY:-99}"
export DISPLAY=":$DISPLAY_NUM"

Xvfb "$DISPLAY" -screen 0 1280x1024x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &

# Poll rather than sleep a fixed interval: the server is usually up in well
# under a second, and a fixed wait is either wasted time or an intermittent
# failure depending on how loaded the host is.
attempts=0
until xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; do
  attempts=$((attempts + 1))
  if [ "$attempts" -gt 100 ]; then
    echo "Xvfb did not come up on $DISPLAY after 10s. Its log:" >&2
    cat /tmp/xvfb.log >&2
    exit 1
  fi
  sleep 0.1
done

exec "$@"
