// Preferences window (runs in the preferences process, not in GNOME Shell: GTK 4 and libadwaita only).
import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';
import {ExtensionPreferences, gettext as _} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

function switchRow(settings, key, title, subtitle) {
    const row = new Adw.SwitchRow({title, subtitle});
    settings.bind(key, row, 'active', Gio.SettingsBindFlags.DEFAULT);
    return row;
}

export default class WindowMagnetPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        const page = new Adw.PreferencesPage({icon_name: 'preferences-system-symbolic'});

        const snapping = new Adw.PreferencesGroup({title: _('Snapping')});
        const range = settings.settings_schema.get_key('snap-threshold').get_range().recursiveUnpack()[1];
        const threshold = new Adw.SpinRow({
            title: _('Snap distance'),
            subtitle: _('How close, in pixels, an edge must come before it snaps'),
            adjustment: new Gtk.Adjustment({lower: range[0], upper: range[1], step_increment: 1, page_increment: 4}),
        });
        settings.bind('snap-threshold', threshold, 'value', Gio.SettingsBindFlags.DEFAULT);
        snapping.add(threshold);
        snapping.add(switchRow(settings, 'snap-to-windows', _('Snap to other windows'),
            _('Edges of the other windows on the same workspace and screen')));
        snapping.add(switchRow(settings, 'snap-to-screen-edges', _('Snap to screen edges'),
            _('Edges of the screen, below the top bar and beside docks')));
        snapping.add(switchRow(settings, 'snap-while-resizing', _('Snap while resizing'),
            _('The edges you drag snap too')));
        page.add(snapping);

        const motion = new Adw.PreferencesGroup({title: _('Motion')});
        motion.add(switchRow(settings, 'spring-animation', _('Spring animation'),
            _('Smooths the jump of a snap. Follows the system Animations setting')));
        page.add(motion);

        const tabs = new Adw.PreferencesGroup({title: _('Tabs')});
        tabs.add(switchRow(settings, 'place-dropped-tabs', _('Open dropped tabs where they are dropped'),
            _('A tab dragged out of a window and dropped on the desktop opens there, at the size of its window')));
        page.add(tabs);

        window.add(page);
        // Tall enough for every group without scrolling (Mutter still fits it on smaller screens).
        window.set_default_size(640, 660);
    }
}
