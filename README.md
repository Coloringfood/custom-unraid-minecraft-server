# Custom Minecraft Server in Docker

Run *any* Minecraft server (Vanilla, Forge, NeoForge, Fabric, Paper, Spigot, FTB, …)
from a directory you already have. Mount your pre-downloaded server folder, and the
container installs the right Java runtime, accepts the EULA, and launches it.

## Two launch models

**1. Generic launcher (default).** Leave `START_SERVER_SCRIPT` empty and the
container auto-detects what to run in the server dir, headless and with *your*
memory settings:

- **Forge / NeoForge** — launches the installed server (`libraries/.../unix_args.txt`).
  If it isn't installed yet, it runs a `forge-*-installer.jar` present in the dir,
  or downloads+installs one when you set `MC_VERSION`+`FORGE_VERSION`
  (or `NEOFORGE_VERSION`).
- **Fabric** — runs `fabric-server-launch.jar`.
- **Vanilla / Paper / Spigot** — runs `${JAR_NAME}.jar` (also works with
  `GAME_V=latest` to auto-download Vanilla).

Memory/JVM flags come from `XMX_SIZE`/`XMS_SIZE`/`EXTRA_JVM_PARAMS` — a pack's own
`user_jvm_args.txt` is ignored so RAM is controlled in one place.

**2. Per-pack override.** Set `START_SERVER_SCRIPT=<name>` (without `.sh`) to run a
start script that ships inside the server dir, exactly as the pack intends. The
installed runtime's `bin/` is on `PATH`, so `java` in that script resolves to it.
Use this when a pack's own launcher does setup you want to keep.

> ⚠️ Some packs' shipped scripts are **interactive** (e.g. Vault Hunters prompts
> for "Sky Vaults? [Y/N]") or delete client-only mods before starting. Interactive
> scripts will hang in a container — prefer the generic launcher for those, and
> remove client-only mods (e.g. `rubidium`) that crash dedicated servers.

## Java runtime

`RUNTIME_NAME` selects a **Temurin (Eclipse Adoptium)** JRE, downloaded on first
start (latest GA build for that major version) into
`/serverdata/serverfiles/runtime/${RUNTIME_NAME}`:

| RUNTIME_NAME | Java version |
| --- | --- |
| `basicjre` | 8 |
| `jre11` | 11 |
| `jre16` | 16 |
| `jre17` | 17 |
| `jre21` | 21 |
| `jre<N>` | any major version Adoptium publishes |

Switching `RUNTIME_NAME` automatically removes the old runtime folder before
installing the new one. Any other value (not `basicjre`/`jre<N>`) is treated as
a runtime you supply yourself: a folder of that name must already exist under
`runtime/`.

ATTENTION: Don't forget to accept the EULA down below and don't forget to edit the 'server.properties' file the server is by default configured to be a LAN server and to be not snooped.

## Console & admin input

The server (and any override start script) runs inside a `screen` session that the
**web console** attaches to with input enabled. So the console isn't read-only — you
can send commands *and* answer interactive prompts a pack's start script might show.

- **Web console:** open `http://HOSTIP:9011` (e.g. `192.168.1.1:9011`), or click WebUI
  in Unraid. Type a server command (e.g. `op <player>`, `stop`) or the answer to a
  prompt, then Enter.
- **From the host (scriptable):** inject input into the session without the browser —
  ```bash
  docker exec -u minecraft <container> screen -S Minecraft -X stuff $'say hello\r'
  ```
  The trailing `\r` is the Enter key; this is the same mechanism the container uses to
  send `stop` on shutdown.

> Because prompts are answerable this way, an interactive override script waits for
> input rather than failing — but it still blocks until someone answers. For fully
> unattended startup, prefer the **generic launcher** (it never prompts).

## Env params
| Name | Value | Example |
| --- | --- | --- |
| SERVER_DIR | Folder for gamefile | /serverdata/serverfiles |
| RUNTIME_NAME | Temurin JRE to install: `basicjre`=Java 8, `jre11`, `jre17`, `jre21`, etc. Switching versions auto-removes the old runtime. | jre17 |
| START_SERVER_SCRIPT | Name (without `.sh`) of a start script in your server dir to run (per-pack override). Leave empty to use the generic auto-detect launcher. | startserver |
| MC_VERSION | Minecraft version, so the generic launcher can download+install Forge when the dir has no installer/libraries. Pair with FORGE_VERSION. | 1.20.1 |
| FORGE_VERSION | Forge version for the generic launcher's download-install. | 47.4.8 |
| NEOFORGE_VERSION | NeoForge version for the generic launcher's download-install. | 21.1.72 |
| JAR_NAME | Executable jar file (Minecraft Serverfile) without the .jar extension. | server |
| GAME_PARAMS | Extra startup Parameters if needed (leave empty if not needed) | empty |
| GAME_PORT | TCP Gameport for the server | 25565 |
| GAME_V | If set to 'latest' the JAR_NAME must be 'server' valid options are 'latest', 'custom' or simply leave empty | latest |
| XMX_SIZE | Enter your XMX size in MB (XMX=The maximum heap size. The performance will decrease if the max heap value is set lower than the amount of live data. It will force frequent garbage collections in order to free up space). | 1024 |
| XMS_SIZE | Enter your XMS size in MB (XMS=The initial and minimum heap size. It is recommended to set the minimum heap size equivalent to the maximum heap size in order to minimize the garbage collection). | 1024 |
| EXTRA_JVM_PARAMS | Extra JVM startup Parameters if needed (leave empty if not needed) | empty |
| JVM_CUSTOM_COMMAND | Overrides all startup parameters for JVM like it is required for Forge v1.18+ | empty |
| ACCEPT_EULA | Head over to: https://account.mojang.com/documents/minecraft_eula to read the EULA. (If you accept the EULA change the value to 'true' without quotes). | true |
| UID | User Identifier | 99 |
| GID | Group Identifier | 100 |

## Run example
```
docker run --name MinecraftBasicServer -d \
	-p 25565:25565 -p 9011:8080 \
	--env 'RUNTIME_NAME=basicjre' \
	--env 'JAR_NAME=server' \
	--env 'GAME_V=latest' \
	--env 'GAME_PORT=25565' \
	--env 'XMX_SIZE=1024' \
    --env 'XMS_SIZE=1024' \
    --env 'ACCEPT_EULA=true' \
	--env 'UID=99' \
	--env 'GID=100' \
	--volume /mnt/user/appdata/minecraftbasicserver:/serverdata/serverfiles \
	ich777/minecraftbasicserver
```
>**NOTE** You can also forward port the TCP port 25575 if you want to connect to the RCON console.


This Docker was mainly edited for better use with Unraid, if you don't use Unraid you should definitely try it!

#### Support Thread: https://forums.unraid.net/topic/79530-support-ich777-gameserver-dockers/