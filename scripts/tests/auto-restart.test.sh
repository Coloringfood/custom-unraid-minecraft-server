#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Unit tests for the scheduling logic in scripts/auto-restart.sh.
# Pure functions only — no running server / screen session required.
# Run:  bash scripts/tests/auto-restart.test.sh
# ---------------------------------------------------------------------------
set -u
export TZ=UTC   # deterministic wall-clock math regardless of host timezone

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../auto-restart.sh
source "${DIR}/auto-restart.sh"

fail=0
check() {
	local desc="$1" got="$2" want="$3"
	if [ "$got" = "$want" ]; then
		echo "ok   - ${desc}"
	else
		echo "FAIL - ${desc}: got [${got}] want [${want}]"
		fail=1
	fi
}

# --- ar_warn_offsets: csv of minutes -> seconds, descending, deduped ---------
check "warn offsets basic"    "$(ar_warn_offsets '10,5,1')"         "600 300 60"
check "warn offsets unsorted" "$(ar_warn_offsets '1,10,5')"         "600 300 60"
check "warn offsets dedupe"   "$(ar_warn_offsets '5,5,10')"         "600 300"
check "warn offsets junk"     "$(ar_warn_offsets '10,foo,,-3,0,2')" "600 120"
check "warn offsets spaces"   "$(ar_warn_offsets ' 10 , 5 ')"       "600 300"
check "warn offsets empty"    "$(ar_warn_offsets '')"               ""

# --- ar_label: human-readable, pluralized ------------------------------------
check "label 10 min" "$(ar_label 600)" "10 minutes"
check "label 1 min"  "$(ar_label 60)"  "1 minute"
check "label 30 sec" "$(ar_label 30)"  "30 seconds"
check "label 1 sec"  "$(ar_label 1)"   "1 second"

# --- ar_target_epoch: next occurrence of HH:MM, strictly in the future -------
now="$(date -d '2026-07-23 10:00:00' +%s)"
check "target later today" \
	"$(ar_target_epoch '18:00' "$now")" "$(date -d '2026-07-23 18:00:00' +%s)"
check "target rolls to tomorrow" \
	"$(ar_target_epoch '04:00' "$now")" "$(date -d '2026-07-24 04:00:00' +%s)"
check "target equal now -> tomorrow" \
	"$(ar_target_epoch '10:00' "$now")" "$(date -d '2026-07-24 10:00:00' +%s)"

if [ "$fail" -eq 0 ]; then
	echo "--- all auto-restart tests passed ---"
else
	echo "--- auto-restart tests FAILED ---"
fi
exit $fail
