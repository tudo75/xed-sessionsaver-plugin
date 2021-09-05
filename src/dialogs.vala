/*
 * dialogs.vala
 *
 * Copyright 2021 Nicola Tudino
 *
 * This file is part of xed-sessionsaver-plugin.
 *
 * xed-sessionsaver-plugin is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License.
 *
 * xed-sessionsaver-plugin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with xed-sessionsaver-plugin.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */


namespace SessionSaverPlugin {

    public class SessionModel : Gtk.ListStore {

        private const int OBJECT_COLUMN = 0;
        private const int NAME_COLUMN = 1;
        private const int N_COLUMNS = 2;
        private XMLSessionStore _store; 

        public SessionModel (XMLSessionStore store) {
            this._store = store;
            GLib.Type[] types = {typeof (Session), typeof (string)};
            this.set_column_types (types);
            Gtk.TreeIter iter;
            foreach (var session in this._store) {
                this.append (out iter);
                this.set (iter, OBJECT_COLUMN, session);
                this.set (iter, NAME_COLUMN, session.session_name);
            }
            store.session_added.connect_after (this.on_session_added);
            store.session_removed.connect (this.on_session_removed);
        }

        public void on_session_added () {
            Gtk.TreeIter iter;
            foreach (var session in this._store) {
                this.append (out iter);
                this.set (iter, OBJECT_COLUMN, session);
                this.set (iter, NAME_COLUMN, session.session_name);
            }
        }

        public void on_session_removed () {
            Gtk.TreeIter iter;
            foreach (var session in this._store) {
                this.append (out iter);
                this.set (iter, OBJECT_COLUMN, session);
                this.set (iter, NAME_COLUMN, session.session_name);
            }
            /*
            if (this.get_iter_first (out iter)) {
                while (true) {
                    Session stored_session;
                    this.@get (iter, OBJECT_COLUMN, out stored_session);
                    if (stored_session == session) {
                        this.remove (ref iter);
                        break;
                    }
                    if (! this.iter_next (ref iter))
                        break;
                }
            }
            */
        }
    }

    public class Dialog : GLib.Object {

        private const string UI_FILE = "/com/github/tudo75/xed-sessionsaver-plugin/sessionsaver.ui";
        private Gtk.Builder ui;
        public Xed.Window parent;
        public Gtk.Dialog dialog;

        public Dialog (string main_widget, Xed.Window parent_window) {
            this.parent = parent_window;
            this.ui = new Gtk.Builder ();
            
            try {
                this.ui.add_from_resource (UI_FILE);
            } catch (GLib.Error e) {
                print ("Error sessionsaver.ui: %s\n", e.message);
            }
            this.dialog = (Gtk.Dialog) this.ui.get_object (main_widget);
            this.dialog.delete_event.connect (this.on_delete_event);
        }

        public GLib.Object get_item (string item) {
            return this.ui.get_object (item);
        }

        private bool on_delete_event (Gtk.Widget dialog, Gdk.EventAny event) {
            dialog.hide ();
            return true;
        }

        public void run () {
            this.dialog.set_transient_for (this.parent);
            this.dialog.show ();
        }

        public void destroy () {
            this.dialog.destroy ();
            this.destroy ();
        }
    }

    public class SaveSessionDialog : Dialog {

        private const int NAME_COLUMN = 1;
        private XMLSessionStore sessions;
        private Gtk.ComboBox combobox;
        private SessionSaverWindow session_saver_window;

        public SaveSessionDialog (Xed.Window window, XMLSessionStore store, string current_session, SessionSaverWindow session_saver_window) {
            base ("save-session-dialog", window);

            this.session_saver_window = session_saver_window;
            this.sessions = store;

            SessionModel model = new SessionModel (store);
            
            this.combobox = (Gtk.ComboBox) this.get_item ("session-name");
            this.combobox.set_model (model);
            this.combobox.set_entry_text_column (NAME_COLUMN);
            this.combobox.changed.connect (on_name_combo_changed);

            if (current_session == null || current_session == "") {
                // this.on_name_combo_changed ();
            } else {
                this.set_combobox_active_by_name (current_session);
            }

            this.dialog.response.connect (on_response);
        }

        private bool set_combobox_active_by_name (string option_name) {
            SessionModel model = (SessionModel) this.combobox.get_model ();
            Gtk.TreeIter iter;
            if (model.get_iter_first (out iter)) {
                while (true) {
                    string option;
                    model.@get (iter, NAME_COLUMN, out option);
                    if (option == option_name) {
                        this.combobox.set_active_iter (iter);
                        return true;
                    }
                    if (! model.iter_next (ref iter)) {
                        break;
                    }
                }
            }
            return false;
        }

        private void on_name_combo_changed () {
            Gtk.Entry entry_field = (Gtk.Entry) this.combobox.get_child ();
            var name = entry_field.get_text ();
            print ("on_name_combo_changed: %s\n", name);
            Gtk.Button button = (Gtk.Button) this.get_item ("save_button");
            button.set_sensitive (name.length > 0);
        }

        private void on_response (Gtk.Dialog dialog, int response_id) {
            if (response_id == Gtk.ResponseType.OK) {
                GLib.SList<GLib.File>  files = new GLib.SList<GLib.File> ();
                foreach (var doc in this.parent.get_documents ()) {
                    if (doc.get_file ().get_location () != null)
                        files.append (doc.get_file ().get_location ());
                }
                Gtk.Entry entry_field = (Gtk.Entry) this.combobox.get_child ();
                var name = entry_field.get_text ();
                this.sessions.add_session (new Session(name, files));
                try {
                    this.sessions.save ();
                } catch (GLib.Error e) {
                    print ("Error SaveSessionDialog.on_response XMLSessionStore.save: %s\n", e.message);
                }
                this.session_saver_window.on_updated_sessions ();
            }
            this.destroy ();
        }
    }
}