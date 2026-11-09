# ArduPilot + Gazebo + QGroundControl macOS Setup — Status

Working dir for this project: `~/Documents/ArduPilot` (moved here from Desktop).

## Why this file exists
The Claude Code session that did the work below was originally anchored (sandboxed)
to `~/Desktop/ArduPilot`. The whole project folder was later moved to
`~/Documents/ArduPilot` per request, which broke that session's ability to
*execute* scripts/binaries here (read/list still worked, but running scripts did
not — exit 126 "permission denied" from the sandbox). Restarting Claude Code with
cwd = `~/Documents/ArduPilot` fixes this since the sandbox anchors to the actual
launch directory.

## Target machine
- Apple Silicon Mac (arm64), macOS 26.5.2
- Homebrew at /opt/homebrew
- Decision: using a **dedicated venv** (`.venv` in this folder, built from
  Homebrew's `python3.12`) instead of the system `python3`, because `~/.zshrc`
  prepends `~/.platformio/penv/bin` to PATH (a Python 3.9 venv used for other,
  unrelated PlatformIO/embedded work) — we deliberately avoid installing
  ArduPilot's pip deps into that unrelated venv.

## Done
- [x] Verified Xcode CLT, Homebrew, git present.
- [x] Created `.venv` here: `python3.12 -m venv ~/Documents/ArduPilot/.venv`
- [x] Cloned ArduPilot with submodules into `~/Documents/ArduPilot/ardupilot`
      (`git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git`)
- [x] Added Gazebo Homebrew tap: `brew tap osrf/simulation`
- [x] **Ran macOS prereqs script** (brew gawk/coreutils/wget/ccache + pip deps:
      pymavlink, MAVProxy, wxPython, lxml, matplotlib, empy==3.3.4, etc.) into
      the venv. Added `Tools/autotest` and ccache to PATH via `~/.zshrc`.

      **Incident during this step, now resolved:** the `.venv` had been created
      *before* the Desktop→Documents move. Python venvs are not relocatable by
      `mv` — `pyvenv.cfg`, `bin/activate`, and the shebangs in `bin/pip`/`pip3`/
      `pip3.12` all hardcode the venv's absolute path at creation time. So
      `source .venv/bin/activate` was silently prepending a now-nonexistent
      `~/Desktop/ArduPilot/.venv/bin` to PATH, and `python3 -m pip install ...`
      fell through PATH to `~/.platformio/penv` (python3.9, an unrelated venv
      used for PlatformIO/embedded work) — installing all the ArduPilot pip
      deps there instead, and upgrading `packaging` 25.0→26.3 which broke
      `streamlit`'s pinned requirement in that env.
      **Fix applied:** uninstalled all the wrongly-added packages from
      `~/.platformio/penv` and restored `packaging==25.0` there (verified with
      `pip check`, clean). Deleted and recreated `.venv` fresh directly at
      `~/Documents/ArduPilot/.venv` (confirmed correct paths in `pyvenv.cfg`,
      `activate`, and `pip` shebang this time). Reran the prereqs script with
      stdin redirected from `/dev/null` instead of a `printf` pipe, since the
      pipe's answers were observed being silently consumed by an earlier `brew
      install` subprocess before reaching the script's own `read -p` prompts
      (all 3 ended up defaulting to "No" either way — correct for pyenv,
      and the autotest-PATH/ccache-PATH lines were added manually to `~/.zshrc`
      instead). Also removed the leftover empty `~/Desktop/ArduPilot/` folder.
      **Lesson for future moves of this project folder:** the venv must be
      deleted and recreated (not just left in place) after any directory move.

## Done (continued)
- [x] **Built ArduCopter SITL.** `sim_vehicle.py -w` (with `Tools/autotest` +
      ccache now on PATH per the `~/.zshrc` lines above) compiled cleanly:
      `'build' finished successfully (1m54.313s)`, binary at
      `ardupilot/build/sitl/bin/arducopter`.
      Note: when run non-interactively (no real TTY), MAVProxy's console hits
      EOF on stdin immediately and exits right after the heartbeat — this is
      expected and not a failure; MAVProxy needs an actual terminal to stay up.
      Verified the real success criterion (parameter reception) by running
      the `arducopter` binary directly and connecting with a short pymavlink
      script instead of MAVProxy: heartbeat received from system 1, **1453
      parameters received**. From now on, when actually *using* the sim day
      to day, just run `sim_vehicle.py -w` (or without `-w` after the first
      time) in a normal interactive Terminal — MAVProxy's console will behave
      normally there.
- [x] **Installed Gazebo Harmonic** (`gz-harmonic` 1.0.0, pulling in
      `gz-sim8` 8.15.0 and its full dependency chain — `gz-physics7`,
      `gz-sensors8`, `sdformat14`, ogre2, dartsim, etc.) via the
      `osrf/simulation` tap. Two real environment issues hit and fixed along
      the way, both one-time:
      1. **Untrusted tap gate.** Newer Homebrew refused to load the formula
         ("Refusing to load formula osrf/simulation/gz-harmonic from
         untrusted tap") until explicitly trusted:
         `brew trust osrf/simulation`. `osrf/simulation` is Open Robotics'
         own official tap for Gazebo — the tap itself was already added
         earlier in this project, just not yet trusted under this newer
         Homebrew policy.
      2. **Broken/unregistered Command Line Tools blocked the build.**
         `brew install gz-harmonic` built ~190 dependency bottles
         successfully, then failed at the final step with "Your Command
         Line Tools (CLT) does not support macOS 26. It is either outdated
         or was modified." `pkgutil --pkg-info com.apple.pkg.CLTools_Executables`
         showed no registered receipt at all, even though the CLT directory
         and `clang` itself were present and ran — i.e. the files existed
         but the installer's bookkeeping record of them didn't, which is
         exactly the "outdated or modified" signature. `softwareupdate
         --list` had no CLT update to offer, and `xcode-select --install`
         (tried first, non-destructively) refused with "already installed."
         Fix: `sudo rm -rf /Library/Developer/CommandLineTools` (removes the
         real but unregistered files — not a no-op, despite the missing
         receipt), then `xcode-select --install` to trigger a fresh
         download via Apple's own installer dialog. Confirmed after:
         `clang --version` → 21.0.0 (up from 17.0.0), and `pkgutil`
         now shows a proper registered receipt (`26.6.0.0...`).
      Verified with a bounded sanity run (`gz sim -s -r --iterations 50 -v 3`,
      output redirected to a file rather than piped through `tail`, since
      `tail` buffers until EOF and made the run look hung): "Gazebo Sim
      Server v8.15.0" started, loaded the default world, initialized
      physics, registered all standard world services (pose/state/scene/
      physics control), ran 50 iterations, and exited with code 0. The
      `Exception sending a multicast message: No route to host` lines in
      the log are a known, benign gz-transport peer-discovery warning on
      macOS network configs without a multicast-capable interface — not a
      functional problem.

## Done (continued, part 2)
- [x] **Built the `ardupilot_gazebo` plugin.** `rapidjson` was already present
      (pulled in earlier as a `gz-harmonic` dependency); installed
      `gstreamer` (1.28.9) and `opencv` (5.1.0) via brew, then cloned
      `https://github.com/ArduPilot/ardupilot_gazebo` into
      `~/Documents/ArduPilot/ardupilot_gazebo`. `GZ_VERSION` was left unset
      since Harmonic is the repo's default.
      **Real build issue hit and fixed:** plain
      `cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo` failed at the CMake
      *generate* step (configure step passed) with:
      `The link interface of target "gz-gui8::gz-gui8" contains: Qt5::Core
      but the target was not found.` Cause: `qt@5` (pulled in earlier as a
      `gz-harmonic` dependency, since `gz-gui8` links against Qt5) is
      **keg-only** in Homebrew — deliberately not symlinked into
      `/opt/homebrew`'s default search path because it conflicts with Qt6
      (`qtbase`, which installing `opencv` just brought in). CMake's
      `find_package(Qt5)` silently couldn't see it until pointed there
      explicitly:
      ```bash
      cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt@5
      ```
      With that, configure + `make -j4` succeeded cleanly, building all four
      plugin libraries in `ardupilot_gazebo/build/`: `libArduPilotPlugin.dylib`,
      `libCameraZoomPlugin.dylib`, `libGstCameraPlugin.dylib`,
      `libParachutePlugin.dylib`.
      **Verified functionally** (not just "it compiled"): with
      `GZ_SIM_SYSTEM_PLUGIN_PATH`/`GZ_SIM_RESOURCE_PATH` exported for the
      session, ran `gz sim -s -r --iterations 100 -v 3 iris_runway.sdf` from
      `ardupilot_gazebo/worlds/`. Log showed `ArduPilotPlugin` registering
      rotor joint force subscriptions for the iris model (`ApplyJointForce
      subscribing to Double messages on
      [/model/iris_with_gimbal/joint/iris_with_standoffs::rotor_0_joint/cmd_force]`
      etc. for all 4 rotors) — confirms the plugin loads and correctly
      wires up the model. The run then sat waiting rather than completing
      its 100 iterations; this is **expected**, not a bug: `ArduPilotPlugin`
      runs Gazebo and ArduPilot SITL in lockstep, holding each physics step
      until SITL sends the matching servo command, so without a live SITL
      instance connected it blocks indefinitely by design. (Benign,
      unrelated warnings also appeared: `XML Element[gz_frame_id]... not
      defined in SDF` — a known sdformat schema-version cosmetic warning,
      not a functional issue.)
      **Pending — needs your action, not done yet:** the two `export` lines
      below could not be added to `~/.zshrc` automatically — the auto-mode
      safety classifier blocks edits to shell startup/dotfiles outside the
      project as a "persistence" action requiring your explicit approval.
      Add these two lines to `~/.zshrc` yourself (they were used
      session-scoped, via plain `export`, for the verification above, but
      that doesn't persist to new terminals):
      ```bash
      export GZ_SIM_SYSTEM_PLUGIN_PATH=~/Documents/ArduPilot/ardupilot_gazebo/build:$GZ_SIM_SYSTEM_PLUGIN_PATH
      export GZ_SIM_RESOURCE_PATH=~/Documents/ArduPilot/ardupilot_gazebo/models:~/Documents/ArduPilot/ardupilot_gazebo/worlds:$GZ_SIM_RESOURCE_PATH
      ```
      One more thing worth knowing for the next end-to-end test: the
      binary currently at `ardupilot/build/sitl/bin/arducopter` is the
      **Linux** one built inside the Docker container (confirmed via
      `file`: `ELF 64-bit ... ARM aarch64 ... GNU/Linux`), left over from
      the earlier Dockerized-SITL work — not a native macOS build. It'll
      need a fresh native `sim_vehicle.py -w` (or `./waf copter`) run
      before step 3 below will work natively.
- [x] **Installed QGroundControl** via Homebrew cask
      (`brew install --cask qgroundcontrol`) rather than a manual download —
      a cask exists and requires only macOS ≥13 (fine on 26.5.2). Installed
      cleanly to `/Applications/QGroundControl.app`, version 5.1. Verified:
      Gatekeeper/`spctl` reports "accepted" (notarized Developer ID,
      `Donald Gagne (BDJKVNW2ZQ)` — QGC's actual upstream maintainer, a
      legitimate signature); launched via `open -a QGroundControl` and
      confirmed the process stays running (not an immediate crash).

## Done (continued, part 3) — full end-to-end verified
- [x] **Full native end-to-end stack confirmed working: Gazebo + `ardupilot_gazebo`
      plugin + native SITL + QGroundControl, with an actual takeoff and
      stable hover in Gazebo.** This is the capstone verification the whole
      setup was building toward.

      **Rebuilt SITL natively first** — the binary at
      `ardupilot/build/sitl/bin/arducopter` was still the Linux one left
      over from the Dockerized-SITL work (confirmed via `file`: `ELF 64-bit
      ... GNU/Linux`). Cleared `ardupilot/build/sitl` and rebuilt with
      `./waf configure --board sitl && ./waf copter` from the activated
      `.venv` — `'copter' finished successfully (4m58.720s)`, confirmed via
      `file` as `Mach-O 64-bit executable arm64` this time.

      **Real macOS-specific Gazebo limitation hit and worked around:**
      `gz sim -v4 -r iris_runway.sdf` (combined server+GUI, matching the
      upstream `ardupilot_gazebo` README's usage example) failed outright:
      `On macOS 'gz sim' currently only works with either the -s argument
      or the -g argument, you cannot run both server and gui in one
      terminal.` This is a known upstream limitation
      ([gazebosim/gz-sim#44](https://github.com/gazebosim/gz-sim/issues/44)),
      not specific to this setup. Fix: run them as two separate processes —
      `gz sim -s -v4 -r iris_runway.sdf` (server) then, a few seconds later,
      `gz sim -g` (GUI, connects to the already-running server over
      gz-transport). Both need the `GZ_SIM_SYSTEM_PLUGIN_PATH`/
      `GZ_SIM_RESOURCE_PATH` exports from the `ardupilot_gazebo` section
      above.

      **Verified the Gazebo↔SITL FDM link actually exchanged data** (not
      just "both processes started"): the SITL log showed
      `Home: -35.363262 149.165237 alt=584.000000m hdg=353.000000` and
      `JSON received: timestamp, imu: gyro, imu: accel_body, position,
      quaternion, velocity, ...` — i.e. SITL received real sensor data from
      the Gazebo plugin over the UDP JSON link, not a stub/default.
      Connecting with pymavlink (`tcp:127.0.0.1:5760`) got a heartbeat from
      system 1 and **1392 PARAM_VALUE** messages (close to the 1453 seen in
      the original native run and 1450 in the Docker container run — minor
      expected variance, not a concern), with the SITL process still alive
      and running afterward.

      **One environment quirk worth knowing for next time:** a first
      attempt at this same pymavlink check, run via `nohup ... & disown` in
      an earlier, separate tool call, saw the SITL process disappear
      partway through (an `EOF on TCP socket` flood from pymavlink's
      reconnect loop). Re-run in a way that stayed within a single
      synchronous command instead, it worked cleanly and stayed up for the
      rest of the session (eventually 17+ minutes of continuous runtime).
      This looks like a quirk of how this sandboxed environment reaps
      background processes across separate tool-call boundaries, not a bug
      in Gazebo/SITL/the plugin — worth keeping in mind if a background
      sim process seems to vanish unexpectedly between tool calls.

      **QGroundControl connection, step by step (since a manual TCP link —
      not auto-connect — is required, per the "GCS: QGroundControl stays
      primary" note above):**
      1. Added a TCP link to `127.0.0.1:5760` in Application Settings →
         Comm Links, as documented. First connection attempt showed as a
         brief connect/disconnect in the SITL log (`New connection on
         SERIAL0` / `Closed connection on SERIAL0`) — the link had been
         added but not actually connected yet. Clicking **Connect**
         explicitly on the link fixed it; confirmed via `lsof -i :5760`
         showing a genuine `ESTABLISHED` connection both ends.
      2. **PreArm failure encountered and fixed:** `PreArm: Motors: Check
         Frame Class and Type`. Cause: launching the raw `arducopter`
         binary directly (rather than through `sim_vehicle.py -f
         gazebo-iris`) skips loading the frame's default parameters — the
         SITL log even says so outright: `No vehicleinfo.json frame for
         model JSON: no default parameters loaded`. Looked up the correct
         values from ArduPilot's own
         `Tools/autotest/default_params/gazebo-iris.parm`:
         `FRAME_CLASS=1` (Quad), `FRAME_TYPE=1` (X). Set both through QGC's
         own Vehicle Setup → Parameters UI (not via a second MAVLink
         connection, since this SITL TCP backend only accepts one GCS
         client at a time — didn't want to risk contending with QGC's
         active link) and rebooted the vehicle when prompted.
      3. **QGC's TCP link did not auto-reconnect after that reboot** —
         expected QGC behavior for manually-added TCP links, not a bug.
         Reconnecting it manually (same Comm Links → Connect) fixed it.
      4. Armed via QGC, and after ~10s the vehicle auto-disarmed back to
         "Ready" — this is ArduCopter's normal `DISARM_DELAY` safety
         feature (default 10s, exactly matching what was observed), not a
         problem. Switched to **GUIDED** mode and used QGC's combined
         **Takeoff** action instead (arms + commands takeoff in one step,
         avoiding the idle-disarm window).
      5. **Result: the vehicle took off and is hovering stably in Gazebo**,
         confirming the complete chain — QGC command → SITL flight
         controller logic → Gazebo physics (via the `ardupilot_gazebo`
         plugin) → visible result in the Gazebo GUI window.

      As of this writing, all four processes (Gazebo server, Gazebo GUI,
      native SITL, QGroundControl) are still running and the vehicle is
      still hovering, left running intentionally per request.

      **Known gap for next time, not yet resolved:** since the raw binary
      was launched directly, other `gazebo-iris.parm` defaults beyond
      `FRAME_CLASS`/`FRAME_TYPE` (precision-landing/IRLock rangefinder
      settings) were never loaded either. They weren't needed for this
      basic takeoff/hover test, but a future session wanting the full
      intended default configuration should either use
      `sim_vehicle.py -v ArduCopter -f gazebo-iris --model JSON` (which
      loads `default_params/copter.parm` + `default_params/gazebo-iris.parm`
      automatically, per `Tools/autotest/pysim/vehicleinfo.json`), or pass
      `--defaults` explicitly to the raw binary invocation.

## Alternative: Dockerized SITL

A reproducible, headless alternative to the native `.venv`-based SITL build
above. Uses ArduPilot's own upstream `ardupilot/Dockerfile` as-is (not
modified) as a build-environment image, with the vendored `ardupilot/`
source bind-mounted in rather than baked into the image. Gazebo and
QGroundControl stay **native** on macOS — GPU/GUI passthrough into Docker is
unreliable on macOS, and there's no portability benefit for a thin native
MAVLink client like QGC.

New files (all live outside `ardupilot/` to keep that vendored upstream tree
pristine/diffable against future `git pull`s):
- `docker-compose.yml` — builds `ardupilot/Dockerfile`, bind-mounts
  `./ardupilot` to `/ardupilot` and `./docker/sitl-entrypoint.sh` into the
  container, publishes `5760/tcp` (GCS/MAVLink) and `9003/udp` (Gazebo → SITL
  FDM-in). Port `9002/udp` (SITL → Gazebo servo-out) is intentionally **not**
  published since that direction is outbound-only from the container.
- `docker/sitl-entrypoint.sh` — scoped to ArduCopter only. Builds the SITL
  binary on first run only (`./waf configure --board sitl` + `./waf copter`,
  run from `/ardupilot`) if it doesn't already exist at
  `build/sitl/bin/arducopter`, then execs it with `--model JSON` and the
  Gazebo-matching ports. To force a rebuild after ArduPilot source changes,
  delete `ardupilot/build/sitl` on the host before the next `docker compose up`.
- `.env.example` — template for `HOST_UID`/`HOST_GID` build args (Compose
  does not auto-read `$UID`/`$GID` from the shell; copy to `.env` or export
  in-shell). This machine's values: `HOST_UID=501` (from `id -u`),
  `HOST_GID=1000` (deliberately **not** `id -g` — see caveat below).
- `.gitignore` — excludes `.venv/`, `ardupilot/build/`, `.DS_Store`, etc.

### Two environment-specific gotchas found and fixed during verification
These aren't hypothetical — both reproduced on this exact machine and are
why the compose file/`.env.example` look the way they do:

1. **`UID`/`GID` are reserved in zsh.** zsh (macOS's default shell since
   Catalina) treats `UID` and `GID` as special read-only parameters tied to
   the real process identity. `GID=1000 docker compose build` doesn't set
   an env var — zsh attempts an actual `setgid()` and fails with
   `(eval):1: failed to change group ID: operation not permitted`. Fix:
   compose args are named `HOST_UID`/`HOST_GID` instead, never `UID`/`GID`.
2. **macOS's default GID (`staff`=20) collides with Ubuntu's `dialout`=20.**
   Passing the host GID straight through as `USER_GID` makes the
   Dockerfile's user-setup step rename Ubuntu's *existing* GID-20 group
   (`dialout`) to `ardupilot`, so the group effectively disappears before
   `install-prereqs-ubuntu.sh` runs `usermod -aG dialout ardupilot` later in
   the same build — build fails with `usermod: group 'dialout' does not
   exist` (exit 6). Fix: `HOST_GID` defaults to `1000` (Dockerfile's own
   safe default, no standard-group collision), not the host's real GID.
   UID-matching alone is sufficient for host file ownership on bind-mounted
   build artifacts (owner-UID permission bits apply regardless of group) —
   confirmed: artifacts built in-container came out owned by UID 501 on the
   host (`ls -ln` → `501  20  ...arducopter`), fully writable/deletable by
   the host user without `sudo`.

### Usage
```bash
cd ~/Documents/ArduPilot
HOST_UID=$(id -u) HOST_GID=1000 docker compose build
HOST_UID=$(id -u) HOST_GID=1000 docker compose up
```
(Docker Desktop must be running in the background first — `open -a Docker`
if it isn't; the `docker` CLI is just a client to the daemon inside Docker
Desktop's Linux VM.)

First run triggers the waf configure+build inside the container (same
`[XXXX/1430] Compiling...` pattern as the native build, confirmed up to
`[1430/1430]`); subsequent runs reuse the existing binary and start in
seconds (confirmed via a down/up cycle — no rebuild triggered).

**If you already built SITL natively on macOS first** (as this project
did): delete `ardupilot/build/sitl` before the *first* `docker compose up`.
The entrypoint's "does the binary already exist" check only looks at
existence + the executable bit, not platform compatibility — a leftover
macOS Mach-O binary at `build/sitl/bin/arducopter` has both, so the
container tries to `exec` it directly and fails with `Exec format error`
(confirmed: this happened on this exact machine, since native SITL had
already been built per the steps above).

To wipe EEPROM/params on a given run (passthrough via `"$@"` in the
entrypoint, not baked into the default startup so saved params survive
normal restarts):
```bash
docker compose run --rm sitl -w
```

Stop with `Ctrl+C` or `docker compose down`.

### Gazebo-side config (native macOS)
No changes needed to `ardupilot_gazebo`'s `ArduPilotPlugin` config — its
upstream default `<fdm_addr>127.0.0.1</fdm_addr>` /
`<fdm_port_in>9002</fdm_port_in>` (from `models/iris_with_ardupilot/model.sdf`)
works as-is on macOS, because Docker Desktop's `host.docker.internal` proxy
can reach host **loopback-bound** listeners transparently. Start Gazebo
(with the plugin loaded) *before* `docker compose up` for the SITL container.

**Linux-portability caveat** (not applicable now, but documented since this
repo may run on Linux later): native Linux Docker's `host-gateway` route
*cannot* reach a strictly `127.0.0.1`-bound listener the way Docker Desktop
does — a future Linux user would need to change the SDF's `fdm_addr` to
`0.0.0.0`.

### GCS: QGroundControl stays primary
QGroundControl remains the primary/documented GCS on macOS (native Apple
Silicon support, no Mono reliability issues, relevant to this repo's
cross-platform-sharing goal). Add a manual **TCP** link to `127.0.0.1:5760`
(the port published by `docker-compose.yml`) — QGC's default auto-connect is
UDP, so this link must be added manually.

Optional secondary tool: Mission Planner (native to ArduPilot, deeper
parameter tree / log analysis) can be used via Mono on Mac, or natively on a
Windows machine/VM if ever needed for that deeper work — same TCP
connection, no setup changes.

### Verification actually performed (results, not just steps)
1. **`docker compose build`** — completed successfully (`ardupilot-sitl:local
   Built`) after fixing the UID/GID issues above. apt+pip prereqs step took
   ~242s, comparable to the native prereqs run.
2. **`docker compose up`** — first run triggered the in-container
   `./waf configure --board sitl` + `./waf copter` build, compiling all
   `[1/1430]`→`[1430/1430]` units and linking `bin/arducopter`
   (`'copter' finished successfully (5m39.703s)` — slower than the native
   `1m54s` build, expected given Docker Desktop's Linux-VM/virtiofs overhead
   on Apple Silicon), then started SITL and reached `Waiting for
   connection ....` on `tcp:5760`, exactly as designed.
3. **MAVLink/param check — binary and TCP path confirmed working**, with
   one important real-world caveat: the main container runs
   `--model JSON`, which blocks on sensor/IMU data from a live Gazebo FDM
   bridge before the main loop proceeds far enough to transmit any MAVLink
   traffic. Confirmed directly: a raw TCP connection to `127.0.0.1:5760`
   succeeds (SITL accepts it) but delivers **zero bytes** for 10s while
   Gazebo isn't running (`No JSON sensor message received, resending
   servos` loops in the container log) — this is correct, expected
   behavior for `--model JSON` without a physics backend, not a Docker bug,
   and it's exactly why step 5 below is deferred.
   To validate the actual binary + MAVLink stack independent of the
   Gazebo-bridge requirement, ran a second instance *inside* the same
   container with the default (non-JSON) physics model on the
   multi-instance port: `arducopter --model quad -I1` → bound
   `tcp:5770` → pymavlink from inside the container: **heartbeat from
   system 1, 1450 PARAM_VALUE messages** (vs. 1453 natively — same order of
   magnitude; the small difference is expected build/version variance, not
   a concern). This confirms the container-built Linux binary and its full
   MAVLink param stack are sound.
4. Confirmed `docker compose down` stops cleanly (tested twice, including
   after killing the secondary sanity-check instance). Confirmed a
   subsequent `docker compose up` reuses the already-built binary and
   reaches `Waiting for connection ....` again within seconds — no rebuild
   triggered, as designed.
5. **Deferred** — full end-to-end pass (container SITL + native Gazebo +
   native QGC, with `--model JSON` actually fed live FDM data so it
   transmits heartbeats on its own) waits on step 1 in "Not done yet" below.
   Gazebo Harmonic, the `ardupilot_gazebo` plugin, and QGroundControl are
   all now installed (see "Done" above) — what's left is the actual
   end-to-end run, plus a fresh native SITL rebuild (the current
   `build/sitl/bin/arducopter` is the Linux binary from the Docker work,
   not a native one). Everything that *can* be verified piecemeal without
   that full run has been verified above.

Citations: upstream `ardupilot/Dockerfile`; `ardupilot_gazebo`'s
`models/iris_with_ardupilot/model.sdf` (`fdm_addr`/`fdm_port_in=9002`); this
repo's own `libraries/AP_HAL_SITL/SITL_cmdline.cpp`
(`SIM_IN_PORT=9003`, `SIM_OUT_PORT=9002`, `BASE_PORT=5760`).

### Explicitly not done as part of this Docker setup
- Not baking the compiled binary into a slim multi-stage final image — the
  repo already vendors the full ardupilot source, so a separate-clone-free
  image doesn't buy anything here.
- `ardupilot/Dockerfile` itself was not modified — used as-is.
- The entrypoint is not generalized for ArduPlane/Rover/other vehicles.
- No `git init`/commit done for this parent repo — only `.gitignore` was
  added so build artifacts/venvs won't get committed later.

## User context / preferences noted so far
- User's Mac: Apple Silicon, running macOS 26.5.2.
- User also has a Linux VM (UTM/QEMU) for ROS/Gazebo, but deliberately chose to
  run SITL+Gazebo+QGC **natively on macOS** instead, because UTM/QEMU's
  GPU/Venus passthrough for Linux guests currently has known unresolved
  rendering bugs (geometry-shader draws) that would make Gazebo's ogre2
  renderer unreliable in that VM. Native macOS has official (if "best-effort")
  support for both SITL and the ardupilot_gazebo plugin.
- User only wants Gazebo for ArduCopter physics simulation — explicitly does
  NOT want/need ROS, since the real vehicle will only have the FC, no
  companion computer.
- Eventual real vehicle target: ArduCopter.
