import St from 'gi://St';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const STATUS_PATH = GLib.build_filenamev([
    GLib.get_home_dir(), '.local', 'state', 'otp-clipboard', 'status.json'
]);

function readStatus() {
    try {
        const file = Gio.File.new_for_path(STATUS_PATH);
        const [ok, contents] = file.load_contents(null);
        if (!ok)
            return null;
        const decoder = new TextDecoder('utf-8');
        return JSON.parse(decoder.decode(contents));
    } catch (e) {
        return null;
    }
}

function runCommand(argv) {
    try {
        Gio.Subprocess.new(argv, Gio.SubprocessFlags.NONE);
    } catch (e) {
        log(`OTP Clipboard Indicator command failed: ${e}`);
    }
}

class OtpIndicator extends PanelMenu.Button {
    constructor() {
        super(0.0, 'OTP Clipboard Indicator');

        this._box = new St.BoxLayout({style_class: 'panel-status-menu-box'});
        this._label = new St.Label({text: 'OTP', y_align: 2});
        this._dot = new St.Label({text: '●', y_align: 2, style: 'color: #f59e0b; padding-left: 4px;'});
        this._box.add_child(this._label);
        this._box.add_child(this._dot);
        this.add_child(this._box);

        this._statusItem = new PopupMenu.PopupMenuItem('Starting…', {reactive: false});
        this._lastItem = new PopupMenu.PopupMenuItem('Last code: none', {reactive: false});
        this._errorItem = new PopupMenu.PopupMenuItem('', {reactive: false});
        this.menu.addMenuItem(this._statusItem);
        this.menu.addMenuItem(this._lastItem);
        this.menu.addMenuItem(this._errorItem);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        const restart = new PopupMenu.PopupMenuItem('Restart OTP Listener');
        restart.connect('activate', () => runCommand(['systemctl', '--user', 'restart', 'otp-clipboard-listener.service']));
        this.menu.addMenuItem(restart);

        const stop = new PopupMenu.PopupMenuItem('Stop OTP Listener');
        stop.connect('activate', () => runCommand(['systemctl', '--user', 'stop', 'otp-clipboard-listener.service']));
        this.menu.addMenuItem(stop);

        this._refresh();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 3, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _refresh() {
        const status = readStatus();
        const now = Math.floor(Date.now() / 1000);
        const heartbeat = status?.heartbeat ?? 0;
        const fresh = status?.running === true && (now - heartbeat) < 15;

        if (fresh) {
            this._dot.set_style('color: #22c55e; padding-left: 4px;');
            this._statusItem.label.text = `Running — PID ${status.pid ?? '?'}`;
        } else if (status?.running === false) {
            this._dot.set_style('color: #ef4444; padding-left: 4px;');
            this._statusItem.label.text = 'Stopped';
        } else {
            this._dot.set_style('color: #f59e0b; padding-left: 4px;');
            this._statusItem.label.text = 'No fresh heartbeat';
        }

        if (status?.last_copy_time) {
            const d = new Date(status.last_copy_time * 1000);
            const time = d.toLocaleTimeString([], {hour: 'numeric', minute: '2-digit'});
            this._lastItem.label.text = `Last copied: ${status.last_code_masked ?? 'code'} at ${time}`;
        } else {
            this._lastItem.label.text = 'Last copied: none';
        }

        if (status?.last_error) {
            this._errorItem.label.text = `Error: ${status.last_error}`;
            this._errorItem.actor.visible = true;
        } else {
            this._errorItem.label.text = '';
            this._errorItem.actor.visible = false;
        }
    }

    destroy() {
        if (this._timer) {
            GLib.Source.remove(this._timer);
            this._timer = null;
        }
        super.destroy();
    }
}

export default class OtpClipboardIndicatorExtension extends Extension {
    enable() {
        this._indicator = new OtpIndicator();
        Main.panel.addToStatusArea(this.uuid, this._indicator, 1, 'right');
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
