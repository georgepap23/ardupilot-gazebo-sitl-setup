# ArduPilot + Gazebo + QGroundControl (macOS)

A reproducible ArduCopter SITL development setup for Apple Silicon Macs:
native software-in-the-loop simulation, physically realistic flight in
Gazebo Harmonic, and QGroundControl as the ground control station —
verified end-to-end with an actual takeoff and hover.

## What's here

- **ArduPilot** (`ardupilot/`, git submodule) — the flight stack, built for SITL.
- **ardupilot_gazebo** (`ardupilot_gazebo/`, git submodule) — the official
  plugin that bridges ArduPilot's physics backend to Gazebo over UDP.
- **Dockerized SITL** (`docker-compose.yml`, `docker/`) — an alternative,
  reproducible way to build and run just the SITL binary in a container
  (Gazebo and QGroundControl still run natively — GUI passthrough in Docker
  isn't reliable on macOS).
- **SETUP_STATUS.md** — the full setup log: every command run, every
  macOS-specific issue hit (Homebrew tap trust, keg-only Qt5, Command Line
  Tools, GID collisions, etc.) and how it was fixed. Read this if something
  below doesn't work as expected.

## Capabilities

- Native ArduCopter SITL build and run (Apple Silicon)
- Gazebo Harmonic physics simulation via the `ardupilot_gazebo` plugin
  (IMU, GPS, and full rigid-body dynamics — not ArduPilot's built-in toy
  physics model)
- QGroundControl as the ground control station (arm, take off, fly, land)
- A Docker-based alternative for building/running SITL in an isolated,
  reproducible environment

## Prerequisites

- Apple Silicon Mac, recent macOS
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools (`xcode-select --install`)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — only
  needed for the Dockerized SITL path

## Quick start (native)

```bash
git clone --recurse-submodules https://github.com/georgepap23/ardupilot-gazebo-sitl-setup.git
cd ardupilot-gazebo-sitl-setup
```

**1. Build SITL:**
```bash
python3 -m venv .venv && source .venv/bin/activate
ardupilot/Tools/environment_install/install-prereqs-mac.sh -y
cd ardupilot/ArduCopter && sim_vehicle.py -w   # builds, then exits — Ctrl+C once it's done
```

**2. Install Gazebo Harmonic:**
```bash
brew tap osrf/simulation
brew trust osrf/simulation
brew install gz-harmonic
```

**3. Build the `ardupilot_gazebo` plugin:**
```bash
brew install rapidjson opencv gstreamer
cd ../../ardupilot_gazebo && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt@5
make -j4
```
Then add to your shell profile (`~/.zshrc`):
```bash
export GZ_SIM_SYSTEM_PLUGIN_PATH=/path/to/ardupilot_gazebo/build:$GZ_SIM_SYSTEM_PLUGIN_PATH
export GZ_SIM_RESOURCE_PATH=/path/to/ardupilot_gazebo/models:/path/to/ardupilot_gazebo/worlds:$GZ_SIM_RESOURCE_PATH
```

**4. Install QGroundControl:**
```bash
brew install --cask qgroundcontrol
```

**5. Run it** (three separate terminals — macOS can't run Gazebo's server
and GUI in one process):
```bash
# Terminal 1 — Gazebo server
cd ardupilot_gazebo/worlds && gz sim -s -r iris_runway.sdf

# Terminal 2 — Gazebo GUI
gz sim -g

# Terminal 3 — SITL
source .venv/bin/activate
cd ardupilot/ArduCopter
sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON --console
```
Open QGroundControl, add a manual **TCP** link to `127.0.0.1:5760` under
Application Settings → Comm Links, and connect. Arm in **GUIDED** mode and
use QGC's **Takeoff** action to fly.

## Alternative: Dockerized SITL

Builds and runs just the SITL binary in a container (Gazebo/QGC stay
native):
```bash
HOST_UID=$(id -u) HOST_GID=1000 docker compose build
HOST_UID=$(id -u) HOST_GID=1000 docker compose up
```
See `SETUP_STATUS.md` for port mappings, the macOS/Linux `host.docker.internal`
caveat, and why `HOST_GID` defaults to `1000` instead of your real GID.

## Troubleshooting

Every real issue hit while building this (Homebrew tap trust prompts, a
broken Command Line Tools install, Qt5 being keg-only, the macOS
server+GUI Gazebo limitation, ArduPilot `PreArm` frame-class errors, etc.)
is documented with its exact fix in **`SETUP_STATUS.md`**.
