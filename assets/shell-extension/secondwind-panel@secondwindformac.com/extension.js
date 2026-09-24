// Second Wind Panel: the top bar details that make it read like a Mac's,
// done in one small extension we own (no third-party code to pin):
//   1. the clock moves from the center to the right edge, "Wed 23 Sep 14:24"
//   2. the active app's name, in bold, right after the ⌘ menu
//   3. a search (magnifier) button that opens Ulauncher, like Spotlight
//   4. notification banners in the top-right corner instead of top-center
//   5. Control Center: "Display" / "Sound" titles over the two sliders
//   6. the ⌘ (Logo Menu) drop-down flush under the icon, not 34 px to the right
// Everything is undone in disable(), so turning it off restores stock GNOME.
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const SEARCH_CMD = ['ulauncher-toggle'];

export default class SecondWindPanel extends Extension {
    enable() {
        const panel = Main.panel;

        // 1. Clock: to the right edge, custom format.
        this._dateMenu = panel.statusArea.dateMenu;
        this._dateParent = this._dateMenu.container.get_parent();
        this._dateParent.remove_child(this._dateMenu.container);
        panel._rightBox.add_child(this._dateMenu.container);
        this._clockLabel = this._dateMenu._clockDisplay;
        this._wallClock = this._dateMenu._clock;
        this._clockId = this._wallClock.connect('notify::clock', () => this._syncClock());
        this._syncClock();

        // 2. Active app name after the left-most item (the ⌘ menu).
        this._appLabel = new St.Label({
            style_class: 'sw-app-name',
            style: 'font-weight: bold; padding: 0 10px;',
            y_align: Clutter.ActorAlign.CENTER,
        });
        panel._leftBox.add_child(this._appLabel);
        this._tracker = Shell.WindowTracker.get_default();
        this._focusId = global.display.connect('notify::focus-window', () => this._syncApp());
        this._syncApp();

        // 3. Search button, just left of the system indicators.
        this._search = new PanelMenu.Button(0.0, 'Second Wind Search', true);
        this._search.add_child(new St.Icon({
            icon_name: 'system-search-symbolic',
            style_class: 'system-status-icon',
        }));
        this._search.connect('button-press-event', () => {
            this._spawnSearch();
            return Clutter.EVENT_STOP;
        });
        panel.addToStatusArea('secondwind-search', this._search, 0, 'right');

        // 4. Notification banners top-right.
        this._bannerBin = Main.messageTray._bannerBin;
        this._bannerAlign = this._bannerBin.x_align;
        this._bannerBin.x_align = Clutter.ActorAlign.END;

        // 5 + 6 act on actors other code creates later (quick settings builds
        // its sliders asynchronously; Logo Menu is another extension), so
        // retry for a few seconds and re-check when extensions change.
        this._titled = [];
        this._tries = 0;
        this._retryId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            this._syncLate();
            return ++this._tries < 20 ? GLib.SOURCE_CONTINUE : GLib.SOURCE_REMOVE;
        });
        this._extId = Main.extensionManager.connect('extension-state-changed',
            () => this._syncLate());
        this._syncLate();
    }

    disable() {
        if (this._clockId) this._wallClock.disconnect(this._clockId);
        this._clockId = 0;
        const box = Main.panel._rightBox;
        if (this._dateMenu.container.get_parent() === box) {
            box.remove_child(this._dateMenu.container);
            this._dateParent.add_child(this._dateMenu.container);
        }
        this._clockLabel.text = this._wallClock.clock;  // stock format back

        if (this._focusId) global.display.disconnect(this._focusId);
        this._focusId = 0;
        this._appLabel?.destroy();
        this._appLabel = null;

        this._search?.destroy();
        this._search = null;

        if (this._bannerBin) this._bannerBin.x_align = this._bannerAlign;

        if (this._retryId) GLib.source_remove(this._retryId);
        this._retryId = 0;
        if (this._extId) Main.extensionManager.disconnect(this._extId);
        this._extId = 0;
        for (const {item, box, vbox} of this._titled ?? []) {
            vbox.remove_child(box);
            item.set_child(box);
            vbox.destroy();
        }
        this._titled = [];
        this._logoMenu?.menu?.actor?.remove_style_class_name('sw-logo-menu');
        this._logoMenu = null;
        this._bannerBin = null;
        this._dateMenu = null;
        this._dateParent = null;
    }

    _syncLate() {
        // 5. Slider titles, like the Mac's Control Center modules.
        const qs = Main.panel.statusArea.quickSettings;
        const es = GLib.get_language_names()[0].startsWith('es');
        this._addTitle(qs?._brightness?.quickSettingsItems?.[0], es ? 'Pantalla' : 'Display');
        this._addTitle(qs?._volumeOutput?.quickSettingsItems?.[0], es ? 'Sonido' : 'Sound');

        // 6. The theme gives every menu a 32 px (invisible) arrow; GNOME then
        // shifts a menu whose source hugs the screen edge so that arrow can
        // point at it: 22 px + the 12 px shadow margin = the gap under ⌘.
        // A style class + stylesheet.css, not an inline style: PanelMenu
        // rewrites the menu's inline style (max-height) every time it opens.
        const logo = Main.panel.statusArea.LogoMenu;
        if (logo?.menu?.actor && logo !== this._logoMenu) {
            this._logoMenu = logo;
            logo.menu.actor.add_style_class_name('sw-logo-menu');
        }
    }

    _addTitle(item, text) {
        const box = item?.get_child();
        if (!box || this._titled.some(t => t.item === item)) return;
        const vbox = new St.BoxLayout({vertical: true, x_expand: true});
        item.set_child(vbox);
        vbox.add_child(new St.Label({text, style_class: 'sw-cc-title'}));
        vbox.add_child(box);
        this._titled.push({item, box, vbox});
    }

    _syncClock() {
        // "%a %-d %b  %H:%M" follows the system language: "Wed 23 Sep 14:24",
        // "mié 23 sept 14:24". First letter upper-cased, like macOS.
        const now = GLib.DateTime.new_now_local();
        const s = now.format('%a %-d %b  %H:%M') ?? this._wallClock.clock;
        this._clockLabel.text = s.charAt(0).toUpperCase() + s.slice(1);
    }

    _syncApp() {
        const app = this._tracker.focus_app;
        this._appLabel.text = app ? app.get_name() : '';
    }

    _spawnSearch() {
        try {
            GLib.spawn_async(null, SEARCH_CMD, null, GLib.SpawnFlags.SEARCH_PATH, null);
        } catch (e) {
            console.warn(`Second Wind Panel: search failed: ${e.message}`);
        }
    }
}
