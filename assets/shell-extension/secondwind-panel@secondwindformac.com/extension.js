// Second Wind Panel: the top bar details that make it read like a Mac's,
// done in one small extension we own (no third-party code to pin):
//   1. the clock moves from the center to the right edge, "Wed 23 Sep 14:24"
//   2. the active app's name, in bold, right after the ⌘ menu
//   3. a search (magnifier) button that opens Ulauncher, like Spotlight
//   4. notification banners in the top-right corner instead of top-center
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
        this._bannerBin = null;
        this._dateMenu = null;
        this._dateParent = null;
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
