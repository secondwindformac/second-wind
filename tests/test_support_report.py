#!/usr/bin/env python3
"""Tests for lib/support_report.py ("Copy report for support").

Every simulated output hides TRAP values (user, full name, host, WiFi network
name and BSSID, MAC/IP addresses, serial number, paths, app names, free log
text). The report must never contain any of them. Run:

    python3 tests/test_support_report.py
"""
import json
import os
import sys
import time
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "lib"))
import support_report as sr  # noqa: E402

NOW = 1_790_000_000.0
DAY = 86400

TRAPS = {
    "user": "trampausuario",
    "fullname": "Juana Trampalina",
    "host": "equipo-trampa",
    "ssid": "RedTrampa-5G",
    "bssid": "AA:BB:CC:DD:EE:FF",
    "mac": "de:ad:be:ef:00:01",
    "ipv4": "192.168.77.77",
    "ipv6": "fe80::1234:5678:9abc:def0",
    "serial": "C02TRAMPA1XY",
    "path": "/home/trampausuario/Documentos/secreto.txt",
    "app": "SpotifyTrampa",
    "logtext": "TEXTO-LIBRE-TRAMPA",
}

MACS_JSON = json.dumps({"models": [
    {"name": "MacBook Air (13-inch, Mid 2013)", "year": 2013, "identifiers": ["MacBookAir6,2"],
     "a_numbers": ["A1466"]},
    {"name": "MacBook Air (13-inch, Early 2014)", "year": 2014, "identifiers": ["MacBookAir6,2"],
     "a_numbers": ["A1466"]},
]})

NM_LOG = "\n".join([
    f"<info> device (wlp3s0): Activation: starting connection '{TRAPS['ssid']}' ({TRAPS['bssid']})",
    f"<info> dhcp4 (wlp3s0): address {TRAPS['ipv4']}  {TRAPS['ipv6']}",
    "<info> device (wlp3s0): state change: activated -> deactivating (reason 'sleeping', sys-iface-state: 'managed')",
    "<info> device (wlp3s0): state change: activated -> deactivating (reason 'unmanaged', sys-iface-state: 'managed')",
    "<info> device (wlp3s0): state change: activated -> disconnected (reason 'supplicant-disconnect', sys-iface-state: 'managed')",
    "<info> device (wlp3s0): state change: activated -> failed (reason 'ssid-not-found', sys-iface-state: 'managed')",
    "<info> device (wlp3s0): state change: activated -> deactivating (reason 'user-requested', sys-iface-state: 'managed')",
    f"<info> device (enx{TRAPS['mac'].replace(':', '')}): state change: activated -> disconnected (reason 'carrier-changed')",
])
KERNEL_LOG = "\n".join([
    f"{TRAPS['app']} invoked oom-killer: gfp_mask=0x140cca",
    f"oom-kill:constraint=CONSTRAINT_NONE,task={TRAPS['app']},pid=4242,uid=1000",
    f"Out of memory: Killed process 4242 ({TRAPS['app']}) total-vm:9000kB",
    f"wlp3s0: {TRAPS['logtext']} {TRAPS['path']} serial {TRAPS['serial']}",
])
OOMD_LOG = f"Killed /user.slice/user-1000.slice/app-{TRAPS['app']}.scope due to memory pressure"


class FakeSource(sr.Source):
    def __init__(self, journal=True):
        self.journal = journal
        self.files = {
            "/sys/class/dmi/id/product_name": "MacBookAir6,2\n",
            "/sys/class/dmi/id/product_serial": TRAPS["serial"],
            os.path.join(ROOT, "data", "macs.json"): MACS_JSON,
            os.path.join(ROOT, "VERSION"): "0.9.5\n",
            "/etc/os-release": f'PRETTY_NAME="Ubuntu 24.04.4 LTS"\nVERSION="24.04.4 LTS (Noble Numbat)"\n'
                               f'HOME_URL="http://{TRAPS["ipv4"]}/{TRAPS["user"]}"\n',
            "/proc/meminfo": "MemTotal:        8069864 kB\nMemFree:  100 kB\nMemAvailable:    3474624 kB\n",
            "/proc/modules": "wl 6488064 0 - Live 0x0000000000000000 (POE)\nfacetimehd 1 0 - Live 0x0\n",
            "/sys/class/power_supply/BAT0/charge_full": "6209000\n",
            "/sys/class/power_supply/BAT0/charge_full_design": "7000000\n",
            "/sys/class/power_supply/BAT0/cycle_count": "14\n",
            "/sys/class/power_supply/BAT0/serial_number": TRAPS["serial"],
            "/sys/bus/pci/devices/0000:03:00.0/class": "0x028000\n",
            "/sys/bus/pci/devices/0000:03:00.0/vendor": "0x14e4\n",
            "/sys/bus/pci/devices/0000:03:00.0/device": "0x43a0\n",
            "/sys/bus/pci/devices/0000:00:02.0/class": "0x030000\n",
        }
        self.dirs = {
            "/sys/class/power_supply": ["AC", "BAT0"],
            "/sys/bus/pci/devices": ["0000:00:02.0", "0000:03:00.0"],
        }

    def read(self, path):
        return self.files.get(path)

    def listdir(self, path):
        return self.dirs.get(path, [])

    def now(self):
        return NOW

    def private_words(self):
        return {TRAPS["user"], *TRAPS["fullname"].split(), TRAPS["host"], TRAPS["ssid"]}

    def run(self, cmd, timeout=6):
        c = " ".join(cmd)
        if cmd[0] == "df":
            return f"Filesystem 1B-blocks {TRAPS['path']}\n  244811706368 206968172544\n"
        if cmd[0] == "bash" and cmd[-1] == "--json":
            return json.dumps({"identifier": "MacBookAir6,2", "name": TRAPS["fullname"],
                               "a_numbers": "A1466", "wifi": "ok", "sound": "ok",
                               "camera": "pending", "keyboard_trackpad": "ok",
                               "bluetooth": "missing", "battery": "ok",
                               "ssid": TRAPS["ssid"]})
        if cmd[0] != "journalctl" or not self.journal:
            return None
        if "--list-boots" in cmd:
            us = lambda t: int(t * 1e6)
            return json.dumps([
                {"index": -3, "boot_id": "x", "first_entry": us(NOW - 20 * DAY), "last_entry": us(NOW - 19 * DAY)},
                {"index": -2, "boot_id": "y", "first_entry": us(NOW - 5 * DAY), "last_entry": us(NOW - 4 * DAY)},
                {"index": -1, "boot_id": "z", "first_entry": us(NOW - 3 * DAY), "last_entry": us(NOW - 2 * DAY)},
                {"index": 0, "boot_id": "w", "first_entry": us(NOW - DAY), "last_entry": us(NOW)},
            ])
        if "-b" in cmd:
            idx = cmd[cmd.index("-b") + 1]
            # -2 ended cleanly; -1 just stopped (power cut) with trap text in its tail.
            return ("...\nReached target reboot.target - System Reboot.\n" if idx == "-2"
                    else f"{TRAPS['logtext']} {TRAPS['host']} {TRAPS['path']}\n")
        if "-k" in cmd:
            return KERNEL_LOG
        if "systemd-oomd" in c:
            return OOMD_LOG
        if "NetworkManager" in c:
            return NM_LOG
        return ""


class SupportReportTest(unittest.TestCase):
    def build(self, lang="es", **kw):
        return sr.build(src=FakeSource(**kw), sw_root=ROOT, lang=lang)

    def assert_no_traps(self, text):
        for name, value in TRAPS.items():
            for part in {value, *value.split()}:
                self.assertNotIn(part.lower(), text.lower(), f"trap '{name}' leaked: {part}")

    def test_no_forbidden_data_es_and_en(self):
        for lang in ("es_CL.UTF-8", "en_US.UTF-8"):
            text, problems = self.build(lang=lang)
            self.assertEqual(problems, [], text)
            self.assert_no_traps(text)
            for bad in ("wlp3s0", "enx", "Documentos", "/", "@", "http"):
                self.assertNotIn(bad, text)

    def test_contents_es(self):
        text, _ = self.build()
        self.assertIn("MacBook Air (13-inch, Early 2014) o MacBook Air (13-inch, Mid 2013)", text)
        self.assertIn("Número de modelo: A1466 · Identificador: MacBookAir6,2 · Año: 2013-2014", text)
        self.assertIn("Second Wind: 0.9.5", text)
        self.assertIn("Ubuntu: 24.04.4 LTS", text)
        self.assertIn("Memoria: 7,7 GB en total · 4,4 GB en uso (57 %)", text)
        self.assertIn("Disco: 228 GB en total · 85 % libre", text)
        self.assertIn("Batería: salud 89 % · 14 ciclos", text)
        self.assertIn("WiFi: driver cargado · chip 14e4:43a0", text)
        self.assertIn("Cámara … · Teclado y trackpad ✔ · Bluetooth ✖", text)

    def test_counts_last_7_days(self):
        # crashes: -1 (no shutdown mark); -2 clean; -3 older than 7 days; 0 running.
        # oom: 1 kernel kill (3 lines) + 1 oomd kill = 2.
        # wifi: supplicant-disconnect + ssid-not-found = 2 (sleeping, unmanaged,
        # user-requested and the wired enx device do not count).
        text, _ = self.build()
        self.assertIn("Últimos 7 días: 1 cierres inesperados · 2 veces sin memoria · "
                      "2 desconexiones de WiFi", text)

    def test_journal_not_readable(self):
        text, problems = self.build(journal=False)
        self.assertEqual(problems, [])
        self.assertIn("? cierres inesperados (no disponible)", text)
        self.assertIn("? desconexiones de WiFi (no disponible)", text)

    def test_guard_catches_leaks(self):
        clean = sr.render(sr.collect(FakeSource(), ROOT), "es")
        for leak in (TRAPS["ipv4"], TRAPS["ipv6"], TRAPS["mac"], TRAPS["bssid"], TRAPS["path"],
                     "~/Descargas", "soporte@ejemplo.com", TRAPS["serial"]):
            self.assertTrue(sr.find_forbidden(clean + leak + "\n"), f"guard missed: {leak}")
        for word in (TRAPS["user"], TRAPS["host"], TRAPS["ssid"], "Trampalina"):
            self.assertTrue(sr.find_forbidden(clean + f"x {word} y\n", {word}),
                            f"guard missed private word: {word}")

    def test_guard_ignores_fixed_vocabulary(self):
        # The Air's account full name is literally "Second Wind" (installer).
        text, _ = self.build()
        self.assertEqual(sr.find_forbidden(text, {"Second", "Wind", "wind", "second-wind"}), [])

    def test_hostile_catalogue_values_are_dropped(self):
        src = FakeSource()
        src.files[os.path.join(ROOT, "data", "macs.json")] = json.dumps({"models": [
            {"name": f"Mac {TRAPS['path']}", "year": 2013, "identifiers": ["MacBookAir6,2"],
             "a_numbers": [TRAPS["serial"]]}]})
        src.files[os.path.join(ROOT, "VERSION")] = TRAPS["ipv4"]
        text, problems = sr.build(src=src, sw_root=ROOT, lang="es")
        self.assertEqual(problems, [])
        self.assert_no_traps(text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
