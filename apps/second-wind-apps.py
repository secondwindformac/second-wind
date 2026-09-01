#!/usr/bin/env python3
"""Second Wind Apps — store v3: a compact visual grid of popular apps.

~21 curated apps as icon cards with checkboxes, grouped by what people do.
Icons are fetched at runtime from each project's own site (favicon service),
so no trademarked artwork ships in this repository. One system password
window installs the whole selection. Official sources only.
"""
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
ICONDIR = os.path.join(SW_SHARE, "store-icons")
os.makedirs(LOGDIR, exist_ok=True)
os.makedirs(ICONDIR, exist_ok=True)

try:
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Adw, Gdk, GLib, Gtk  # noqa: E402
except Exception:
    os.execv("/bin/bash", ["bash", os.path.join(SW_ROOT, "apps", "second-wind-apps.sh")])

ES = (locale.getlocale()[0] or os.environ.get("LANG", "en")).startswith("es")


def d(es, en):
    return es if ES else en


# id, name, kind, ref, icon-domain, description, default-on
# kinds: apt | snap | snap_classic | deb (url) | web (url)
CATALOG = [
    ("ess", d("Esenciales", "Essentials"), [
        ("chrome", "Google Chrome", "deb",
         "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
         "chrome.google.com",  # google.com serves the "G", this one the Chrome ball
         d("El navegador que ya conoces — y la base de las apps web",
           "The browser you already know — and what web apps run on"), True),
        ("quicklook", "Quick Look", "apt", "gnome-sushi", "gnome.org",
         d("Vista previa con la barra espaciadora", "Space-bar file preview"), True),
        ("vlc", "VLC", "apt", "vlc", "videolan.org",
         d("Reproduce cualquier video", "Plays any video"), True),
        ("transmission", "Transmission", "apt", "transmission-gtk", "transmissionbt.com",
         d("Descargas torrent", "Torrent downloads"), False),
        ("gimp", "GIMP", "apt", "gimp", "gimp.org",
         d("Edición de imágenes", "Image editing"), False),
    ]),
    ("media", d("Música y video", "Music and video"), [
        ("spotify", "Spotify", "snap", "spotify", "spotify.com",
         d("Tu música", "Your music"), True),
        ("audacity", "Audacity", "apt", "audacity", "audacityteam.org",
         d("Grabación y edición de audio", "Audio recording and editing"), False),
        ("obs", "OBS Studio", "snap", "obs-studio", "obsproject.com",
         d("Streaming y captura", "Streaming and capture"), False),
        ("kdenlive", "Kdenlive", "apt", "kdenlive", "kdenlive.org",
         d("Editor de video", "Video editor"), False),
        ("steam", "Steam", "apt", "steam-installer", "steampowered.com",
         d("Juegos", "Games"), False),
    ]),
    ("social", d("Comunicación", "Communication"), [
        ("zoom", "Zoom", "deb",
         "https://zoom.us/client/latest/zoom_amd64.deb", "zoom.us",
         d("Videollamadas (app oficial)", "Video calls (official app)"), False),
        ("telegram", "Telegram", "snap", "telegram-desktop", "telegram.org",
         d("Mensajería", "Messaging"), False),
        ("discord", "Discord", "deb",
         "https://discord.com/api/download?platform=linux&format=deb", "discord.com",
         d("Chat y comunidades", "Chat and communities"), False),
        ("slack", "Slack", "snap", "slack", "slack.com",
         d("Trabajo en equipo", "Team chat"), False),
    ]),
    ("work", d("Oficina y creatividad", "Office and creativity"), [
        ("onlyoffice", "OnlyOffice", "snap", "onlyoffice-desktopeditors", "onlyoffice.com",
         d("Word, Excel y PowerPoint", "Word, Excel and PowerPoint"), True),
        ("blender", "Blender", "snap_classic", "blender", "blender.org",
         d("3D profesional", "Professional 3D"), False),
    ]),
    ("web", d("Apps web — ventana propia + icono en el dock",
              "Web apps — own window + dock icon"), [
        ("whatsapp", "WhatsApp", "web", "https://web.whatsapp.com", "whatsapp.com",
         d("Tus chats como app", "Your chats as an app"), True),
        ("youtube", "YouTube", "web", "https://www.youtube.com", "youtube.com",
         d("Video como app", "Video as an app"), False),
        ("netflix", "Netflix", "web", "https://www.netflix.com", "netflix.com",
         d("Series y películas", "Shows and movies"), False),
        ("office365", "Office 365", "web", "https://www.office.com", "office.com",
         d("Microsoft 365 en línea", "Microsoft 365 online"), False),
        ("claude", "Claude", "web", "https://claude.ai", "claude.ai",
         d("Tu asistente de IA", "Your AI assistant"), False),
        ("canva", "Canva", "web", "https://www.canva.com", "canva.com",
         d("Diseño fácil", "Easy design"), False),
    ]),
]

T = {
    "title": "Second Wind Apps",
    "install": d("Instalar", "Install"),
    "installing": d("Instalando… (contraseña en ventana del sistema)",
                    "Installing… (password in a system window)"),
    "done_ok": d("¡Listo! Encuentra tus apps con Cmd+Espacio.",
                 "Done! Find your apps with Cmd+Space."),
    "done_warn": d("Terminado con avisos — detalle en apps-gui.log",
                   "Finished with warnings — details in apps-gui.log"),
    "nothing": d("Marca al menos una app.", "Tick at least one app."),
    "g_support": d("El proyecto", "The project"),
    "donate": d("Apoyar Second Wind", "Support Second Wind"),
    "donate_sub": d("Donaciones y novedades", "Donations and news"),
    "news": d("Avisos de novedades y apoyo", "News and support notices"),
    "news_sub": d("Una notificación ocasional; apágalo cuando quieras",
                  "An occasional notification; turn off anytime"),
    "news_test": d("Probar el aviso ahora", "Try the notice now"),
    "news_test_sub": d("Muestra la notificación de ejemplo", "Shows the sample notification"),
    "help": d("Obtener ayuda", "Get help"),
    "help_sub": d("Guía, preguntas frecuentes y reporte de problemas",
                  "Guide, FAQ and problem reports"),
    "exp_title": "Mac Experience",
    "exp_trial": d("Prueba gratis: quedan {days} días · después US$10 una vez",
                   "Free trial: {days} days left · then US$10 once"),
    "exp_active": d("Activo en este Mac — tuyo para siempre ✓",
                    "Active on this Mac — yours forever ✓"),
    "exp_off": d("Apagado — tu Mac sigue igual; recupera ⌘ y Spotlight por US$10",
                 "Off — your Mac is unchanged; bring back ⌘ and Spotlight for US$10"),
    "exp_buy": d("Comprar", "Buy"),
    "exp_key": d("Tengo una clave", "I have a key"),
    "exp_key_head": d("Activar Mac Experience", "Activate Mac Experience"),
    "exp_key_body": d("Pega la clave de licencia que te llegó por correo al comprar.",
                      "Paste the license key you received by email after buying."),
    "exp_key_ph": d("Clave de licencia", "License key"),
    "exp_activate": d("Activar", "Activate"),
    "cancel": d("Cancelar", "Cancel"),
    "exp_act_okmsg": d("¡Listo! Tu teclado ⌘ y Spotlight están de vuelta.",
                       "Done! Your ⌘ keyboard and Spotlight are back."),
    "exp_act_badmsg": d("La clave no se pudo activar — revisa que esté bien copiada.",
                        "The key couldn't be activated — check it was copied correctly."),
}

CSS = b"""
.app-card { border-radius: 14px; padding: 10px 6px; }
.app-card:checked { background: alpha(@accent_bg_color, .18);
                    outline: 2px solid @accent_bg_color; outline-offset: -2px; }
.app-name { font-weight: 600; font-size: 12px; }
"""


def links():
    cfg = {}
    for path in (os.path.join(SW_STATE, "links.conf"),
                 os.path.join(SW_ROOT, "links.conf")):
        try:
            with open(path) as f:
                for line in f:
                    if "=" in line and not line.strip().startswith("#"):
                        k, v = line.strip().split("=", 1)
                        cfg.setdefault(k, v)
            break
        except FileNotFoundError:
            continue
    # Defaults AFTER parsing (a pre-seeded default would shadow the real file)
    cfg.setdefault("DONATE_URL", "https://github.com/secondwindformac/second-wind")
    cfg.setdefault("EXPERIENCE_URL", cfg.get("WEBSITE_URL",
                   "https://secondwindformac.com/"))
    return cfg


def mf(*args):
    subprocess.run(["python3", os.path.join(SW_ROOT, "lib", "manifest.py"), *args],
                   env={**os.environ, "SW_MANIFEST": os.path.join(SW_STATE, "manifest.json")},
                   check=False)


def fetch_icon(app_id, domain):
    path = os.path.join(ICONDIR, f"{app_id}.png")
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    # Several sources, in order: some domains 404 on one service but not the
    # next (VLC/GIMP did, caught in the E2E clips). GdkPixbuf sniffs content,
    # so an .ico body behind a .png name still renders. Icons are cached, and
    # deliberately NOT shipped in the repo (third-party logos stay upstream).
    for url in (f"https://www.google.com/s2/favicons?domain={domain}&sz=128",
                f"https://icons.duckduckgo.com/ip3/{domain}.ico",
                f"https://{domain}/favicon.ico"):
        subprocess.run(["curl", "-fsSL", "-m", "10", "-o", path, url], check=False)
        if os.path.exists(path) and os.path.getsize(path) > 0:
            return path
    try:
        os.remove(path)  # leave no empty cache file behind
    except FileNotFoundError:
        pass
    return None


def make_webapp(app_id, name, url, domain):
    browser = shutil.which("google-chrome") or shutil.which("google-chrome-stable")
    if not browser:
        return f"{name}: Chrome"
    icon = fetch_icon(app_id, domain) or "web-browser"
    desk = os.path.expanduser(f"~/.local/share/applications/secondwind-{app_id}.desktop")
    with open(desk, "w") as f:
        f.write(f"[Desktop Entry]\nType=Application\nName={name}\n"
                f"Exec={browser} --app={url} --class=secondwind-{app_id}\n"
                f"Icon={icon}\nStartupWMClass=secondwind-{app_id}\nCategories=Network;\n")
    mf("file-created", desk)
    return None


class Store(Adw.Application):
    def __init__(self):
        super().__init__(application_id="app.secondwind.Apps")
        self.cards = {}

    def do_activate(self):
        prov = Gtk.CssProvider()
        prov.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), prov,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.win = Adw.ApplicationWindow(application=self, title=T["title"],
                                         default_width=680, default_height=760)
        view = Adw.ToolbarView()
        view.add_top_bar(Adw.HeaderBar())

        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6,
                       margin_top=6, margin_bottom=10, margin_start=18, margin_end=18)

        for _gid, gtitle, apps in CATALOG:
            head = Gtk.Label(label=gtitle, xalign=0,
                             css_classes=["heading"], margin_top=14)
            body.append(head)
            flow = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE,
                               max_children_per_line=6, min_children_per_line=3,
                               column_spacing=6, row_spacing=6, homogeneous=True)
            for app in apps:
                flow.append(self.card(app))
            body.append(flow)

        sup = Adw.PreferencesGroup(title=T["g_support"], margin_top=18)
        self.exp_row = Adw.ActionRow(title=T["exp_title"])
        expkey = Gtk.Button(label=T["exp_key"], valign=Gtk.Align.CENTER)
        expkey.connect("clicked", self.on_exp_key)
        expbuy = Gtk.Button(label=T["exp_buy"], valign=Gtk.Align.CENTER,
                            css_classes=["suggested-action"])
        expbuy.connect("clicked", lambda *_: subprocess.Popen(
            ["xdg-open", links()["EXPERIENCE_URL"]]))
        self.exp_row.add_suffix(expkey)
        self.exp_row.add_suffix(expbuy)
        sup.add(self.exp_row)
        self.exp_refresh()
        helpr = Adw.ActionRow(title=T["help"], subtitle=T["help_sub"],
                              activatable=True)
        helpr.add_suffix(Gtk.Image.new_from_icon_name("help-browser-symbolic"))
        helpr.connect("activated", lambda *_: subprocess.Popen(
            ["xdg-open", links().get("SUPPORT_URL", links()["DONATE_URL"])]))
        sup.add(helpr)
        donate = Adw.ActionRow(title=T["donate"], subtitle=T["donate_sub"],
                               activatable=True)
        donate.add_suffix(Gtk.Image.new_from_icon_name("adw-external-link-symbolic"))
        donate.connect("activated", lambda *_:
                       subprocess.Popen(["xdg-open", links()["DONATE_URL"]]))
        sup.add(donate)
        news = Adw.SwitchRow(title=T["news"], subtitle=T["news_sub"],
                             active=not os.path.exists(
                                 os.path.join(SW_STATE, "news-optout")))
        news.connect("notify::active", self.on_news)
        sup.add(news)
        test = Adw.ActionRow(title=T["news_test"], subtitle=T["news_test_sub"],
                             activatable=True)
        test.add_suffix(Gtk.Image.new_from_icon_name("preferences-system-notifications-symbolic"))
        test.connect("activated", lambda *_: subprocess.Popen(
            ["bash", os.path.join(SW_STATE, "news", "second-wind-news.sh"), "--test"]))
        sup.add(test)
        body.append(sup)

        scroller = Gtk.ScrolledWindow(child=body, vexpand=True)

        self.status = Gtk.Label(label="", wrap=True)
        self.spinner = Gtk.Spinner(margin_end=6)
        self.blabel = Gtk.Label(label=T["install"])
        bb = Gtk.Box(spacing=6)
        bb.append(self.spinner)
        bb.append(self.blabel)
        self.button = Gtk.Button(css_classes=["suggested-action", "pill"],
                                 margin_top=4, margin_bottom=14,
                                 halign=Gtk.Align.CENTER, child=bb)
        self.button.connect("clicked", self.on_install)
        bottom = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        bottom.append(self.status)
        bottom.append(self.button)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content.append(scroller)
        content.append(bottom)
        view.set_content(content)
        self.win.set_content(view)
        self.win.present()
        self.count()
        threading.Thread(target=self.icons_worker, daemon=True).start()

    # --- Mac Experience row -------------------------------------------------
    def exp_bin(self):
        return os.path.join(SW_ROOT, "bin", "second-wind-experience")

    def exp_status(self):
        try:
            out = subprocess.run([self.exp_bin(), "status"], capture_output=True,
                                 text=True, timeout=10).stdout.strip().split()
            return (out[0], out[1] if len(out) > 1 else "")
        except Exception:
            return ("trial", "")

    def exp_refresh(self):
        st, extra = self.exp_status()
        if st == "active":
            self.exp_row.set_subtitle(T["exp_active"])
        elif st == "off":
            self.exp_row.set_subtitle(T["exp_off"])
        else:
            self.exp_row.set_subtitle(T["exp_trial"].format(days=extra or "30"))

    def on_exp_key(self, *_):
        dlg = Adw.AlertDialog(heading=T["exp_key_head"], body=T["exp_key_body"])
        entry = Adw.EntryRow(title=T["exp_key_ph"])
        box = Gtk.ListBox(css_classes=["boxed-list"])
        box.append(entry)
        dlg.set_extra_child(box)
        dlg.add_response("cancel", T["cancel"])
        dlg.add_response("act", T["exp_activate"])
        dlg.set_response_appearance("act", Adw.ResponseAppearance.SUGGESTED)
        dlg.set_default_response("act")

        def on_resp(_d, resp):
            key = entry.get_text().strip()
            if resp != "act" or not key:
                return
            def work():
                r = subprocess.run([self.exp_bin(), "activate", key],
                                   capture_output=True, text=True)
                GLib.idle_add(self.exp_done, r.returncode == 0)
            threading.Thread(target=work, daemon=True).start()

        dlg.connect("response", on_resp)
        dlg.present(self.win)

    def exp_done(self, ok_):
        self.status.set_label(T["exp_act_okmsg"] if ok_ else T["exp_act_badmsg"])
        self.exp_refresh()
        return False

    def card(self, app):
        app_id, name, kind, ref, _dom, desc, default = app
        # Something already on this machine shouldn't come pre-checked
        # (only probed for default entries, to keep startup snappy).
        if default and kind != "web" and self.installed(kind, ref, app_id):
            default = False
        img = Gtk.Image(icon_name="application-x-executable-symbolic",
                        pixel_size=44)
        label = Gtk.Label(label=name, css_classes=["app-name"],
                          ellipsize=3, max_width_chars=12)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.append(img)
        box.append(label)
        btn = Gtk.ToggleButton(child=box, css_classes=["app-card", "flat"],
                               active=default, tooltip_text=desc)
        btn.connect("toggled", lambda *_: self.count())
        self.cards[app_id] = (btn, img, app)
        return btn

    def icons_worker(self):
        for app_id, (_btn, img, app) in list(self.cards.items()):
            path = fetch_icon(app_id, app[4])
            if path:
                GLib.idle_add(img.set_from_file, path)

    def count(self):
        n = sum(1 for b, _i, _a in self.cards.values() if b.get_active())
        self.blabel.set_label(f"{T['install']} ({n})")

    def on_news(self, row, _p):
        flag = os.path.join(SW_STATE, "news-optout")
        if row.get_active():
            try:
                os.remove(flag)
            except FileNotFoundError:
                pass
        else:
            open(flag, "w").close()

    def on_install(self, _b):
        sel = [a for (b, _i, a) in self.cards.values() if b.get_active()]
        if not sel:
            self.status.set_label(T["nothing"])
            return
        self.button.set_sensitive(False)
        self.spinner.start()
        self.status.set_label(T["installing"])
        threading.Thread(target=self.worker, args=(sel,), daemon=True).start()

    # deb entries download by URL, so their dpkg names live here.
    DEB_PKGS = {"chrome": "google-chrome-stable", "zoom": "zoom", "discord": "discord"}

    def installed(self, kind, ref, app_id=None):
        if kind == "apt":
            return not subprocess.run(["dpkg", "-s", ref],
                                      capture_output=True).returncode
        if kind in ("snap", "snap_classic"):
            return not subprocess.run(["snap", "list", ref],
                                      capture_output=True).returncode
        if kind == "deb" and app_id in self.DEB_PKGS:
            return not subprocess.run(["dpkg", "-s", self.DEB_PKGS[app_id]],
                                      capture_output=True).returncode
        return False

    def worker(self, sel):
        fails = []
        apt, snaps, debs = [], [], []
        for app_id, name, kind, ref, domain, _desc, _def in sel:
            if kind == "web":
                err = make_webapp(app_id, name, ref, domain)
                if err:
                    fails.append(err)
            elif self.installed(kind, ref, app_id):
                continue
            elif kind == "apt":
                apt.append(ref)
            elif kind in ("snap", "snap_classic"):
                snaps.append((ref, kind == "snap_classic"))
            elif kind == "deb":
                dest = os.path.join(SW_STATE, "cache", f"{app_id}.deb")
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                if subprocess.run(["curl", "-fsSL", "-o", dest, ref]).returncode:
                    fails.append(f"{name} (download)")
                else:
                    debs.append((app_id, dest))

        if apt or snaps or debs:
            cmd = "set -e; export DEBIAN_FRONTEND=noninteractive; apt-get update -qq || true"
            if apt:
                cmd += "; apt-get install -y " + " ".join(apt)
            for ref, classic in snaps:
                cmd += f"; snap install {ref}" + (" --classic" if classic else "")
            for _aid, path in debs:
                cmd += f"; apt-get install -y '{path}'"
            with open(os.path.join(LOGDIR, "apps-gui.log"), "a") as log:
                rc = subprocess.run(["pkexec", "bash", "-c", cmd],
                                    stdout=log, stderr=log).returncode
            if rc != 0:
                fails.append("pkexec")
            else:
                for ref, _c in snaps:
                    mf("note", f"app-{ref}")
                for aid, _p in debs:
                    mf("note", f"app-{aid}")

        GLib.idle_add(self.finish, fails)

    def finish(self, fails):
        self.spinner.stop()
        self.button.set_sensitive(True)
        self.status.set_label(T["done_warn"] if fails else T["done_ok"])
        return False


if __name__ == "__main__":
    sys.exit(Store().run(None))
