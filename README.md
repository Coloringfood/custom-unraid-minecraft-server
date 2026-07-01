# Custom Minecraft Server in Docker

Run *any* Minecraft server (Vanilla, Forge, Fabric, Paper, Spigot, FTB, …) from a
directory you already have. Point the container at your pre-downloaded server
files, tell it which start script to run, and it will install the right Java
runtime and launch it.

## Bring your own server directory (recommended)

1. Mount your existing server folder to `/serverdata/serverfiles`.
2. Put a start script in that folder, e.g. `startserver.sh`, containing your
   launch command (for a Forge server this is usually the generated
   `run.sh`/`user_jvm_args.txt` invocation).
3. Set `START_SERVER_SCRIPT=startserver` (the name **without** the `.sh`).
4. Pick a Java version with `RUNTIME_NAME` (see below) and accept the EULA.

When `START_SERVER_SCRIPT` is set the container skips all Vanilla
version-checking/downloading — it only installs Java and runs your script. The
runtime's `bin/` is prepended to `PATH`, so `java` inside your script resolves
to the installed runtime.

> Leave `START_SERVER_SCRIPT` blank to fall back to the original behaviour:
> set `GAME_V=latest` to auto-download Vanilla, `GAME_V=custom` to run your own
> `${JAR_NAME}.jar`, or provide a full `JVM_CUSTOM_COMMAND`.

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

>**WEB CONSOLE:** You can connect to the Minecraft console by opening your browser and go to HOSTIP:9011 (eg: 192.168.1.1:9011) or click on WebUI on the Docker page within Unraid.

## Env params
| Name | Value | Example |
| --- | --- | --- |
| SERVER_DIR | Folder for gamefile | /serverdata/serverfiles |
| RUNTIME_NAME | Temurin JRE to install: `basicjre`=Java 8, `jre11`, `jre17`, `jre21`, etc. Switching versions auto-removes the old runtime. | jre17 |
| START_SERVER_SCRIPT | Name (without `.sh`) of a start script in your server dir to run. Set this to bring your own pre-downloaded server. | startserver |
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