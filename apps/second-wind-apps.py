#!/usr/bin/env python3
"""Second Wind Apps — native GTK4/libadwaita app picker (store v2).

End users never see a terminal: switches per app, one system password window
(pkexec) for the whole batch, web apps created silently. Falls back to the
zenity picker (second-wind-apps.sh) on systems without libadwaita bindings.
"""
import json
import locale
import os
import shutil
import subprocess
import sys
import threading

SW_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SW_STATE = os.path.expanduser("~/.local/state/second-wind")
SW_SHARE = os.path.expanduser("~/.local/share/second-wind")
LOGDIR = os.path.join(SW_STATE, "logs")
os.makedirs(LOGDIR, exist_ok=True)

try:
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Adw, GLib, Gtk  # noqa: E402
except Exception:
    os.execv("/bin/bash", ["bash", os.path.join(SW_ROOT, "apps", "second-wind-apps.sh")])

ES = (locale.getlocale()[0] or os.environ.get("LANG", "en")).startswith("es")

T = {
    "title": "Second Wind Apps",
    "subtitle": "Añade apps con un interruptor — sin comandos" if ES
                else "Add apps with a switch — no commands",
    "g_ess": "Esenciales" if ES else "Essentials",
    "g_media": "Música y oficina" if ES else "Music & office",
    "g_calls": "Videollamadas" if ES else "Video calls",
    "g_web": "Apps web (ventana propia + icono en el dock)" if ES
             else "Web apps (own window + dock icon)",
    "install": "Instalar seleccionadas" if ES else "Install selected",
    "installing": "Instalando… (la contraseña se pide en una ventana del sistema)"
                  if ES else "Installing… (your password is asked in a system window)",
    "done_ok": "¡Listo! Encuentra tus apps con Cmd+Espacio." if ES
               else "Done! Find your apps with Cmd+Space.",
    "done_warn": "Terminado con avisos — detalle en apps-gui.log" if ES
                 else "Finished with warnings — details in apps-gui.log",
    "nothing": "Enciende al menos un interruptor." if ES else "Turn on at least one switch.",
    "g_support": "El proyecto" if ES else "The project",
    "donate": "Apoyar Second Wind" if ES else "Support Second Wind",
    "donate_sub": "Donaciones y novedades del proyecto" if ES
                  else "Donations and project news",
    "news": "Avisos de novedades y apoyo" if ES else "News & support notices",
    "news_sub": "Una notificación ocasional; apágalo cuando quieras" if ES
                else "An occasional notification; turn off anytime",
    "quicklook": ("Quick Look", "Vista previa con la barra espaciadora" if ES
                  else "Preview files with the Space bar"),
    "vlc": ("VLC", "Reproduce cualquier video" if ES else "Plays any video"),
    "spotify": ("Spotify", "Música (tienda oficial)" if ES else "Music (official store)"),
    "office": ("OnlyOffice", "Abre y edita Word, Excel, PowerPoint" if ES
               else "Opens and edits Word, Excel, PowerPoint"),
    "zoom": ("Zoom", "App oficial de zoom.us" if ES else "Official app from zoom.us"),
    "wa": ("WhatsApp", "web.whatsapp.com como app" if ES else "web.whatsapp.com as an app"),
    "o365": ("Office 365", "office.com como app" if ES else "office.com as an app"),
    "netflix": ("Netflix", "netflix.com como app" if ES else "netflix.com as an app"),
}


def links():
    cfg = {"DONATE_URL": "https://github.com/arancibiamartin/second-wind"}
    try:
        with open(os.path.join(SW_ROOT, "links.conf")) as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    cfg[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    return cfg


def mf(*args):
    subprocess.run(["python3", os.path.join(SW_ROOT, "lib", "manifest.py"), *args],
                   env={**os.environ, "SW_MANIFEST": os.path.join(SW_STATE, "manifest.json")},
                   check=False)


def make_webapp(app_id, name, url, domain):
    browser = shutil.which("google-chrome") or shutil.which("google-chrome-stable")
    if not browser:
        return f"{name}: Chrome"
    icons = os.path.join(SW_SHARE, "webapps")
    os.makedirs(icons, exist_ok=True)
    icon = os.path.join(icons, f"{app_id}.png")
    subprocess.run(["curl", "-fsSL", "-m", "10", "-o", icon,
                    f"https://www.google.com/s2/favicons?domain={domain}&sz=128"],
                   check=False)
    if not (os.path.exists(icon) and os.path.getsize(icon) > 0):
        icon = "web-browser"
    desk = os.path.expanduser(f"~/.local/share/applications/secondwind-{app_id}.desktop")
    with open(desk, "w") as f:
        f.write(f"[Desktop Entry]\nType=Application\nName={name}\n"
                f"Exec={browser} --app={url} --class=secondwind-{app_id}\n"
                f"Icon={icon}\nStartupWMClass=secondwind-{app_id}\nCategories=Network;\n")
    mf("file-created", desk)
    if icon != "web-browser":
        mf("file-created", icon)
    return None


class Store(Adw.Application):
    def __init__(self):
        super().__init__(application_id="app.secondwind.Apps")

    def do_activate(self):
        self.win = Adw.ApplicationWindow(application=self, title=T["title"],
                                         default_width=560, default_height=720)
        view = Adw.ToolbarView()
        header = Adw.HeaderBar()
        view.add_top_bar(header)

        page = Adw.PreferencesPage()
        self.rows = {}

        def group(title, items):
            g = Adw.PreferencesGroup(title=title)
            for key, default in items:
                name, sub = T[key]
                row = Adw.SwitchRow(title=name, subtitle=sub, active=default)
                self.rows[key] = row
                g.add(row)
            page.add(g)

        group(T["g_ess"], [("quicklook", True), ("vlc", True)])
        group(T["g_media"], [("spotify", True), ("office", True)])
        group(T["g_calls"], [("zoom", False)])
        group(T["g_web"], [("wa", True), ("o365", False), ("netflix", False)])

        sup = Adw.PreferencesGroup(title=T["g_support"])
        donate = Adw.ActionRow(title=T["donate"], subtitle=T["donate_sub"],
                               activatable=True)
        donate.add_suffix(Gtk.Image.new_from_icon_name("adw-external-link-symbolic"))
        donate.connect("activated", lambda *_:
                       subprocess.Popen(["xdg-open", links()["DONATE_URL"]]))
        sup.add(donate)
        self.news = Adw.SwitchRow(title=T["news"], subtitle=T["news_sub"],
                                  active=not os.path.exists(
                                      os.path.join(SW_STATE, "news-optout")))
        self.news.connect("notify::active", self.on_news)
        sup.add(self.news)
        page.add(sup)

        self.status = Gtk.Label(label="", wrap=True, margin_start=16, margin_end=16)
        self.spinner = Gtk.Spinner(margin_end=8)
        self.button = Gtk.Button(css_classes=["suggested-action", "pill"],
                                 margin_top=6, margin_bottom=18, halign=Gtk.Align.CENTER)
        bb = Gtk.Box(spacing=6)
        bb.append(self.spinner)
        bb.append(Gtk.Label(label=T["install"]))
        self.button.set_child(bb)
        self.button.connect("clicked", self.on_install)

        bottom = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        bottom.append(self.status)
        bottom.append(self.button)

        scroller = Gtk.ScrolledWindow(child=page, vexpand=True)
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content.append(scroller)
        content.append(bottom)
        view.set_content(content)
        self.win.set_content(view)
        self.win.present()

    def on_news(self, row, _param):
        flag = os.path.join(SW_STATE, "news-optout")
        if row.get_active():
            try:
                os.remove(flag)
            except FileNotFoundError:
                pass
        else:
            open(flag, "w").close()

    def on_install(self, _btn):
        sel = {k for k, r in self.rows.items() if r.get_active()}
        if not sel:
            self.status.set_label(T["nothing"])
            return
        self.button.set_sensitive(False)
        self.spinner.start()
        self.status.set_label(T["installing"])
        threading.Thread(target=self.worker, args=(sel,), daemon=True).start()

    def worker(self, sel):
        fails = []
        apt = []
        snaps = []
        if "quicklook" in sel:
            apt.append("gnome-sushi")
        if "vlc" in sel:
            apt.append("vlc")
        if "spotify" in sel and subprocess.run(
                ["snap", "list", "spotify"], capture_output=True).returncode:
            snaps.append("spotify")
        if "office" in sel and subprocess.run(
                ["snap", "list", "onlyoffice-desktopeditors"],
                capture_output=True).returncode:
            snaps.append("onlyoffice-desktopeditors")
        zoom_deb = ""
        if "zoom" in sel and subprocess.run(
                ["dpkg", "-s", "zoom"], capture_output=True).returncode:
            zoom_deb = os.path.join(SW_STATE, "cache", "zoom_amd64.deb")
            os.makedirs(os.path.dirname(zoom_deb), exist_ok=True)
            if subprocess.run(["curl", "-fsSL", "-o", zoom_deb,
                               "https://zoom.us/client/latest/zoom_amd64.deb"]).returncode:
                fails.append("Zoom (download)")
                zoom_deb = ""

        if apt or snaps or zoom_deb:
            cmd = "set -e; export DEBIAN_FRONTEND=noninteractive; apt-get update -qq || true"
            if apt:
                cmd += "; apt-get install -y " + " ".join(apt)
            for s in snaps:
                cmd += f"; snap install {s}"
            if zoom_deb:
                cmd += f"; apt-get install -y '{zoom_deb}'"
            with open(os.path.join(LOGDIR, "apps-gui.log"), "a") as log:
                rc = subprocess.run(["pkexec", "bash", "-c", cmd],
                                    stdout=log, stderr=log).returncode
            if rc != 0:
                fails.append("pkexec")
            else:
                for s in snaps:
                    mf("note", f"app-{s.split('-')[0]}")
                if zoom_deb:
                    mf("note", "app-zoom")

        for key, args in (("wa", ("whatsapp", "WhatsApp", "https://web.whatsapp.com", "whatsapp.com")),
                          ("o365", ("office365", "Office 365", "https://www.office.com", "office.com")),
                          ("netflix", ("netflix", "Netflix", "https://www.netflix.com", "netflix.com"))):
            if key in sel:
                err = make_webapp(*args)
                if err:
                    fails.append(err)

        GLib.idle_add(self.finish, fails)

    def finish(self, fails):
        self.spinner.stop()
        self.button.set_sensitive(True)
        self.status.set_label(T["done_warn"] if fails else T["done_ok"])
        return False


if __name__ == "__main__":
    sys.exit(Store().run(None))
