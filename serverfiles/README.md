# Local test server directory

`docker-compose.yml` mounts this folder to `/serverdata/serverfiles` inside the
container. Drop a pre-downloaded Minecraft server here to test against.

Everything in this folder is git-ignored (except this README and `.gitkeep`), so
worlds, jars, the downloaded Java runtime, logs, etc. are never committed.

## Quick start

1. Copy your server files here (e.g. Forge's generated files).
2. Add a start script, e.g. `startserver.sh`:
   ```bash
   #!/bin/bash
   # Forge 1.20.1 example — java is on PATH from the installed runtime
   java @user_jvm_args.txt @libraries/net/minecraftforge/forge/*/unix_args.txt nogui
   ```
   Make sure the name (without `.sh`) matches `START_SERVER_SCRIPT` in
   `docker-compose.yml`.
3. From the repo root: `docker compose up --build`.
