#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Daily scheduled server restart with in-game warnings.
#
# Opt-in via env:
#   AUTO_RESTART_TIME  "HH:MM"  wall-clock time (container TZ) to restart daily.
#                               Empty  => disabled (this script exits immediately).
#   AUTO_RESTART_WARN  "10,5,1" comma-separated minutes-before to broadcast a
#                               `say` warning. Default "10,5,1".
#   TZ                 e.g. "America/Denver" — the container is UTC by default,
#                               so set this or AUTO_RESTART_TIME is interpreted
#                               as UTC.
#
# How it works: it does NOT kill the container directly. At restart time it
# sends `stop` into the Minecraft `screen` session (the same mechanism used on
# shutdown). The server saves & exits, the screen session ends, the entrypoint
# falls through, and Docker's `restart: unless-stopped` policy starts a fresh
# container. The web console (gotty) reconnects at the same URL afterward.
#
# Warnings are sent with `screen ... stuff "say ...\r"`, so this works for ANY
# server type (vanilla / Forge / NeoForge / Fabric / Paper) — no mod required.
# ---------------------------------------------------------------------------

SCREEN_NAME="Minecraft"

# Epoch (seconds) of the next occurrence of HH:MM strictly after now_epoch.
#   ar_target_epoch <hhmm> <now_epoch>
ar_target_epoch() {
	local hhmm="$1" now="$2" day target
	day="$(date -d "@${now}" +%Y-%m-%d)"
	target="$(date -d "${day} ${hhmm}" +%s)"
	if [ "$target" -le "$now" ]; then
		target=$((target + 86400))
	fi
	printf '%s\n' "$target"
}

# Parse a csv of minutes into seconds-before-restart offsets: positive integers
# only, sorted descending, deduped. Non-numeric / <=0 tokens are dropped.
#   ar_warn_offsets "10,5,1"  ->  "600 300 60"
ar_warn_offsets() {
	local csv="$1" out="" tok
	local IFS=','
	for tok in $csv; do
		tok="${tok//[[:space:]]/}"
		[ -z "$tok" ] && continue
		case "$tok" in
			*[!0-9]*) continue ;;   # anything non-digit (incl. '-') -> skip
		esac
		[ "$tok" -le 0 ] && continue
		out="${out} $((tok * 60))"
	done
	# shellcheck disable=SC2086
	echo $out | tr ' ' '\n' | grep -v '^$' | sort -rnu | tr '\n' ' ' | sed 's/ *$//'
}

# Human-readable, pluralized duration for a whole number of seconds.
#   ar_label 600 -> "10 minutes"   ar_label 1 -> "1 second"
ar_label() {
	local s="$1"
	if [ "$s" -ge 60 ] && [ $((s % 60)) -eq 0 ]; then
		local m=$((s / 60))
		if [ "$m" -eq 1 ]; then echo "1 minute"; else echo "${m} minutes"; fi
	else
		if [ "$s" -eq 1 ]; then echo "1 second"; else echo "${s} seconds"; fi
	fi
}

# Send a chat broadcast to all players. The trailing CR is the Enter key.
ar_broadcast() {
	screen -S "${SCREEN_NAME}" -X stuff "say $1$(printf '\r')" 2>/dev/null || true
}

# Ask the server to stop (triggers the daily restart via Docker's policy).
ar_stop() {
	screen -S "${SCREEN_NAME}" -X stuff "stop$(printf '\r')" 2>/dev/null || true
}

main() {
	if [ -z "${AUTO_RESTART_TIME:-}" ]; then
		exit 0   # feature disabled
	fi
	local warn_csv="${AUTO_RESTART_WARN:-10,5,1}"

	while true; do
		local now target offsets off fire sleep_for label
		now="$(date +%s)"
		target="$(ar_target_epoch "${AUTO_RESTART_TIME}" "${now}")"
		echo "---[auto-restart] next restart ${AUTO_RESTART_TIME} (${warn_csv} min warnings)---"

		# Broadcast each warning as its moment arrives. Warnings whose time has
		# already passed (container started late in the window) are skipped.
		offsets="$(ar_warn_offsets "${warn_csv}")"
		for off in ${offsets}; do
			fire=$((target - off))
			now="$(date +%s)"
			sleep_for=$((fire - now))
			if [ "${sleep_for}" -gt 0 ]; then
				sleep "${sleep_for}"
				label="$(ar_label "${off}")"
				ar_broadcast "Server restarting in ${label}..."
			fi
		done

		# Wait out any remaining time, then final notice + stop.
		now="$(date +%s)"
		sleep_for=$((target - now))
		[ "${sleep_for}" -gt 0 ] && sleep "${sleep_for}"
		ar_broadcast "Server restarting now — back in about a minute."
		sleep 1
		ar_stop

		# The server is shutting down; the container will exit and Docker will
		# bring up a fresh one, taking this process with it. Sleep well past the
		# shutdown so we never spin; if we somehow survive, the loop just
		# schedules the next day.
		sleep 300
	done
}

# Only run when executed directly — sourcing (e.g. from tests) just loads the
# functions above.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	main
fi
