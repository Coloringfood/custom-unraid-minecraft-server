# Local test server directory

Each subfolder here is one server/modpack. `docker-compose.yml` mounts **one** of
them to `/serverdata/serverfiles` via the `PACK` variable:

```bash
docker compose up -d --build                       # PACK defaults to DeceasedCraft
PACK=ProjectArchitect2 docker compose up -d        # switch packs
```

Everything inside each pack folder is git-ignored (worlds, jars, the downloaded
Java runtime, installed Forge `libraries/`, logs, etc.), so nothing here gets
committed.

## Launching a pack

- **Generic (default):** leave `START_SERVER_SCRIPT` empty. For a Forge/NeoForge
  pack with no `libraries/` yet, either drop its `forge-*-installer.jar` in the
  folder or pass the version so it downloads+installs:
  ```bash
  PACK=VaultHunters3rdEditionRemastered MC_VERSION=1.18.2 FORGE_VERSION=40.3.11 \
    XMX_SIZE=6144 XMS_SIZE=6144 docker compose up -d --build
  ```
- **Per-pack override:** run the pack's own script:
  ```bash
  PACK=ProjectArchitect2 START_SERVER_SCRIPT=startserver docker compose up -d --build
  ```

Watch it boot: `docker compose logs -f` — look for `Done (…)! For help, type "help"`.

> Remove client-only mods (e.g. `rubidium`, `legendarytooltips`, `torohealth`)
> from a pack's `mods/` — they crash dedicated servers.
