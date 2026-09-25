#!/usr/bin/env python3
"""Second Wind — the product's own app (shown as "Second Wind"; internally
still app.secondwind.Apps so existing installs keep their dock icon): app
store v3: a compact visual grid of popular apps.

~21 curated apps as icon cards with checkboxes, grouped by what people do.
Icons are fetched at runtime (official app icons via Flathub, site icons for
web apps), so no trademarked artwork ships in this repository. They are
prefetched during setup (module 70) and retried while the window is open;
offline, a card shows a colored initial instead of a generic gear. One system password
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

if __name__ == "__main__" and "--prefetch-icons" in sys.argv:
    PREFETCH = True
else:
    PREFETCH = False

try:
    if PREFETCH:
        raise ImportError  # no GTK needed (nor wanted) to warm the icon cache
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402
except Exception:
    if not PREFETCH:
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

# Where each card's icon comes from, best first; the favicon services for the
# catalog domain are always the last resort. "flathub:<id>" = the app's
# official 128px icon, resolved through Flathub's appstream API (the media URL
# carries a hash, so it is never hardcoded). "theme:<name>" = a local icon that
# works offline. Plain URLs are fetched as-is. (Favicons alone were blurry:
# WhatsApp came back 23px, and the Air got none at all while offline.)
ICON_SRC = {
    "chrome": ["flathub:com.google.Chrome"],
    "quicklook": ["theme:org.gnome.Nautilus"],
    "vlc": ["flathub:org.videolan.VLC"],
    "transmission": ["flathub:com.transmissionbt.Transmission"],
    "gimp": ["flathub:org.gimp.GIMP"],
    "spotify": ["flathub:com.spotify.Client"],
    "audacity": ["flathub:org.audacityteam.Audacity"],
    "obs": ["flathub:com.obsproject.Studio"],
    "kdenlive": ["flathub:org.kde.kdenlive"],
    "steam": ["flathub:com.valvesoftware.Steam"],
    "zoom": ["flathub:us.zoom.Zoom"],
    "telegram": ["flathub:org.telegram.desktop"],
    "discord": ["flathub:com.discordapp.Discord"],
    "slack": ["flathub:com.slack.Slack"],
    "onlyoffice": ["flathub:org.onlyoffice.desktopeditors"],
    "blender": ["flathub:org.blender.Blender"],
    "whatsapp": ["https://web.whatsapp.com/apple-touch-icon.png"],
    "claude": ["https://claude.ai/apple-touch-icon.png"],
}

T = {
    # Shown as "Second Wind": apps are one part of it (CEO, 24-Sep).
    "title": "Second Wind",
    "install": d("Instalar", "Install"),
    "installing": d("Instalando… (contraseña en ventana del sistema)",
                    "Installing… (password in a system window)"),
    "done_ok": d("¡Listo! Encuentra tus apps con Cmd+Espacio.",
                 "Done! Find your apps with Cmd+Space."),
    "done_warn": d("Terminado con avisos — detalle en apps-gui.log",
                   "Finished with warnings — details in apps-gui.log"),
    "nothing": d("Marca al menos una app.", "Tick at least one app."),
    "g_support": d("El proyecto", "The project"),
    "more": d("Más opciones", "More options"),
    "mymac": d("Tu Mac…", "Your Mac…"),
    "about": d("Acerca de Second Wind", "About Second Wind"),
    "about_sub": d("Una segunda vida para tu Mac.", "A second life for your Mac."),
    "contact": d("Escribirnos", "Contact us"),
    "exp_pill_trial": d("Mac Experience · {days} días", "Mac Experience · {days} days"),
    "exp_pill_active": d("Mac Experience ✓", "Mac Experience ✓"),
    "donate": d("Apoyar Second Wind", "Support Second Wind"),
    "donate_sub": d("Donaciones y novedades", "Donations and news"),
    "news": d("Avisos de novedades y apoyo", "News and support notices"),
    "news_sub": d("Una notificación ocasional; apágalo cuando quieras",
                  "An occasional notification; turn off anytime"),
    "upd": d("Buscar actualizaciones", "Check for updates"),
    "upd_sub": d("Versión instalada: {v}. Te avisamos con una notificación.",
                 "Installed version: {v}. We'll tell you with a notification."),
    "news_test": d("Probar el aviso ahora", "Try the notice now"),
    "news_test_sub": d("Muestra la notificación de ejemplo", "Shows the sample notification"),
    "help": d("Obtener ayuda", "Get help"),
    "help_sub": d("Guía, preguntas frecuentes y reporte de problemas",
                  "Guide, FAQ and problem reports"),
    "exp_title": "Mac Experience",
    "exp_trial": d("Prueba gratis: quedan {days} días · después US$10 una vez",
                   "Free trial: {days} days left · then US$10 once"),
    "exp_trial_1": d("Prueba gratis: queda 1 día · después US$10 una vez",
                     "Free trial: 1 day left · then US$10 once"),
    "exp_pill_trial_1": d("Mac Experience · 1 día", "Mac Experience · 1 day"),
    "exp_active": d("Activo en este Mac — tuyo para siempre ✓",
                    "Active on this Mac — yours forever ✓"),
    "exp_off": d("Apagado — tu Mac sigue igual; recupera ⌘ y Spotlight por US$10",
                 "Off — your Mac is unchanged; bring back ⌘ and Spotlight for US$10"),
    "exp_buy": d("Comprar", "Buy"),
    "exp_key": d("Tengo una clave", "I have a key"),
    "exp_key_head": d("Activar Mac Experience", "Activate Mac Experience"),
    "exp_key_body": d("Pega la clave de licencia que te llegó por correo al comprar.",
                      "Paste the license key you received by email after buying."),
    "exp_key_body_buy": d("Se abrió la página de pago en tu navegador. Cuando termines, te llegará "
                          "un correo de Lemon Squeezy con tu clave de licencia: cópiala y pégala aquí.",
                          "The payment page opened in your browser. When you finish, Lemon Squeezy "
                          "e-mails you your license key: copy it and paste it here."),
    "exp_key_ph": d("Clave de licencia", "License key"),
    "exp_activate": d("Activar", "Activate"),
    "cancel": d("Cancelar", "Cancel"),
    "exp_act_okmsg": d("¡Listo! Tu teclado ⌘ y Spotlight están de vuelta.",
                       "Done! Your ⌘ keyboard and Spotlight are back."),
    "exp_act_badmsg": d("La clave no se pudo activar — revisa que esté bien copiada.",
                        "The key couldn't be activated — check it was copied correctly."),
}

CSS = b"""
headerbar menubutton.exp-pill > button {
  border-radius: 999px; padding: 2px 12px; box-shadow: none;
  background: alpha(@accent_bg_color, .14); color: @accent_color; font-weight: 600; }
headerbar menubutton.exp-pill > button:hover { background: alpha(@accent_bg_color, .24); }
headerbar menubutton.exp-pill > button:checked { background: alpha(@accent_bg_color, .30); }
.app-card { border-radius: 14px; padding: 10px 6px; }
.app-card:checked { background: alpha(@accent_bg_color, .18);
                    outline: 2px solid @accent_bg_color; outline-offset: -2px; }
.app-name { font-weight: 600; font-size: 12px; }
.mono { border-radius: 11px; color: white; font-weight: 800; font-size: 22px; }
.mono-0 { background: #2563EB; } .mono-1 { background: #0D9488; }
.mono-2 { background: #EA580C; } .mono-3 { background: #7C3AED; }
.mono-4 { background: #DB2777; } .mono-5 { background: #059669; }
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
    cfg.setdefault("WEBSITE_URL", "https://secondwindformac.com/")
    cfg.setdefault("WEBSITE_URL_ES", "https://secondwindformac.com/es/")
    cfg.setdefault("HELP_URL", cfg["WEBSITE_URL"] + "#faq")
    cfg.setdefault("HELP_URL_ES", cfg["WEBSITE_URL_ES"] + "#faq")
    cfg.setdefault("CONTACT_EMAIL", "hello@secondwindformac.com")
    cfg.setdefault("DONATE_URL", cfg["WEBSITE_URL"])
    # Everything a person clicks goes to our site or a human, never GitHub
    # (CEO, 24-Sep). Language-aware where the site has both.
    cfg["HELP"] = cfg["HELP_URL_ES"] if ES else cfg["HELP_URL"]
    cfg["SITE"] = cfg["WEBSITE_URL_ES"] if ES else cfg["WEBSITE_URL"]
    cfg.setdefault("EXPERIENCE_URL", cfg.get("WEBSITE_URL",
                   "https://secondwindformac.com/"))
    return cfg


def mf(*args):
    subprocess.run(["python3", os.path.join(SW_ROOT, "lib", "manifest.py"), *args],
                   env={**os.environ, "SW_MANIFEST": os.path.join(SW_STATE, "manifest.json")},
                   check=False)


IMG_MAGIC = (b"\x89PNG", b"\xff\xd8\xff", b"GIF8", b"\x00\x00\x01\x00", b"RIFF")


def is_image(path):
    # Some sites answer a missing favicon with an HTML page and status 200
    # (office.com did); caching that showed a broken card forever.
    try:
        with open(path, "rb") as f:
            head = f.read(256)
    except OSError:
        return False
    return head.startswith(IMG_MAGIC) or (b"<svg" in head and b"<html" not in head.lower())


def icon_log(msg):
    with open(os.path.join(LOGDIR, "apps-icons.log"), "a") as f:
        f.write(msg + "\n")


def flathub_icon_url(fid):
    r = subprocess.run(["curl", "-fsL", "-m", "10",
                        f"https://flathub.org/api/v2/appstream/{fid}"],
                       capture_output=True, text=True, check=False)
    try:
        import json
        return json.loads(r.stdout).get("icon") if r.returncode == 0 else None
    except ValueError:
        return None


def fetch_icon(app_id, domain):
    # "-v2" retires caches from the favicon-only era (low-res, sometimes HTML)
    path = os.path.join(ICONDIR, f"{app_id}-v2.png")
    if os.path.exists(path) and is_image(path):
        return path
    urls = []
    for src in ICON_SRC.get(app_id, []):
        if src.startswith("theme:"):
            continue  # resolved locally by the window, nothing to download
        if src.startswith("flathub:"):
            src = flathub_icon_url(src[len("flathub:"):])
        if src:
            urls.append(src)
    # Fallbacks, in order: some domains 404 on one service but not the next
    # (VLC/GIMP did, caught in the E2E clips). GdkPixbuf sniffs content, so an
    # .ico body behind a .png name still renders. Deliberately NOT shipped in
    # the repo (third-party logos stay upstream).
    urls += [f"https://www.google.com/s2/favicons?domain={domain}&sz=128",
             f"https://icons.duckduckgo.com/ip3/{domain}.ico",
             f"https://{domain}/favicon.ico"]
    tmp = path + ".part"
    for url in urls:
        subprocess.run(["curl", "-fsL", "-m", "10", "-A", "Mozilla/5.0",
                        "-o", tmp, url], check=False)
        if is_image(tmp):
            os.replace(tmp, path)
            return path
    try:
        os.remove(tmp)  # leave no half/HTML file behind
    except FileNotFoundError:
        pass
    icon_log(f"{app_id}: no icon (offline or all sources failed)")
    return None


def prefetch_icons():
    got = 0
    for _gid, _title, apps in CATALOG:
        for app in apps:
            if any(x.startswith("theme:") for x in ICON_SRC.get(app[0], [])) \
                    or fetch_icon(app[0], app[4]):
                got += 1
    total = sum(len(a) for _g, _t, a in CATALOG)
    print(f"icons: {got}/{total}")
    return 0


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


if PREFETCH:
    sys.exit(prefetch_icons())  # before Store: Adw isn't imported in this mode


class Store(Adw.Application):
    def __init__(self):
        super().__init__(application_id="app.secondwind.Apps")
        self.cards = {}
        self.stacks = {}

    def do_activate(self):
        prov = Gtk.CssProvider()
        prov.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), prov,
            # Above USER: the MacTahoe theme is linked into ~/.config/gtk-4.0
            # (user priority) and would repaint our own classes (the pill came
            # out plain white). Our CSS only targets the store's own classes.
            Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)

        self.win = Adw.ApplicationWindow(application=self, title=T["title"],
                                         default_width=680, default_height=760)
        view = Adw.ToolbarView()
        view.add_top_bar(self.header())

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

    # --- Header: title (left) · Mac Experience pill + "⋯" menu (right) ------
    # CEO review on the Air (24-Sep): the project options (updates, help,
    # Mac Experience, notices) sat under the whole catalog and were never
    # found; a block of them on top was too heavy. Mac apps put them in the
    # title bar: one discreet pill that sells, one ⋯ menu for the rest.
    def version(self):
        try:
            with open(os.path.join(SW_ROOT, "VERSION")) as f:
                return f.read().strip()
        except OSError:
            return "?"

    def header(self):
        hb = Adw.HeaderBar(show_title=False)
        # Title on the left, next to the window buttons (CEO, 24-Sep).
        hb.pack_start(Gtk.Label(label=T["title"], css_classes=["heading"],
                                margin_start=6))

        # Mac Experience: status at a glance, a popover to buy or activate.
        pop = Gtk.Popover()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8,
                      margin_top=12, margin_bottom=12, margin_start=14, margin_end=14,
                      width_request=280)
        box.append(Gtk.Label(label=T["exp_title"], xalign=0, css_classes=["title-4"]))
        self.exp_lbl = Gtk.Label(xalign=0, wrap=True, max_width_chars=34,
                                 css_classes=["dim-label"])
        box.append(self.exp_lbl)
        self.exp_btns = Gtk.Box(spacing=8, margin_top=4, homogeneous=True)
        key = Gtk.Button(label=T["exp_key"])
        key.connect("clicked", lambda *_: (pop.popdown(), self.on_exp_key()))
        buy = Gtk.Button(label=T["exp_buy"], css_classes=["suggested-action"])
        # Buy = checkout + the key box right away, saying where the key comes
        # from: after paying, nobody told the CEO where it goes (Air, 24-Sep).
        buy.connect("clicked", lambda *_: (pop.popdown(), subprocess.Popen(
            ["xdg-open", links()["EXPERIENCE_URL"]]), self.on_exp_key(after_buy=True)))
        self.exp_btns.append(key)
        self.exp_btns.append(buy)
        box.append(self.exp_btns)
        pop.set_child(box)
        self.exp_pill = Gtk.MenuButton(popover=pop, css_classes=["exp-pill"],
                                       tooltip_text=T["exp_title"])
        self.exp_refresh()

        # Everything else, one click away and out of the catalog's way.
        actions = {
            # "Your Mac" (component check + "Copy report for support") used to
            # open only once, after the first boot; now always one click away.
            "mymac": lambda *_: subprocess.Popen(
                ["bash", os.path.join(SW_ROOT, "bin", "second-wind-mymac"), "--gui"],
                env={**os.environ, "SW_ROOT": SW_ROOT}),
            "check-updates": lambda *_: subprocess.Popen(
                ["bash", os.path.join(SW_ROOT, "bin", "second-wind-update"), "--manual"]),
            "help": lambda *_: subprocess.Popen(["xdg-open", links()["HELP"]]),
            "contact": lambda *_: subprocess.Popen(
                ["xdg-open", "mailto:" + links()["CONTACT_EMAIL"]]),
            "donate": lambda *_: subprocess.Popen(["xdg-open", links()["DONATE_URL"]]),
            "news-test": lambda *_: subprocess.Popen(
                ["bash", os.path.join(SW_STATE, "news", "second-wind-news.sh"), "--test"]),
            "about": self.on_about,
        }
        for name, cb in actions.items():
            act = Gio.SimpleAction.new(name, None)
            act.connect("activate", cb)
            self.add_action(act)
        news = Gio.SimpleAction.new_stateful(
            "news", None, GLib.Variant.new_boolean(
                not os.path.exists(os.path.join(SW_STATE, "news-optout"))))
        news.connect("change-state", self.on_news)
        self.add_action(news)

        menu = Gio.Menu()
        for items in ([(T["mymac"], "app.mymac"), (T["upd"], "app.check-updates")],
                      [(T["help"], "app.help"), (T["contact"], "app.contact"),
                       (T["donate"], "app.donate")],
                      [(T["news"], "app.news"), (T["news_test"], "app.news-test")],
                      [(T["about"], "app.about")]):
            sec = Gio.Menu()
            for label, action in items:
                sec.append(label, action)
            menu.append_section(None, sec)
        more = Gtk.MenuButton(icon_name="view-more-symbolic", menu_model=menu,
                              tooltip_text=T["more"])
        hb.pack_end(more)
        hb.pack_end(self.exp_pill)   # just left of ⋯ (pack_end goes right-to-left)
        return hb

    def on_about(self, *_):
        # The app icon ships as a file (~/.local/share/second-wind), not in an
        # icon theme: let the About dialog find it by name.
        Gtk.IconTheme.get_for_display(Gdk.Display.get_default()).add_search_path(
            os.path.expanduser("~/.local/share/second-wind"))
        about = Adw.AboutDialog(application_name=T["title"],
                                application_icon="second-wind-apps",
                                developer_name="Second Wind",
                                version=self.version(),
                                comments=T["about_sub"],
                                # Our site and a human contact — no GitHub
                                # anywhere a person clicks (CEO, 24-Sep).
                                website=links()["SITE"],
                                support_url="mailto:" + links()["CONTACT_EMAIL"])
        about.present(self.win)

    # --- Mac Experience state -----------------------------------------------
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
            self.exp_pill.set_label(T["exp_pill_active"])
            self.exp_lbl.set_label(T["exp_active"])
            self.exp_btns.set_visible(False)
        elif st == "off":
            self.exp_pill.set_label(T["exp_title"])
            self.exp_lbl.set_label(T["exp_off"])
            self.exp_btns.set_visible(True)
        else:
            days = extra or "30"
            one = days == "1"   # "1 day", not "1 days" (Air, 24-Sep)
            self.exp_pill.set_label(T["exp_pill_trial_1" if one else "exp_pill_trial"].format(days=days))
            self.exp_lbl.set_label(T["exp_trial_1" if one else "exp_trial"].format(days=days))
            self.exp_btns.set_visible(True)

    def on_exp_key(self, *_, after_buy=False):
        dlg = Adw.AlertDialog(heading=T["exp_key_head"],
                              body=T["exp_key_body_buy"] if after_buy else T["exp_key_body"])
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
        if default and self.installed(kind, ref, app_id):
            default = False
        # Until (or unless) the real icon arrives: a colored initial, never a
        # generic gear — a grid of gears reads as "broken" (Air, 23-Sep).
        mono = Gtk.Label(label=name[:1].upper(), css_classes=[
            "mono", f"mono-{sum(map(ord, app_id)) % 6}"], halign=Gtk.Align.CENTER)
        mono.set_size_request(44, 44)
        img = Gtk.Image(pixel_size=44)
        stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE)
        stack.add_named(mono, "mono")
        stack.add_named(img, "img")
        theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default())
        for src in ICON_SRC.get(app_id, []):
            if src.startswith("theme:") and theme.has_icon(src[6:]):
                img.set_from_icon_name(src[6:])
                stack.set_visible_child_name("img")
        label = Gtk.Label(label=name, css_classes=["app-name"],
                          ellipsize=3, max_width_chars=12)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.append(stack)
        box.append(label)
        btn = Gtk.ToggleButton(child=box, css_classes=["app-card", "flat"],
                               active=default, tooltip_text=desc)
        btn.connect("toggled", lambda *_: self.count())
        self.cards[app_id] = (btn, img, app)
        self.stacks[app_id] = stack
        return btn

    def show_icon(self, app_id, path):
        self.cards[app_id][1].set_from_file(path)
        self.stacks[app_id].set_visible_child_name("img")
        return False

    def icons_worker(self):
        # The window may open before the network is up (first login, WiFi
        # still joining), so keep retrying the missing ones for ~10 minutes.
        import time
        todo = [a for a, s in self.stacks.items() if s.get_visible_child_name() == "mono"]
        for wait in (0, 5, 10, 20, 30, 60, 60, 120, 120, 180):
            time.sleep(wait)
            for app_id in list(todo):
                path = fetch_icon(app_id, self.cards[app_id][2][4])
                if path:
                    GLib.idle_add(self.show_icon, app_id, path)
                    todo.remove(app_id)
            if not todo:
                return

    def count(self):
        n = sum(1 for b, _i, _a in self.cards.values() if b.get_active())
        self.blabel.set_label(f"{T['install']} ({n})")

    def on_news(self, action, value):
        action.set_state(value)
        flag = os.path.join(SW_STATE, "news-optout")
        if value.get_boolean():
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
        if kind == "web":   # a web app is its launcher (Air: WhatsApp came pre-checked again)
            return os.path.exists(os.path.expanduser(
                f"~/.local/share/applications/secondwind-{app_id}.desktop"))
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

        # Just-installed apps (e.g. Chrome, WhatsApp) get the Mac window
        # buttons right away, not only at the next login.
        subprocess.run([os.path.join(SW_ROOT, "bin", "second-wind-titlebars"), "--quiet"])
        GLib.idle_add(self.finish, fails)

    def finish(self, fails):
        self.spinner.stop()
        self.button.set_sensitive(True)
        self.status.set_label(T["done_warn"] if fails else T["done_ok"])
        return False


if __name__ == "__main__":
    sys.exit(Store().run(None))
