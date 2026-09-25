#!/usr/bin/env bash
# The support nudge of the news heartbeat (modules/75-news.sh), with fake
# notify-send / xdg-open / curl — no desktop, no network. Checks: day 45 (not
# 30), the thank-you text for Mac Experience buyers, tapping the notice =
# Support, "never" = opt-out, a timed-out notice counts as shown, no
# notification daemon = try again next week, and the --test notice.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }

sed -n '/^cat > "\$NEWS_DIR\/second-wind-news.sh"/,/^EOF$/p' "$ROOT/modules/75-news.sh" \
  | sed '1d;$d' > "$T/news.sh"
mkdir -p "$T/bin"
cat > "$T/bin/notify-send" <<'EOF'
#!/bin/sh
for a; do last="$a"; done
printf '%s\n' "$last" >> "$LOG.body"
printf '%s' "$FAKE_ANSWER"; exit "${FAKE_RC:-0}"
EOF
cat > "$T/bin/xdg-open" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >> "$LOG.open"
EOF
printf '#!/bin/sh\nexit 7\n' > "$T/bin/curl"
chmod +x "$T/bin/"*

run() {  # run AGE_DAYS EXP_STATE ANSWER RC [--test]
  local H="$T/home-$RANDOM"; local S="$H/.local/state/second-wind"
  mkdir -p "$S/news" "$S/experience"
  echo $(( $(date +%s) - $1 * 86400 - 60 )) > "$S/news/install-date"
  echo "/usr/local/share/second-wind/bin/second-wind-update" > "$S/news/updater"
  echo "$2" > "$S/experience/state"
  echo "DONATE_URL=https://ko-fi.com/example" > "$S/links.conf"
  LOG="$H/log"; : > "$LOG.body"; : > "$LOG.open"
  HOME="$H" LANG=es_CL.UTF-8 LOG="$LOG" FAKE_ANSWER="$3" FAKE_RC="$4" PATH="$T/bin:$PATH" \
    bash "$T/news.sh" ${5:-} ; sleep 0.3
  CUR="$H"
}
S() { echo "$CUR/.local/state/second-wind"; }

run 44 trial "" 0
[ ! -s "$CUR/log.body" ] && [ ! -f "$(S)/news/nudged" ] && ok "day 44: no nudge yet" || bad "day 44 showed a nudge"

run 45 off default 0
grep -q 'mes y medio' "$CUR/log.body" && ok "day 45, not bought: regular text" || bad "day 45 text: $(cat "$CUR/log.body")"
grep -qx 'https://ko-fi.com/example' "$CUR/log.open" && ok "tap on the notice opens the donation page" || bad "tap did not open"
[ -f "$(S)/news/nudged" ] && ok "nudge burned once shown" || bad "not marked as shown"

run 45 active support 0
grep -q 'Gracias por darle' "$CUR/log.body" && ok "buyer gets the thank-you text" || bad "buyer text: $(cat "$CUR/log.body")"
grep -q ko-fi "$CUR/log.open" && ok "Support button opens the donation page" || bad "Support did not open"

run 50 trial never 0
[ -f "$(S)/../second-wind/news-optout" ] || [ -f "$CUR/.local/state/second-wind/news-optout" ] \
  && ok "\"never\" switches notices off" || bad "never did not opt out"

run 50 trial "" 124
[ -f "$(S)/news/nudged" ] && [ ! -s "$CUR/log.open" ] && ok "ignored for 1 h (timeout): counts as shown, opens nothing" \
  || bad "timeout handling"

run 50 trial "" 1
[ ! -f "$(S)/news/nudged" ] && ok "no notification daemon: retried next week" || bad "burned without being shown"

run 0 trial default 0 --test
grep -q PRUEBA "$CUR/log.body" && grep -q ko-fi "$CUR/log.open" && [ ! -f "$(S)/news/nudged" ] \
  && ok "--test: sample notice, tap opens the page, no state change" || bad "--test"

exit $fail
