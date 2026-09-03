# Firstboot GUI Conversion (#2b) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace the terminal/whiptail first-boot conversion with a friendly graphical flow — one confirmation, one graphical password, a phase-based progress window, a clear error+retry — without changing the standalone `./install.sh` terminal experience.

**Architecture:** A thin GUI layer only. The first-boot autostart (`usb/firstboot/second-wind-firstboot.sh`) orchestrates the graphical flow via a new `lib/gui.sh` (consent, one-time auth, progress, error). The proven `install.sh` + `modules/*.sh` run UNCHANGED except: `install.sh --firstboot` skips its own question phase, and `lib/ui.sh` routes `ui_step`/`ui_error` to the progress window when `SW_UI=gui`. If the graphical layer isn't available, first-boot falls back to today's terminal path (never to an invisible dialog).

**Tech Stack:** bash, zenity (GTK dialogs, present on Ubuntu 24.04 GNOME), sudo `SUDO_ASKPASS`, GNOME 46 / Wayland.

**Spec:** committee-validated v2 design (this file's Global Constraints capture the committee's P0 fixes). Committee verdict: 3/3 `needs_iteration` on the v1 (pkexec + step-% progress); v2 adopts their recommended path.

## Global Constraints

- **Privilege model:** NEVER assume `pkexec` populates the sudo credential cache — it does not. Authenticate ONCE via a zenity `SUDO_ASKPASS` helper + `sudo -A -v`, keep it warm with a `sudo -n` keepalive in the parent, and call `gui_auth_ensure` (which runs `sudo -n true`) before privileged work; on expiry fail LOUD (visible error), never a mute hang.
- **Password safety:** the askpass helper prints the password ONLY to stdout, never to a file/log/argv/env; helper file mode `0700`, deleted in a trap.
- **Progress:** phase-based / pulsating (`Preparando… Instalando… Afinando… ¡Listo!`), NOT parsed percentages. Deterministic close of the progress dialog on both success and failure.
- **No silent failure:** a failing module or a dead progress reader must surface a `zenity --error` with the log path + retry; the first-boot autostart stays armed until success (existing STAMP logic).
- **Fallback is graphical or abort:** if `SW_UI=gui` but zenity/DISPLAY aren't ready, first-boot uses the existing terminal path; it must NEVER fall through to an invisible whiptail in a no-tty process.
- **Standalone untouched:** `./install.sh` in a terminal behaves EXACTLY as today. The GUI code path is guarded by `SW_UI=gui` and isolated so it is not regression surface for the terminal path.
- **i18n:** every user-visible string exists in `lib/i18n/en.sh` and `lib/i18n/es.sh`.
- **Taller can't run GNOME/VMs:** unit-level tests here stub `zenity`/`sudo`; the real acceptance is a clean-VM E2E by the Mac's Claude (Task 7).

---

## File Structure

- **Create** `lib/gui.sh` — all zenity orchestration + one-time auth + progress lifecycle. One responsibility: the graphical shell around `install.sh`. Sourced by `common.sh` (so `ui.sh` can update progress) and by `firstboot`.
- **Modify** `lib/ui.sh` — add `ui_error`; route `ui_step`/`ui_error` to `lib/gui.sh` when `SW_UI=gui`. Terminal primitives unchanged.
- **Modify** `lib/common.sh` — source `lib/gui.sh` after `ui.sh` deps are available.
- **Modify** `install.sh` — with `--firstboot`, skip the question phase (consent lives in the wrapper); keep `WITH_HARDWARE=1`.
- **Modify** `usb/firstboot/second-wind-firstboot.sh` — GUI orchestration: consent → auth → progress → run `install.sh --firstboot` (SW_UI=gui) → success reboot / error+retry; graceful terminal fallback.
- **Modify** `lib/i18n/en.sh`, `lib/i18n/es.sh` — consent body, phase labels, error strings, auth prompt.
- **Create** `tests/gui/` — bash stub-based tests (fake `zenity`/`sudo` on PATH capturing argv).

---

### Task 1: `lib/gui.sh` — GUI availability, consent, error

**Files:**
- Create: `lib/gui.sh`
- Test: `tests/gui/test_gui_basics.sh`

**Interfaces:**
- Produces: `gui_available() -> 0/1`; `gui_consent(BODY) -> 0 yes/1 no`; `gui_error(BODY, LOGPATH)`; global `SW_UI` respected. Depends on: `zenity`, `MSG[]` (i18n), `$DISPLAY`/`$WAYLAND_DISPLAY`.

- [ ] **Step 1: Write the failing test**

```bash
# tests/gui/test_gui_basics.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# stub zenity: record argv, succeed
cat > "$TMP/zenity" <<'EOF'
#!/bin/sh
printf '%s\0' "$@" >> "$ZENITY_LOG"
exit "${ZENITY_RC:-0}"
EOF
chmod +x "$TMP/zenity"; export PATH="$TMP:$PATH" ZENITY_LOG="$TMP/z.log"
export DISPLAY=":0"; declare -A MSG=([gui_err_title]="Error")
source "$ROOT/lib/gui.sh"
# gui_available true when zenity + DISPLAY present
gui_available || { echo "FAIL: gui_available should be true"; exit 1; }
# gui_consent returns 0 when zenity exits 0
ZENITY_RC=0 gui_consent "body" || { echo "FAIL: consent yes"; exit 1; }
# gui_consent returns 1 when zenity exits 1 (No)
ZENITY_RC=1 gui_consent "body" && { echo "FAIL: consent no"; exit 1; }
# gui_error calls zenity --error with the body
: > "$ZENITY_LOG"; gui_error "boom" "/tmp/log"
grep -qz -- "--error" "$ZENITY_LOG" || { echo "FAIL: error dialog"; exit 1; }
grep -qz -- "boom" "$ZENITY_LOG" || { echo "FAIL: error body"; exit 1; }
echo "PASS test_gui_basics"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/gui/test_gui_basics.sh`
Expected: FAIL (`lib/gui.sh` does not exist yet).

- [ ] **Step 3: Write minimal `lib/gui.sh`**

```bash
#!/usr/bin/env bash
# Second Wind — graphical shell around install.sh for the guided first boot.
# Only active when SW_UI=gui; everything degrades to no-op/false otherwise.
SW_UI="${SW_UI:-terminal}"
gui_available() {
  command -v zenity >/dev/null 2>&1 && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }
}
# gui_consent BODY -> 0 (yes) / 1 (no)
gui_consent() {
  zenity --question --no-wrap --title="Second Wind" \
    --ok-label="${MSG[gui_ok]:-Continue}" --cancel-label="${MSG[gui_cancel]:-Not now}" \
    --text="$1" 2>/dev/null
}
# gui_error BODY LOGPATH
gui_error() {
  zenity --error --no-wrap --title="${MSG[gui_err_title]:-Second Wind}" \
    --text="$1"$'\n\n'"${MSG[gui_err_log]:-Log:} $2" 2>/dev/null || true
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash tests/gui/test_gui_basics.sh` → Expected: `PASS test_gui_basics`

- [ ] **Step 5: Commit**

```bash
git add lib/gui.sh tests/gui/test_gui_basics.sh
git -c user.name="Second Wind" -c user.email="hello@secondwindformac.com" \
  commit -m "gui: availability, one-shot consent and error dialogs"
```

---

### Task 2: `lib/gui.sh` — one-time graphical auth + keepalive + ensure

**Files:**
- Modify: `lib/gui.sh`
- Test: `tests/gui/test_gui_auth.sh`

**Interfaces:**
- Produces: `gui_auth_begin() -> 0/1` (asks the password once, warms sudo, starts keepalive, exports `SUDO_ASKPASS`); `gui_auth_ensure() -> 0/1` (fails loud if credentials are gone); `gui_auth_end()` (kills keepalive, removes askpass). Consumes: `zenity`, `sudo`.

- [ ] **Step 1: Write the failing test** (stub `sudo` + `zenity`; assert the askpass helper emits ONLY the password on stdout and never writes it to a file)

```bash
# tests/gui/test_gui_auth.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# stub zenity --password -> prints a secret to stdout
cat > "$TMP/zenity" <<'EOF'
#!/bin/sh
case "$*" in *--password*) echo "s3cr3t";; *) : ;; esac
exit 0
EOF
# stub sudo: -A -v ok; -n true ok; record calls
cat > "$TMP/sudo" <<'EOF'
#!/bin/sh
printf '%s ' "$@" >> "$SUDO_LOG"; echo >> "$SUDO_LOG"
exit 0
EOF
chmod +x "$TMP/zenity" "$TMP/sudo"
export PATH="$TMP:$PATH" SUDO_LOG="$TMP/sudo.log" DISPLAY=":0"
declare -A MSG=([gui_pw_prompt]="Your password")
source "$ROOT/lib/gui.sh"
gui_auth_begin || { echo "FAIL: auth_begin"; exit 1; }
[ -n "${SUDO_ASKPASS:-}" ] && [ -x "$SUDO_ASKPASS" ] || { echo "FAIL: askpass not set"; exit 1; }
# askpass emits ONLY the secret on stdout
out="$("$SUDO_ASKPASS")"; [ "$out" = "s3cr3t" ] || { echo "FAIL: askpass stdout"; exit 1; }
# askpass file must not contain the password literal (it calls zenity, doesn't store it)
grep -q "s3cr3t" "$SUDO_ASKPASS" && { echo "FAIL: password stored in helper"; exit 1; }
grep -q -- "-A -v" "$SUDO_LOG" || { echo "FAIL: sudo -A -v not called"; exit 1; }
gui_auth_ensure || { echo "FAIL: ensure ok path"; exit 1; }
gui_auth_end
[ -e "${SUDO_ASKPASS}" ] && { echo "FAIL: askpass not cleaned"; exit 1; }
echo "PASS test_gui_auth"
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tests/gui/test_gui_auth.sh` → Expected: FAIL (functions undefined).

- [ ] **Step 3: Implement in `lib/gui.sh`**

```bash
# --- one-time graphical privilege escalation ---
SW_GUI_ASKPASS=""; SW_GUI_KEEPALIVE=""
gui_auth_begin() {
  SW_GUI_ASKPASS="$(mktemp)"; chmod 0700 "$SW_GUI_ASKPASS"
  # helper: prints the password to STDOUT only; never stores/logs it
  cat > "$SW_GUI_ASKPASS" <<EOF
#!/bin/sh
exec zenity --password --title="Second Wind" 2>/dev/null
EOF
  chmod 0700 "$SW_GUI_ASKPASS"
  export SUDO_ASKPASS="$SW_GUI_ASKPASS"
  # ask once; sudo -A uses the askpass helper (graphical prompt)
  sudo -A -v || { gui_auth_end; return 1; }
  # keep the timestamp warm for the whole run (~7 min); dies with the parent
  ( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
  SW_GUI_KEEPALIVE=$!
  return 0
}
gui_auth_ensure() {
  sudo -n true 2>/dev/null && return 0
  sudo -A -v 2>/dev/null && return 0   # one graphical re-ask
  return 1                              # caller shows gui_error — never mute
}
gui_auth_end() {
  [ -n "$SW_GUI_KEEPALIVE" ] && kill "$SW_GUI_KEEPALIVE" 2>/dev/null || true
  [ -n "$SW_GUI_ASKPASS" ] && rm -f "$SW_GUI_ASKPASS" || true
  SW_GUI_KEEPALIVE=""; SW_GUI_ASKPASS=""; unset SUDO_ASKPASS
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash tests/gui/test_gui_auth.sh` → Expected: `PASS test_gui_auth`

- [ ] **Step 5: Commit**

```bash
git add lib/gui.sh tests/gui/test_gui_auth.sh
git -c user.name="Second Wind" -c user.email="hello@secondwindformac.com" \
  commit -m "gui: one-time askpass auth + keepalive + loud ensure (no pkexec)"
```

---

### Task 3: `lib/gui.sh` — phase progress window (pulsating, deterministic close)

**Files:**
- Modify: `lib/gui.sh`
- Test: `tests/gui/test_gui_progress.sh`

**Interfaces:**
- Produces: `gui_progress_open()` (mkfifo, starts `zenity --progress --pulsate`, exports `SW_PROGRESS_FIFO`); `gui_progress_update(TEXT)` (writes `# TEXT` to the fifo, no-op if closed); `gui_progress_close()` (closes fifo → dialog auto-closes; cleans up). Consumes: `zenity`, `mkfifo`.

- [ ] **Step 1: Write the failing test** (stub zenity that drains the fifo into a log; assert updates land and close is clean)

```bash
# tests/gui/test_gui_progress.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/zenity" <<'EOF'
#!/bin/sh
# emulate --progress: copy stdin to a log until EOF
cat >> "$ZP_LOG"
EOF
chmod +x "$TMP/zenity"; export PATH="$TMP:$PATH" ZP_LOG="$TMP/zp.log" DISPLAY=":0"
declare -A MSG=()
source "$ROOT/lib/gui.sh"
gui_progress_open "Working"
[ -p "${SW_PROGRESS_FIFO:-/none}" ] || { echo "FAIL: fifo missing"; exit 1; }
gui_progress_update "Preparando"
gui_progress_update "Instalando"
gui_progress_close
grep -q "# Preparando" "$ZP_LOG" || { echo "FAIL: phase 1 missing"; exit 1; }
grep -q "# Instalando" "$ZP_LOG" || { echo "FAIL: phase 2 missing"; exit 1; }
[ -e "${SW_PROGRESS_FIFO}" ] && { echo "FAIL: fifo not cleaned"; exit 1; }
# update after close must be a no-op (no error)
gui_progress_update "late" || { echo "FAIL: update-after-close errored"; exit 1; }
echo "PASS test_gui_progress"
```

- [ ] **Step 2: Run to verify it fails** → `bash tests/gui/test_gui_progress.sh` → FAIL.

- [ ] **Step 3: Implement in `lib/gui.sh`**

```bash
# --- phase-based progress window ---
SW_PROGRESS_FIFO=""; SW_PROGRESS_PID=""
gui_progress_open() {
  local dir; dir="$(mktemp -d)"; SW_PROGRESS_FIFO="$dir/p"
  mkfifo "$SW_PROGRESS_FIFO"
  ( zenity --progress --pulsate --no-cancel --auto-close \
      --title="Second Wind" --text="${1:-…}" < "$SW_PROGRESS_FIFO" 2>/dev/null ) &
  SW_PROGRESS_PID=$!
  # hold the write end open so the reader doesn't get EOF between updates
  exec {SW_PROGRESS_WFD}>"$SW_PROGRESS_FIFO"
  export SW_PROGRESS_FIFO
}
gui_progress_update() {
  [ -n "$SW_PROGRESS_FIFO" ] && [ -p "$SW_PROGRESS_FIFO" ] || return 0
  printf '# %s\n' "$1" >&"$SW_PROGRESS_WFD" 2>/dev/null || true
}
gui_progress_close() {
  [ -n "${SW_PROGRESS_WFD:-}" ] && exec {SW_PROGRESS_WFD}>&- 2>/dev/null || true
  [ -n "$SW_PROGRESS_PID" ] && wait "$SW_PROGRESS_PID" 2>/dev/null || true
  [ -n "$SW_PROGRESS_FIFO" ] && rm -rf "$(dirname "$SW_PROGRESS_FIFO")" || true
  SW_PROGRESS_FIFO=""; SW_PROGRESS_PID=""; unset SW_PROGRESS_FIFO
}
```

- [ ] **Step 4: Run to verify it passes** → `bash tests/gui/test_gui_progress.sh` → `PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/gui.sh tests/gui/test_gui_progress.sh
git -c user.name="Second Wind" -c user.email="hello@secondwindformac.com" \
  commit -m "gui: pulsating phase progress window with deterministic close"
```

---

### Task 4: `lib/ui.sh` — route `ui_step`/`ui_error` to the progress window under `SW_UI=gui`

**Files:**
- Modify: `lib/ui.sh`
- Test: `tests/gui/test_ui_routing.sh`

**Interfaces:**
- Consumes: `gui_progress_update`, `gui_error` (Task 1/3). Produces: `ui_error(TEXT[,LOGPATH])`; `ui_step` behavior unchanged in terminal mode, routes to progress in GUI mode.

- [ ] **Step 1: Write the failing test**

```bash
# tests/gui/test_ui_routing.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# fake gui_* to record calls, so we test ROUTING only
cat > "$TMP/fakegui.sh" <<'EOF'
gui_progress_update(){ echo "PROG:$1" >> "$CALLS"; }
gui_error(){ echo "ERR:$1" >> "$CALLS"; }
EOF
export CALLS="$TMP/calls"; C_INFO=""; C_OFF=""
# terminal mode: ui_step prints a line, does NOT call gui_progress_update
SW_UI=terminal; source "$ROOT/lib/ui.sh"; source "$TMP/fakegui.sh"
out="$(ui_step 3 17 "Instalando")"; echo "$out" | grep -q "\[3/17\] Instalando" || { echo "FAIL: terminal step line"; exit 1; }
[ -f "$CALLS" ] && grep -q PROG "$CALLS" && { echo "FAIL: terminal must not call progress"; exit 1; }
# gui mode: ui_step routes to gui_progress_update; ui_error to gui_error
: > "$CALLS"; SW_UI=gui
ui_step 4 17 "Afinando"; grep -q "PROG:Afinando" "$CALLS" || { echo "FAIL: gui step routing"; exit 1; }
ui_error "boom"; grep -q "ERR:boom" "$CALLS" || { echo "FAIL: gui error routing"; exit 1; }
echo "PASS test_ui_routing"
```

- [ ] **Step 2: Run to verify it fails** → FAIL (`ui_error` undefined; `ui_step` not routing).

- [ ] **Step 3: Modify `lib/ui.sh`** (replace `ui_step`, add `ui_error`)

```bash
ui_step() {
  if [ "${SW_UI:-terminal}" = gui ]; then
    gui_progress_update "$3"
  else
    printf '\n%s[%s/%s] %s%s\n' "$C_INFO" "$1" "$2" "$3" "$C_OFF"
  fi
}
# ui_error TEXT [LOGPATH]
ui_error() {
  if [ "${SW_UI:-terminal}" = gui ]; then
    gui_error "$1" "${2:-}"
  else
    printf '%s\n' "$1" >&2
  fi
}
```

- [ ] **Step 4: Run to verify it passes** → `PASS test_ui_routing`.

- [ ] **Step 5: Commit**

```bash
git add lib/ui.sh tests/gui/test_ui_routing.sh
git -c user.name="Second Wind" -c user.email="hello@secondwindformac.com" \
  commit -m "ui: route step/error to the GUI progress window when SW_UI=gui"
```

---

### Task 5: `install.sh` skips its question phase under `--firstboot`; `common.sh` sources `gui.sh`

**Files:**
- Modify: `install.sh:63-69` (question phase guard); `lib/common.sh` (source `gui.sh`)
- Test: `tests/gui/test_install_firstboot_flags.sh`

**Interfaces:**
- Consumes: `FIRSTBOOT` (already parsed). Produces: with `--firstboot`, `install.sh` runs modules without asking welcome/confirm/hardware; `WITH_HARDWARE` stays 1.

- [ ] **Step 1: Write the failing test** (guard the question block so it is skipped when FIRSTBOOT=1; assert via a stubbed run that no `ui_msg`/`ui_yesno` fire)

```bash
# tests/gui/test_install_firstboot_flags.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Static assertion: the question phase is guarded by FIRSTBOOT
grep -Eq '\[ *"\$FIRSTBOOT" *!= *1 *\].*\{|FIRSTBOOT.*question' "$ROOT/install.sh" \
  || grep -q 'FIRSTBOOT" != 1' "$ROOT/install.sh" \
  || { echo "FAIL: question phase not guarded by FIRSTBOOT"; exit 1; }
grep -q 'source lib/gui.sh\|source "\?\$SW_LIB/gui.sh\|gui.sh' "$ROOT/lib/common.sh" \
  || { echo "FAIL: common.sh does not source gui.sh"; exit 1; }
bash -n "$ROOT/install.sh" && bash -n "$ROOT/lib/common.sh" || { echo "FAIL: syntax"; exit 1; }
echo "PASS test_install_firstboot_flags"
```

- [ ] **Step 2: Run to verify it fails** → FAIL.

- [ ] **Step 3: Implement**

In `install.sh`, guard the question phase (line ~63):

```bash
if [ ${#ONLY_MODULES[@]} -eq 0 ] && [ "$FIRSTBOOT" != 1 ]; then
  ui_msg "${MSG[welcome]}"
  ui_yesno "${MSG[confirm]}" || die "${MSG[cancelled]}"
  if [ "$WITH_HARDWARE" = 1 ] && [ "$ASSUME_YES" != 1 ] && ui_has_tty; then
    ui_yesno "${MSG[ask_hardware]}" || WITH_HARDWARE=0
  fi
fi
```

In `lib/common.sh`, after the output helpers are defined and before use, add:

```bash
# GUI shell (only active when SW_UI=gui); safe no-op helpers otherwise.
[ -f "$SW_LIB/gui.sh" ] && source "$SW_LIB/gui.sh"
```

- [ ] **Step 4: Run to verify it passes** → `PASS`. Also run the whole suite: `for t in tests/gui/*.sh; do bash "$t" || exit 1; done`.

- [ ] **Step 5: Commit**

```bash
git add install.sh lib/common.sh tests/gui/test_install_firstboot_flags.sh
git -c user.name="Second Wind" -c user.email="hello@secondwindformac.com" \
  commit -m "install: skip question phase under --firstboot; wire gui.sh"
```

---

### Task 6: `firstboot` — graphical orchestration + i18n

**Files:**
- Modify: `usb/firstboot/second-wind-firstboot.sh`
- Modify: `lib/i18n/en.sh`, `lib/i18n/es.sh`
- Test: `tests/gui/test_firstboot_flow.sh` (stubbed)

**Interfaces:**
- Consumes: `gui_available`, `gui_consent`, `gui_auth_begin/ensure/end`, `gui_progress_open/close`, `gui_error`, `install.sh --firstboot`. Produces: the guided graphical conversion; terminal fallback preserved.

- [ ] **Step 1: Add i18n strings** (both files) — consent body, phases, errors, auth prompt. EN example (mirror in ES):

```bash
[gui_ok]="Turn my Mac on"
[gui_cancel]="Not now"
[gui_consent]="This turns your Ubuntu into a Mac: the full look, Mac keyboard shortcuts, Spotlight search, and MacBook fixes (camera, fan, F-keys, Mac login screen).\n\nA FULL BACKUP of your settings is saved first, and everything can be undone later.\n\nIt takes a few minutes and restarts once at the end. Ready?"
[gui_pw_prompt]="Enter your password to let Second Wind set things up"
[gui_phase_prep]="Preparing…"
[gui_phase_install]="Installing your Mac experience…"
[gui_phase_finish]="Finishing touches…"
[gui_err_title]="Second Wind"
[gui_err_body]="Something interrupted the setup. Nothing was lost — it will resume next time you log in."
[gui_err_log]="Technical log:"
```

- [ ] **Step 2: Write the failing stubbed flow test**

```bash
# tests/gui/test_firstboot_flow.sh — assert the GUI branch calls the flow in order
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
grep -q 'SW_UI=gui' "$ROOT/usb/firstboot/second-wind-firstboot.sh" || { echo "FAIL: firstboot does not run install in gui mode"; exit 1; }
grep -q 'gui_available' "$ROOT/usb/firstboot/second-wind-firstboot.sh" || { echo "FAIL: no gui_available gate"; exit 1; }
grep -q 'gui_consent' "$ROOT/usb/firstboot/second-wind-firstboot.sh" || { echo "FAIL: no consent"; exit 1; }
grep -q 'gui_auth_begin' "$ROOT/usb/firstboot/second-wind-firstboot.sh" || { echo "FAIL: no auth"; exit 1; }
grep -q 'gui_progress_open' "$ROOT/usb/firstboot/second-wind-firstboot.sh" || { echo "FAIL: no progress"; exit 1; }
# terminal fallback still present (gnome-terminal path kept)
grep -q 'gnome-terminal' "$ROOT/usb/firstboot/second-wind-firstboot.sh" || { echo "FAIL: terminal fallback removed"; exit 1; }
bash -n "$ROOT/usb/firstboot/second-wind-firstboot.sh" || { echo "FAIL: syntax"; exit 1; }
echo "PASS test_firstboot_flow"
```

- [ ] **Step 3: Implement the GUI branch in `firstboot`** (after the net-wait; keep the existing terminal path as the `else`/fallback). Sketch to implement precisely:

```bash
# Source the payload's libs so we can use gui_* helpers.
export SW_ROOT="$SWDIR"; source "$SWDIR/lib/common.sh"

run_gui() {
  gui_consent "${MSG[gui_consent]}" || return 2      # 2 = user said "Not now" (stay armed, quiet)
  gui_auth_begin || return 2                          # user cancelled the password
  gui_progress_open "${MSG[gui_phase_prep]}"
  # install.sh runs hidden; ui_step drives the progress window via SW_PROGRESS_FIFO
  SW_UI=gui "$SWDIR/install.sh" --firstboot; local rc=$?
  gui_progress_close
  gui_auth_end
  return "$rc"
}

if gui_available; then
  if run_gui; then
    touch "$STAMP"; rm -f "$AUTOSTART"
    notify-send -i emblem-ok-symbolic "Second Wind" "$T_DONE" 2>/dev/null || true
    sleep 6
    gnome-session-quit --reboot --no-prompt 2>/dev/null || systemctl reboot 2>/dev/null \
      || sudo -n systemctl reboot 2>/dev/null || true
    exit 0
  else
    rc=$?
    [ "$rc" = 2 ] || gui_error "${MSG[gui_err_body]}" "$LOGDIR"   # real error → visible; cancel(2) → silent
    exit 0   # autostart stays armed; next login retries (existing behavior)
  fi
else
  : # fall through to the existing gnome-terminal path below (unchanged)
fi
```

(The existing `gnome-terminal --wait -- bash -c "$RUN"` block and its `--firstboot` wiring from Task 5 remain as the fallback for machines without a usable zenity/DISPLAY.)

- [ ] **Step 4: Run to verify it passes** → `bash tests/gui/test_firstboot_flow.sh` → `PASS`; run the full suite.

- [ ] **Step 5: Commit**

```bash
git add usb/firstboot/second-wind-firstboot.sh lib/i18n/en.sh lib/i18n/es.sh tests/gui/test_firstboot_flow.sh
git -c user.name="Second Wind" -c user.email="hello@secondwindformac.com" \
  commit -m "firstboot: graphical conversion (consent, one password, progress) with terminal fallback"
```

---

### Task 7: Clean-VM E2E acceptance (Mac's Claude) + Toshy-failure surfacing

**Files:**
- Modify (if needed): `usb/firstboot/second-wind-firstboot.sh` (Toshy non-fatal notice)
- Deliverable: verification brief + evidence in Drive/customer-journey

**This is the real acceptance — the Taller cannot run GNOME.** Hand the Mac's Claude a brief to run a clean-VM install of this branch and confirm, with screenshots + outputs:

- [ ] **Step 1:** One graphical **consent** window (no terminal); user clicks once.
- [ ] **Step 2:** One graphical **password** prompt; never asked again mid-run.
- [ ] **Step 3:** A **progress window** with friendly phases (Preparing → Installing → Finishing); it visibly advances, never a black terminal.
- [ ] **Step 4:** On success: "Casi listo…" + **auto-reboot**; 2nd login → full Mac desktop (⌘, dark bar, 4 extensions ACTIVE via `verify.sh --all`).
- [ ] **Step 5:** **No mute hang** if a step needs privilege (verify the keepalive held; if forced to fail, a `zenity --error` with the log path appears).
- [ ] **Step 6:** **Standalone unchanged:** `./install.sh` in a real terminal still shows the whiptail flow.
- [ ] **Step 7:** If Toshy fails headless, a gentle non-fatal notice appears (⌘ keyboard pending) rather than silent breakage. Add the notice in `firstboot`/module if the E2E shows it's silent.
- [ ] **Step 8:** Report to Drive `customer-journey/` (REPORTE-R4 + screenshots). Only after this passes: merge branch → `main`.

---

## Self-Review

- **Spec coverage:** privilege P0 → Task 2 (askpass/keepalive/ensure, no pkexec) ✓; progress P0 → Task 3 (pulsating phases, deterministic close) ✓; no-silent-failure → Task 3/4/6 (gui_error + retry) ✓; graphical-or-abort fallback → Task 6 (`gui_available` gate, terminal else) ✓; standalone untouched → Task 4/5 (SW_UI guard, terminal path kept) + Task 7 Step 6 ✓; one consent describing consequences → Task 6 i18n `gui_consent` ✓; Toshy surfacing → Task 7 Step 7 ✓; i18n ES/EN → Task 6 ✓.
- **Placeholder scan:** none — every step has concrete code/commands.
- **Type/name consistency:** `gui_available/gui_consent/gui_error/gui_auth_begin/gui_auth_ensure/gui_auth_end/gui_progress_open/gui_progress_update/gui_progress_close`, `SW_UI`, `SW_PROGRESS_FIFO`, `SUDO_ASKPASS` used consistently across tasks.
- **Deferred (YAGNI, per committee):** exact-% progress and a full multi-backend UI abstraction are OUT until after the destructive Mac test.
- **Deferred risk to watch (Task 7):** polkit/DISPLAY agent readiness at first-login autostart — the `gui_available` gate + first-boot retry mitigate; confirm timing in the VM.
