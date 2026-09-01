#!/usr/bin/env python3
"""Second Wind USB Creator — native GTK4/libadwaita, no terminal.

Flow: intro → prepare (real-progress ISO download with resume + seed build)
→ pick a stick (small ones disabled with the reason) → hard confirm →
write (live GB progress from dd) → done. Desktop notifications fire on
milestones so switching apps never loses you. Falls back to the zenity flow
(make-usb.sh --gui) where libadwaita bindings are missing.
"""
import locale
import os
import shutil
import subprocess
import sys
import threading
import urllib.request

SW_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SW_STATE = os.path.expanduser("~/.local/state/second-wind")
LOGDIR = os.path.join(SW_STATE, "logs")
os.makedirs(LOGDIR, exist_ok=True)


def ensure_launcher():
    """Register our own app icon so the creator opens from the applications
    grid WITHOUT a terminal. Runs on every start (idempotent, self-heals the
    path); wrapped so a launcher hiccup never blocks the app."""
    try:
        apps = os.path.expanduser("~/.local/share/applications")
        os.makedirs(apps, exist_ok=True)
        icon = os.path.join(SW_ROOT, "creator", "macos", "assets", "icon-1024.png")
        with open(os.path.join(apps, "second-wind-usb-creator.desktop"), "w") as f:
            f.write(
                "[Desktop Entry]\n"
                "Type=Application\n"
                "Name=Second Wind USB Creator\n"
                "Comment=Create a bootable Second Wind USB installer\n"
                f"Exec=python3 {os.path.abspath(__file__)}\n"
                f"Icon={icon}\n"
                "Terminal=false\n"
                "Categories=System;Utility;\n"
                "StartupNotify=true\n"
            )
        subprocess.Popen(["update-desktop-database", apps],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass  # the launcher is a convenience; never let it stop the creator


ensure_launcher()

try:
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Adw, GLib, Gtk  # noqa: E402
except Exception:
    os.execv("/bin/bash", ["bash", os.path.join(SW_ROOT, "scripts", "make-usb.sh"), "--gui"])

MIN_BYTES = 7 * 1000**3   # real-world "8 GB" sticks are ~7.2 GiB; payload is ~6.5 GB


def lock_value(key):
    with open(os.path.join(SW_ROOT, "versions.lock")) as f:
        for line in f:
            if line.startswith(key + "="):
                return line.split("=", 1)[1].split("#")[0].strip()
    raise KeyError(key)


ISO_URL = lock_value("UBUNTU_ISO_URL")
ISO_SHA = lock_value("UBUNTU_ISO_SHA256")
ISO = os.path.join(SW_STATE, "cache", "iso", os.path.basename(ISO_URL))

def build_T(ES):
    return {
    "title": "Second Wind USB Creator",
    "intro_t": "Un pendrive que instala la “Mac nueva” completa" if ES
               else "One USB stick that installs the whole “new Mac”",
    "intro_b": ("• Pendrive de 8 GB o más (se borra entero)\n"
                "• La primera vez se descargan ~6 GB del Ubuntu oficial, verificados\n"
                "• Puedes cambiar de app: te avisamos con una notificación al terminar")
               if ES else
               ("• 8 GB or larger stick (fully erased)\n"
                "• First run downloads ~6 GB of verified official Ubuntu\n"
                "• Feel free to switch apps: a notification tells you when it's done"),
    "start": "Comenzar" if ES else "Start",
    "prep": "Preparando Ubuntu oficial…" if ES else "Preparing official Ubuntu…",
    "verify": "Verificando la descarga… (puede tardar ~1 min)" if ES else "Verifying the download… (may take ~1 min)",
    "seed": "Preparando la semilla Second Wind…" if ES else "Preparing the Second Wind seed…",
    "pick_t": "Elige el pendrive" if ES else "Choose the stick",
    "pick_b": "Se borrará por completo." if ES else "It will be completely erased.",
    "too_small": "Muy pequeño — se necesitan 8 GB" if ES else "Too small — 8 GB needed",
    "no_usb": "Conecta un pendrive y pulsa Actualizar." if ES
              else "Plug a stick in and press Refresh.",
    "refresh": "Actualizar" if ES else "Refresh",
    "write_btn": "Borrar y crear instalador" if ES else "Erase and create installer",
    "confirm_t": "¿Borrar TODO el contenido?" if ES else "Erase EVERYTHING on it?",
    "confirm_b": "no tiene vuelta atrás." if ES else "cannot be undone.",
    "cancel": "Cancelar" if ES else "Cancel",
    "erase": "Sí, borrar" if ES else "Yes, erase",
    "locks_t": "Antes de borrar — dos confirmaciones" if ES
               else "Before we erase — two promises",
    "locks_b": "Marca las dos casillas para continuar. Instalar borra TODO este Mac." if ES
               else "Tick both boxes to continue. Installing erases EVERYTHING on this Mac.",
    "lock1": "Respaldé mis fotos, archivos y contraseñas (están en otro lugar)" if ES
             else "I backed up my photos, files and passwords (they're somewhere else)",
    "lock2": "Entiendo que este Mac se borrará por completo" if ES
             else "I understand this Mac will be completely erased",
    "continue": "Continuar" if ES else "Continue",
    "writing": "Escribiendo el pendrive — no lo desconectes" if ES
               else "Writing the stick — do not unplug it",
    "finishing": "Sellando la semilla…" if ES else "Sealing the seed…",
    "done_t": "¡Pendrive listo! 🎉" if ES else "USB ready! 🎉",
    "done_b": ("En el Mac a revivir: enciéndelo manteniendo Option (⌥), elige "
               "“EFI Boot” y responde las 4 pantallas. El resto es automático.")
              if ES else
              ("On the Mac to revive: power on holding Option (⌥), pick "
               "“EFI Boot” and answer the 4 screens. The rest is automatic."),
    "close": "Cerrar" if ES else "Close",
    "fail_t": "Algo falló" if ES else "Something failed",
    "fail_b": "Detalle en usb-creator.log. Reintenta: nada quedó a medias peligrosas."
              if ES else
              "Details in usb-creator.log. Retry: nothing was left half-dangerous.",
    "busy_close": "Espera a que termine la escritura para cerrar." if ES
                  else "Wait for the write to finish before closing.",
    "n_ready": "Pendrive listo para crear tu Mac nueva" if ES
               else "USB ready to create your new Mac",
    "n_fail": "El creador de USB encontró un problema" if ES
              else "The USB creator hit a problem",
}


LANG_ES = False   # English by default; the first screen offers a manual switch
T = build_T(LANG_ES)


def notify(body):
    subprocess.Popen(["notify-send", "-a", "Second Wind", "-i", "drive-removable-media",
                      T["title"], body])


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024


class Creator(Adw.Application):
    def __init__(self):
        super().__init__(application_id="app.secondwind.USBCreator")
        self.writing = False
        self._pulse_id = None

    # ---------- UI scaffolding ----------
    def do_activate(self):
        self.win = Adw.ApplicationWindow(application=self, title=T["title"],
                                         default_width=520, default_height=560)
        self.win.connect("close-request", self.on_close)
        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        view = Adw.ToolbarView()
        view.add_top_bar(Adw.HeaderBar())
        view.set_content(self.stack)
        self.win.set_content(view)
        self.page_intro()
        self.win.present()

    def page(self, name, *children):
        old = self.stack.get_child_by_name(name)
        if old is not None:
            self.stack.remove(old)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14,
                      margin_top=28, margin_bottom=28, margin_start=28, margin_end=28,
                      valign=Gtk.Align.CENTER)
        for c in children:
            box.append(c)
        self.stack.add_named(box, name)
        self.stack.set_visible_child_name(name)

    def status_page(self, icon, title, body):
        sp = Adw.StatusPage(icon_name=icon, title=title, description=body)
        sp.set_vexpand(True)
        return sp

    # ---------- pages ----------
    def page_intro(self):
        lang_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6,
                           halign=Gtk.Align.CENTER)
        en = Gtk.ToggleButton(label="English", css_classes=["pill"], active=not LANG_ES)
        es = Gtk.ToggleButton(label="Español", css_classes=["pill"], active=LANG_ES)
        es.set_group(en)
        en.connect("toggled", lambda b: b.get_active() and self._set_lang(False))
        es.connect("toggled", lambda b: b.get_active() and self._set_lang(True))
        lang_row.append(en)
        lang_row.append(es)
        sp = self.status_page("media-removable-symbolic", T["intro_t"], T["intro_b"])
        b = Gtk.Button(label=T["start"], css_classes=["suggested-action", "pill"],
                       halign=Gtk.Align.CENTER)
        b.connect("clicked", lambda *_: self.page_prepare())
        self.page("intro", lang_row, sp, b)

    def _set_lang(self, es):
        global LANG_ES, T
        if es == LANG_ES:
            return
        LANG_ES = es
        T = build_T(LANG_ES)
        self.win.set_title(T["title"])
        self.page_intro()

    def page_prepare(self):
        self.prog = Gtk.ProgressBar(show_text=True, fraction=0)
        self.plabel = Gtk.Label(label=T["prep"])
        self.page("prep", self.status_page("folder-download-symbolic", T["prep"], ""),
                  self.prog, self.plabel)
        threading.Thread(target=self.prepare_worker, daemon=True).start()

    def prepare_worker(self):
        try:
            os.makedirs(os.path.dirname(ISO), exist_ok=True)
            want = None
            req = urllib.request.Request(ISO_URL, method="HEAD")
            with urllib.request.urlopen(req, timeout=20) as r:
                want = int(r.headers["Content-Length"])
            have = os.path.getsize(ISO) if os.path.exists(ISO) else 0
            if have < want:
                req = urllib.request.Request(ISO_URL)
                if have:
                    req.add_header("Range", f"bytes={have}-")
                with urllib.request.urlopen(req, timeout=30) as r, open(ISO, "ab") as f:
                    while True:
                        chunk = r.read(1024 * 512)
                        if not chunk:
                            break
                        f.write(chunk)
                        have += len(chunk)
                        GLib.idle_add(self.set_prog, have / want,
                                      f"{human(have)} / {human(want)}")
            GLib.idle_add(self.prep_phase, T["verify"])
            out = subprocess.run(["sha256sum", ISO], capture_output=True,
                                 text=True).stdout.split()[0]
            if out != ISO_SHA:
                os.remove(ISO)
                raise RuntimeError("checksum")
            GLib.idle_add(self.prep_phase, T["seed"])
            r = subprocess.run(["bash", os.path.join(SW_ROOT, "scripts", "make-usb.sh"),
                                "--build"],
                               stdout=open(os.path.join(LOGDIR, "usb-creator.log"), "a"),
                               stderr=subprocess.STDOUT)
            if r.returncode:
                raise RuntimeError("build")
            GLib.idle_add(self.page_pick)
        except Exception:
            GLib.idle_add(self.page_fail)

    def set_prog(self, frac, text):
        self.prog.set_fraction(frac)
        self.plabel.set_label(text)
        self.win.set_title(f"{int(frac*100)}% — {T['title']}")
        return False

    def prep_phase(self, text):
        # Indeterminate steps (verify, seed): pulse so it never looks frozen at 100%.
        self.plabel.set_label(text)
        self.win.set_title(f"{T['title']} — {text}")
        self.prog.set_fraction(0.0)
        if not self._pulse_id:
            self.prog.set_pulse_step(0.1)
            self._pulse_id = GLib.timeout_add(120, self._pulse_tick)
        return False

    def _pulse_tick(self):
        self.prog.pulse()
        return True

    def _stop_pulse(self):
        if self._pulse_id:
            GLib.source_remove(self._pulse_id)
            self._pulse_id = None

    def sticks(self):
        out = subprocess.run(["lsblk", "-dbnro", "NAME,SIZE,MODEL,RM"],
                             capture_output=True, text=True).stdout
        rows = []
        for line in out.strip().splitlines():
            parts = line.split(None, 2)
            if len(parts) < 2:
                continue
            name, size = parts[0], int(parts[1])
            rest = parts[2] if len(parts) > 2 else "1"
            rm = rest.rsplit(None, 1)[-1]
            model = rest[:-1].strip() if rest.endswith(("0", "1")) else ""
            if rm != "1":
                continue
            rows.append((f"/dev/{name}", size, model or "USB"))
        return rows

    def page_pick(self):
        self._stop_pulse()
        group = Adw.PreferencesGroup(title=T["pick_t"], description=T["pick_b"])
        rows = self.sticks()
        self.checks = []
        anchor = None
        first = None
        if not rows:
            group.add(Adw.ActionRow(title=T["no_usb"]))
        for dev, size, model in rows:
            ok = size >= MIN_BYTES
            row = Adw.ActionRow(title=f"{model} — {human(size)}",
                                subtitle=dev if ok else f"{dev} · {T['too_small']}")
            check = Gtk.CheckButton()
            check.dev = dev
            if anchor:
                check.set_group(anchor)
            else:
                anchor = check
            if ok:
                self.checks.append(check)
                if first is None:
                    first = check
            row.add_prefix(check)
            row.set_activatable_widget(check)
            row.set_sensitive(ok)
            group.add(row)
        if first:
            first.set_active(True)

        refresh = Gtk.Button(label=T["refresh"], halign=Gtk.Align.CENTER,
                             css_classes=["pill"])
        refresh.connect("clicked", lambda *_: self.page_pick())
        go = Gtk.Button(label=T["write_btn"], halign=Gtk.Align.CENTER,
                        css_classes=["destructive-action", "pill"],
                        sensitive=bool(first))
        go.connect("clicked", self.confirm)
        btns = Gtk.Box(spacing=10, halign=Gtk.Align.CENTER)
        btns.append(refresh)
        btns.append(go)
        self.page("pick", group, btns)

    def confirm(self, _b):
        dev = next((c.dev for c in self.checks if c.get_active()), None)
        if not dev:
            return
        # Lock 1 of 2 — the backup checklist. BOTH promises are required to go on.
        d = Adw.AlertDialog(heading=T["locks_t"], body=T["locks_b"])
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin_top=6)
        c1 = Gtk.CheckButton(label=T["lock1"])
        c2 = Gtk.CheckButton(label=T["lock2"])
        box.append(c1)
        box.append(c2)
        d.set_extra_child(box)
        d.add_response("cancel", T["cancel"])
        d.add_response("go", T["continue"])
        d.set_response_appearance("go", Adw.ResponseAppearance.DESTRUCTIVE)
        d.set_response_enabled("go", False)
        d.set_default_response("cancel")

        def gate(*_):
            d.set_response_enabled("go", c1.get_active() and c2.get_active())
        c1.connect("toggled", gate)
        c2.connect("toggled", gate)
        d.connect("response", lambda _d, r: r == "go" and self.confirm_erase(dev))
        d.present(self.win)

    def confirm_erase(self, dev):
        # Lock 2 of 2 — the final, unambiguous erase confirmation.
        d = Adw.AlertDialog(heading=T["confirm_t"],
                            body=f"{dev} — {T['confirm_b']}")
        d.add_response("cancel", T["cancel"])
        d.add_response("erase", T["erase"])
        d.set_response_appearance("erase", Adw.ResponseAppearance.DESTRUCTIVE)
        d.set_default_response("cancel")
        d.connect("response", lambda _d, r: r == "erase" and self.page_write(dev))
        d.present(self.win)

    def page_write(self, dev):
        self.writing = True
        self.prog = Gtk.ProgressBar(show_text=True, fraction=0)
        self.plabel = Gtk.Label(label=T["writing"])
        self.page("write", self.status_page("drive-harddisk-usb-symbolic",
                                            T["writing"], dev),
                  self.prog, self.plabel)
        threading.Thread(target=self.write_worker, args=(dev,), daemon=True).start()

    def write_worker(self, dev):
        status = os.path.join(LOGDIR, "usb-dd-status")
        open(status, "w").close()
        total = os.path.getsize(ISO)
        # pkexec runs as root with HOME=/root and a sanitized environment, so the
        # ISO/seed would be looked up under /root and dd would fail. Pass the real
        # user's SW_STATE through `env` (as an argument, it survives pkexec's env reset).
        p = subprocess.Popen(["pkexec", "/usr/bin/env",
                              f"SW_STATE={SW_STATE}", "SW_DD_STATUS=1", "bash",
                              os.path.join(SW_ROOT, "scripts", "make-usb.sh"),
                              "--write-core", dev],
                             stdout=open(os.path.join(LOGDIR, "usb-creator.log"), "a"),
                             stderr=open(status, "w"))
        while p.poll() is None:
            try:
                with open(status) as f:
                    txt = f.read()
                last = [x for x in txt.replace("\r", "\n").splitlines() if " bytes" in x]
                if last:
                    done = int(last[-1].split()[0])
                    GLib.idle_add(self.set_prog, min(done / total, 0.99),
                                  f"{human(done)} / {human(total)}")
            except Exception:
                pass
            GLib.usleep(700_000)
        self.writing = False
        if p.returncode == 0:
            GLib.idle_add(self.set_prog, 1.0, T["finishing"])
            notify(T["n_ready"])
            GLib.idle_add(self.page_done)
        else:
            notify(T["n_fail"])
            GLib.idle_add(self.page_fail)

    def page_done(self):
        sp = self.status_page("emblem-ok-symbolic", T["done_t"], T["done_b"])
        b = Gtk.Button(label=T["close"], css_classes=["suggested-action", "pill"],
                       halign=Gtk.Align.CENTER)
        b.connect("clicked", lambda *_: self.win.close())
        self.page("done", sp, b)

    def page_fail(self):
        self._stop_pulse()
        sp = self.status_page("dialog-error-symbolic", T["fail_t"], T["fail_b"])
        b = Gtk.Button(label=T["close"], css_classes=["pill"], halign=Gtk.Align.CENTER)
        b.connect("clicked", lambda *_: self.win.close())
        self.page("fail", sp, b)

    def on_close(self, *_):
        if self.writing:
            self.plabel.set_label(T["busy_close"])
            return True
        return False


if __name__ == "__main__":
    sys.exit(Creator().run(None))
