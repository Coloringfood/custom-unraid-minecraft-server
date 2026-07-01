#!/bin/bash
# ---------------------------------------------------------------------------
# Java runtime install
#
# RUNTIME_NAME selects which Temurin (Eclipse Adoptium) JRE major version to
# install:  basicjre -> 8, jre11 -> 11, jre17 -> 17, jre21 -> 21, etc.
# The runtime is downloaded from the Adoptium API (always the latest GA build
# for that major version) and extracted to ${SERVER_DIR}/runtime/${RUNTIME_NAME}.
# Any other RUNTIME_NAME is treated as a user-provided runtime: the matching
# folder must already exist under ${SERVER_DIR}/runtime/.
# ---------------------------------------------------------------------------
RUNTIME_DIR="${SERVER_DIR}/runtime"
JAVA_HOME_DIR="${RUNTIME_DIR}/${RUNTIME_NAME}"

echo "---Checking for 'runtime' folder---"
mkdir -p "${RUNTIME_DIR}"

# Remove any runtime folders that aren't the one we want (keeps the dir tidy
# and reclaims space when switching Java versions).
for d in "${RUNTIME_DIR}"/*/; do
	[ -d "$d" ] || continue
	if [ "$(basename "$d")" != "${RUNTIME_NAME}" ]; then
		echo "---Removing stale runtime '$(basename "$d")'---"
		rm -rf "$d"
	fi
done

echo "---Checking if Runtime is installed---"
if [ -x "${JAVA_HOME_DIR}/bin/java" ]; then
	echo "---Runtime '${RUNTIME_NAME}' found---"
else
	# Map RUNTIME_NAME to an Adoptium major version. Empty => user-provided.
	case "${RUNTIME_NAME}" in
		basicjre) JAVA_MAJOR=8 ;;
		jre*)     JAVA_MAJOR="${RUNTIME_NAME#jre}" ;;
		*)        JAVA_MAJOR="" ;;
	esac

	if [ -z "${JAVA_MAJOR}" ]; then
		echo "---------------------------------------------------------------------------------------------"
		echo "---Custom runtime '${RUNTIME_NAME}' not found in '${RUNTIME_DIR}', please check! Sleeping!---"
		echo "---------------------------------------------------------------------------------------------"
		sleep infinity
	fi

	DL_URL="https://api.adoptium.net/v3/binary/latest/${JAVA_MAJOR}/ga/linux/x64/jre/hotspot/normal/eclipse"
	echo "---Downloading and installing Temurin JRE ${JAVA_MAJOR}---"
	mkdir -p "${JAVA_HOME_DIR}"
	if wget -q --show-progress --progress=bar:force:noscroll -O "${RUNTIME_DIR}/${RUNTIME_NAME}.tar.gz" "${DL_URL}"; then
		echo "---Successfully downloaded Temurin JRE ${JAVA_MAJOR}!---"
		tar --directory "${JAVA_HOME_DIR}" --strip-components=1 -xzf "${RUNTIME_DIR}/${RUNTIME_NAME}.tar.gz"
		rm -f "${RUNTIME_DIR}/${RUNTIME_NAME}.tar.gz"
	else
		echo "---Something went wrong, can't download the Runtime, putting server in sleep mode---"
		sleep infinity
	fi
fi

# ---------------------------------------------------------------------------
# Server executable / start command
#
# Primary path: bring your own pre-downloaded server directory plus a start
# script named ${START_SERVER_SCRIPT}.sh living in ${SERVER_DIR}. When that is
# set we skip all vanilla version-checking/downloading entirely.
# ---------------------------------------------------------------------------
echo "---Checking for Minecraft Server executable ---"
if [ -n "${START_SERVER_SCRIPT}" ]; then
	echo "---Using custom start script '${START_SERVER_SCRIPT}.sh' from the server directory---"
	if [ ! -f "${SERVER_DIR}/${START_SERVER_SCRIPT}.sh" ]; then
		echo "---Can't find '${START_SERVER_SCRIPT}.sh' in '${SERVER_DIR}', putting server in sleep mode!---"
		sleep infinity
	fi
	# Bind-mounted scripts (esp. from Windows hosts) may not carry the exec bit.
	chmod +x "${SERVER_DIR}/${START_SERVER_SCRIPT}.sh" 2>/dev/null ||:
elif [ -n "${JVM_CUSTOM_COMMAND}" ]; then
	echo "---Detected JVM_CUSTOM_COMMAND: ${JVM_CUSTOM_COMMAND} skipping Check for Minecraft Server executable!---"
elif [ "${GAME_V}" == "custom" ]; then
	echo "---Custom mode enabled please make sure that '${JAR_NAME}.jar' is in the main directory!---"
	if [ ! -f $SERVER_DIR/${JAR_NAME}.jar ]; then
		echo "---Can't find '${JAR_NAME}.jar' please make sure that it's in the main directory, putting server into sleep mode!---"
		sleep infinity
	fi
	echo "---Executable '${JAR_NAME}.jar' in main directory found, continuing!---"
elif [ "${GAME_V}" == "latest" ]; then
	VERSION="$(wget -qO- https://github.com/ich777/versions/raw/master/MinecraftJavaEdition)"
	LAT_V="$(echo "$VERSION" | grep "LATEST" | cut -d '=' -f2)"
	DL_URL="$(echo "$VERSION" | grep "DL_URL" | cut -d '=' -f2)"
	CUR_V="$(unzip -p ${SERVER_DIR}/${JAR_NAME}.jar version.json | grep "name" | cut -d '"' -f 4)"
	if [ -z "$VERSION" ]; then
		LAT_V="$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r '.latest.release')"
		if [ -z "$LAT_V" ]; then
			if [ -z "$CUR_V" ]; then
				echo "---Can't get latest version from Minecraft falling back to v1.16.2---"
				DL_URL="https://launcher.mojang.com/v1/objects/c5f6fb23c3876461d46ec380421e42b289789530/server.jar"
				LAT_V="1.16.2"
			else
				echo "---Can't get latest version from Minecraft falling back to current version: v$CUR_V---"
				LAT_V="$CUR_V"
			fi
		fi
	fi
	if [ ! -f ${SERVER_DIR}/${JAR_NAME}.jar ]; then
		cd ${SERVER_DIR}
		echo "---Downloading Minecraft Server $LAT_V---"
		if wget -q -nc --show-progress --progress=bar:force:noscroll "$DL_URL" ; then
			echo "---Successfully downloaded Minecraft $LAT_V Server!---"
		else
			echo "---Something went wrong, can't download Minecraft Server, putting server in sleep mode---"
			sleep infinity
		fi
	elif [ "$LAT_V" != "$CUR_V" ]; then
		cd ${SERVER_DIR}
		echo "---Newer version of Minecraft v$LAT_V found, currently installed: $CUR_V---"
		rm ${SERVER_DIR}/${JAR_NAME}.jar
		if wget -q -nc --show-progress --progress=bar:force:noscroll "$DL_URL" ; then
			echo "---Successfully downloaded Minecraft $LAT_V Server!---"
		else
			echo "---Something went wrong, can't download Minecraft Server, putting server in sleep mode---"
			sleep infinity
		fi
	elif [ "$LAT_V" == "$CUR_V" ]; then
		echo "---Minecraft v${CUR_V} is Up-To-Date!---"
	fi
fi

echo "---Preparing Server---"
if [ ! -f ~/.screenrc ]; then
    echo "defscrollback 30000
bindkey \"^C\" echo 'Blocked. Please use to command \"stop\" to shutdown the server or close this window to exit the terminal.'" > ~/.screenrc
fi
echo "---Checking for 'server.properties'---"
if [ ! -f ${SERVER_DIR}/server.properties ]; then
	cp /tmp/server.properties ${SERVER_DIR}/
else
    echo "---'server.properties' found..."
fi
chmod -R ${DATA_PERM} ${DATA_DIR}
# Settle the EULA *before* launching so there is no dependency on how long the
# server (or a first-boot installer) takes to create eula.txt.
if [ "${ACCEPT_EULA}" == "true" ]; then
	echo "---EULA accepted via ACCEPT_EULA---"
	echo "eula=true" > ${SERVER_DIR}/eula.txt
elif [ "${ACCEPT_EULA}" == "false" ]; then
	if [ -f ${SERVER_DIR}/eula.txt ] && grep -rq 'eula=true' ${SERVER_DIR}/eula.txt; then
		sed -i '/eula=true/c\eula=false' ${SERVER_DIR}/eula.txt
	fi
	echo
	echo "-------------------------------------------------------"
	echo "------EULA not accepted, you must accept the EULA------"
	echo "---to start the Server, putting server in sleep mode---"
	echo "-------------------------------------------------------"
	sleep infinity
else
	echo "---Unexpected ACCEPT_EULA value '${ACCEPT_EULA}', please set 'true' or 'false'---"
fi
echo "---Checking for old logs---"
find ${SERVER_DIR} -name "masterLog.*" -exec rm -f {} \;
screen -wipe 2&>/dev/null

echo "---Starting Server---"
cd ${SERVER_DIR}
export PATH="${JAVA_HOME_DIR}/bin:$PATH"
if [ -n "${START_SERVER_SCRIPT}" ]; then
	# Per-pack override: run the pack's own start script verbatim.
	screen -S Minecraft -L -Logfile ${SERVER_DIR}/masterLog.0 -d -m ${SERVER_DIR}/${START_SERVER_SCRIPT}.sh
elif [ -n "${JVM_CUSTOM_COMMAND}" ]; then
	screen -S Minecraft -L -Logfile ${SERVER_DIR}/masterLog.0 -d -m ${JAVA_HOME_DIR}/bin/java ${JVM_CUSTOM_COMMAND} ${GAME_PARAMS}
else
	# Default: generic headless auto-detect launcher (Forge/NeoForge/Fabric/vanilla).
	screen -S Minecraft -L -Logfile ${SERVER_DIR}/masterLog.0 -d -m /opt/scripts/launch.sh
fi
echo "---Waiting for logs, please stand by...---"
if [ "${ENABLE_WEBCONSOLE}" == "true" ]; then
    /opt/scripts/start-gotty.sh 2>/dev/null &
fi

# Best-effort streaming of the server log to the container's stdout (docker logs).
# NOTE: `tail -F` uses inotify and can abort with "No data available" on some
# bind mounts (notably Docker Desktop on Windows) while the file is being
# rewritten. Run it in a retry loop in the background so a hiccup can never take
# down the entrypoint and trigger a restart loop.
(
	sleep 5
	while true; do
		if [ -f "${SERVER_DIR}/logs/latest.log" ]; then
			tail -n 100 -F "${SERVER_DIR}/logs/latest.log" 2>/dev/null
		else
			tail -n 100 -F "${SERVER_DIR}/masterLog.0" 2>/dev/null
		fi
		sleep 2
	done
) &

# Keep the container alive for as long as the server's screen session is running,
# so a log-tail hiccup can't kill a healthy server. When the server stops, fall
# through and exit 0 so Docker's restart policy can act.
sleep 5
while screen -list 2>/dev/null | grep -q '\.Minecraft'; do
	sleep 5
done
echo "---Minecraft server has stopped---"
