#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Generic, headless server launcher (the DEFAULT when neither START_SERVER_SCRIPT
# nor JVM_CUSTOM_COMMAND is set).
#
# It auto-detects the loader in ${SERVER_DIR} and launches it with the memory
# settings from the container env (XMX_SIZE/XMS_SIZE/EXTRA_JVM_PARAMS) — never
# from a pack's user_jvm_args.txt, and never with an interactive prompt.
#
# Install handling (Forge/NeoForge), in order of preference:
#   1. Already installed (libraries/.../unix_args.txt present) -> just launch.
#   2. A forge-*-installer.jar / neoforge-*-installer.jar in the dir -> run it.
#   3. MC_VERSION+FORGE_VERSION (or NEOFORGE_VERSION) set -> download + install.
#
# Loader launch detection: Forge -> NeoForge -> Fabric -> vanilla/Paper jar.
# ---------------------------------------------------------------------------
set -u
cd "${SERVER_DIR:?SERVER_DIR must be set}"

MEM_ARGS="-Xmx${XMX_SIZE:-2048}M -Xms${XMS_SIZE:-2048}M"

# Print the path to an installed Forge/NeoForge args file, or fail (return 1).
find_args_file() {
	local f
	f="$(ls libraries/net/minecraftforge/forge/*/unix_args.txt 2>/dev/null | head -n1)"
	[ -z "$f" ] && f="$(ls libraries/net/neoforged/neoforge/*/unix_args.txt 2>/dev/null | head -n1)"
	[ -n "$f" ] && { printf '%s\n' "$f"; return 0; }
	return 1
}

install_if_needed() {
	find_args_file >/dev/null 2>&1 && return 0

	local inst=""
	inst="$(ls forge-*-installer.jar neoforge-*-installer.jar 2>/dev/null | head -n1)"

	# No installer in the dir — download one if we were told which version.
	if [ -z "$inst" ] && [ -n "${MC_VERSION:-}" ] && [ -n "${FORGE_VERSION:-}" ]; then
		inst="forge-${MC_VERSION}-${FORGE_VERSION}-installer.jar"
		echo "---Downloading Forge installer ${MC_VERSION}-${FORGE_VERSION}---"
		wget -q --show-progress --progress=bar:force:noscroll -O "$inst" \
			"https://maven.minecraftforge.net/net/minecraftforge/forge/${MC_VERSION}-${FORGE_VERSION}/${inst}" \
			|| { echo "---Failed to download Forge installer---"; exit 1; }
	elif [ -z "$inst" ] && [ -n "${NEOFORGE_VERSION:-}" ]; then
		inst="neoforge-${NEOFORGE_VERSION}-installer.jar"
		echo "---Downloading NeoForge installer ${NEOFORGE_VERSION}---"
		wget -q --show-progress --progress=bar:force:noscroll -O "$inst" \
			"https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/${inst}" \
			|| { echo "---Failed to download NeoForge installer---"; exit 1; }
	fi

	if [ -z "$inst" ] || [ ! -f "$inst" ]; then
		return 1   # nothing to install from
	fi

	# Retry to ride out transient library-download failures during --installServer
	# (Forge's installer is idempotent). Avoids relying on a container restart.
	local attempt=1
	while [ "$attempt" -le 3 ]; do
		echo "---Installing server from ${inst} (attempt ${attempt})---"
		java -jar "$inst" --installServer || true
		if find_args_file >/dev/null 2>&1; then
			echo "---Server install complete---"
			return 0
		fi
		echo "---Install did not complete, retrying in 5s...---"
		sleep 5
		attempt=$((attempt + 1))
	done
	return 1
}

install_if_needed || true

# 1) Forge / NeoForge (argfile launch)
if ARGS_FILE="$(find_args_file)"; then
	echo "---Launching Forge/NeoForge server (${ARGS_FILE})---"
	exec java ${MEM_ARGS} ${EXTRA_JVM_PARAMS:-} "@${ARGS_FILE}" nogui ${GAME_PARAMS:-} "$@"
fi

# 2) Fabric
for fj in fabric-server-launch.jar fabric-server-launcher.jar; do
	if [ -f "$fj" ]; then
		echo "---Launching Fabric server (${fj})---"
		exec java ${MEM_ARGS} ${EXTRA_JVM_PARAMS:-} -jar "$fj" nogui ${GAME_PARAMS:-} "$@"
	fi
done

# 3) Vanilla / Paper / Spigot / custom jar
JAR="${JAR_NAME:-server}.jar"
if [ -f "$JAR" ]; then
	echo "---Launching ${JAR}---"
	exec java ${MEM_ARGS} ${EXTRA_JVM_PARAMS:-} -jar "$JAR" nogui ${GAME_PARAMS:-} "$@"
fi

echo "---------------------------------------------------------------------"
echo "No server detected in ${SERVER_DIR}. Provide one of:"
echo "  * an installed Forge/NeoForge server (libraries/.../unix_args.txt)"
echo "  * a forge-*-installer.jar (or set MC_VERSION + FORGE_VERSION)"
echo "  * a Fabric server jar, or a ${JAR_NAME:-server}.jar"
echo "Or set START_SERVER_SCRIPT to run the pack's own start script."
echo "Sleeping instead of exiting so the container doesn't restart-loop —"
echo "fix the server directory, then restart the container."
echo "---------------------------------------------------------------------"
sleep infinity
