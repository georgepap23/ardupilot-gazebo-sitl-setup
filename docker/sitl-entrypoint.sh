#!/bin/bash
set -euo pipefail

BINARY=/ardupilot/build/sitl/bin/arducopter
if [ ! -x "$BINARY" ]; then
    echo "SITL binary not found — building (first run only)..."
    # Per upstream BUILD.md's own documented Docker workflow: build via the
    # ./waf wrapper from the repo root, not waf-light directly from a
    # vehicle subdirectory (waf-light alone doesn't load ArduPilot's custom
    # --board option, which lives in the root wscript).
    cd /ardupilot
    ./waf configure --board sitl
    ./waf copter
fi

SIM_ADDRESS="${SIM_ADDRESS:-host.docker.internal}"

echo "Starting ArduCopter SITL (model=JSON, sim-address=$SIM_ADDRESS)"
echo "  GCS (MAVLink):      tcp:5760"
echo "  Gazebo FDM in:      udp:9003"
echo "  Servo output out:   udp:$SIM_ADDRESS:9002"

cd /ardupilot/ArduCopter
exec "$BINARY" \
    --model JSON \
    --speedup 1 \
    --sim-address="$SIM_ADDRESS" \
    --sim-port-in=9003 \
    --sim-port-out=9002 \
    -I0 \
    "$@"
