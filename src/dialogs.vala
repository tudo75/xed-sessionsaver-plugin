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
        private SchemaSessionStore _store; 

        public SessionModel (SchemaSessionStore store) {
            this._store = store;
            GLib.Type[] types = {typeof (GLib.SList<GLib.File>), typeof (string)};
            this.set_column_types (types);
            Gtk.TreeIter iter;
            foreach (var session in this._store) {
                this.append (out iter);
                this.set (iter, OBJECT_COLUMN, session.session_files);
                this.set (iter, NAME_COLUMN, session.session_name);
            }
            store.session_added.connect_after (this.on_session_added);
            store.session_removed.connect (this.on_session_removed);
        }

        public void on_session_added () {
            Gtk.TreeIter iter;
            foreach (var session in this._store) {
                this.append (out iter);
                this.set (iter, OBJECT_COLUMN, session.session_files);
                this.set (iter, NAME_COLUMN, session.session_name);
            }
        }

        public void on_session_removed (Session session) {
            Gtk.TreeIter iter;
            if (this.get_iter_first (out iter)) {
                while (true) {
                    Session stored_session = Session ();
                    this.@get (iter, NAME_COLUMN, out stored_session.session_name, OBJECT_COLUMN, out stored_session.session_files);
                    if (stored_session == session) {
                        this.remove (ref iter);
                        break;
                    }
                    if (! this.iter_next (ref iter))
                        break;
                }
            }
        }
    }

    public class SessionSaverDialog : Gtk.Dialog {

        public signal void sessions_updated ();

        private const int NAME_COLUMN = 1;
        private SchemaSessionStore sessions;
        private Gtk.ComboBox combobox;
        private Gtk.Button save_btn;
        private Xed.Window parent_xed_window;

        public SessionSaverDialog (Xed.Window parent_window, SchemaSessionStore store, string current_session) {
            this.parent_xed_window = parent_window;
            this.set_title (_("Save Session"));
            this.set_transient_for (parent_window);
            this.set_border_width (10);
            this.set_resizable (false);
            this.set_type_hint (Gdk.WindowTypeHint.DIALOG);

            Gtk.Box vbox = (Gtk.Box) this.get_content_area ();
            vbox.set_orientation (Gtk.Orientation.VERTICAL);
            vbox.set_spacing (6);
            
            this.sessions = store;
            SessionModel model = new SessionModel (store);

            Gtk.Label label = new Gtk.Label (_("Session Name") + ":");
            label.set_xalign (0);
            
            this.combobox = new Gtk.ComboBox.with_model_and_entry (model);
            this.combobox.set_entry_text_column (NAME_COLUMN);

            Gtk.Button cancel_btn = (Gtk.Button) this.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            cancel_btn.set_image (new Gtk.Image.from_icon_name ("process-stop", Gtk.IconSize.BUTTON));
            cancel_btn.set_valign (Gtk.Align.CENTER);
            this.save_btn = (Gtk.Button) this.add_button (_("Save"), Gtk.ResponseType.OK);
            this.save_btn.set_image (new Gtk.Image.from_icon_name ("document-save", Gtk.IconSize.BUTTON));
            this.save_btn.set_valign (Gtk.Align.CENTER);
            
            if (current_session == null || current_session == "") {
                this.on_name_combo_changed (combobox);
            } else {
                this.set_combobox_active_by_name (current_session);
            }

            vbox.add (label);
            vbox.add (combobox);

            combobox.changed.connect (this.on_name_combo_changed);
            this.response.connect (this.on_response);
            this.show_all ();
            this.show ();
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

        private void on_name_combo_changed (Gtk.ComboBox combo) {
            Gtk.Entry entry_field = (Gtk.Entry) combo.get_child ();
            var name = entry_field.get_text ();
            this.save_btn.set_sensitive (name.length > 0);
        }

        private void on_response (Gtk.Dialog dialog, int response_id) {
            if (response_id == Gtk.ResponseType.OK) {
                Gtk.Entry entry_field = (Gtk.Entry) this.combobox.get_child ();
                var name = entry_field.get_text ();
                var new_session = Session () {session_name = name, session_files = new GLib.SList<GLib.File> ()};
                foreach (var doc in this.parent_xed_window.get_documents ()) {
                    if (doc.get_file ().get_location () != null) {
                       new_session.add_file (doc.get_file ().get_location ().get_uri ());
                    }
                }
                this.sessions.add_session (new_session);
                this.sessions.save ();
                this.sessions_updated ();
            }
            this.destroy ();
        }
    }

    public class SessionManagerDialog : Gtk.Dialog {

        public signal void session_selected (Session session);
        public signal void sessions_updated ();
        public signal void session_removed (Session session);

        private const int OBJECT_COLUMN = 0;
        private const int NAME_COLUMN = 1;
        private SchemaSessionStore sessions;
        private Xed.Window parent_xed_window;
        private Gtk.TreeView tree_view;
        private bool are_sessions_updated = false;
        private SessionModel model;

        public SessionManagerDialog (Xed.Window parent_window, SchemaSessionStore store) {
            this.parent_xed_window = parent_window;
            this.set_title (_("Saved Sessions"));
            this.set_transient_for (parent_window);
            this.set_border_width (10);
            this.set_resizable (false);
            this.set_type_hint (Gdk.WindowTypeHint.DIALOG);
            this.sessions = store;
            this.set_size_request (400, 200);

            this.model = new SessionModel (this.sessions);

            Gtk.Box vbox = (Gtk.Box) this.get_content_area ();
            vbox.set_orientation (Gtk.Orientation.VERTICAL);
            vbox.set_spacing (0);
            Gtk.Box hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            Gtk.ScrolledWindow scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.set_hexpand (true);
            scrolled_window.set_vexpand (true);
            scrolled_window.set_shadow_type (Gtk.ShadowType.IN);
            scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;

            this.tree_view = new Gtk.TreeView.with_model (this.model);
            Gtk.CellRendererText renderer = new Gtk.CellRendererText ();
            Gtk.TreeViewColumn column = new Gtk.TreeViewColumn ();
            column.set_title (_("Session Name"));
            column.pack_start (renderer, true);
            column.add_attribute (renderer, "text", NAME_COLUMN);
            tree_view.append_column (column);
            scrolled_window.add (tree_view);

            Gtk.Box button_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            button_box.set_homogeneous (false);
            button_box.set_vexpand (true);
            Gtk.Button open_btn = new Gtk.Button.from_icon_name ("document-open", Gtk.IconSize.BUTTON);
            Gtk.Button remove_btn = new Gtk.Button.from_icon_name ("edit-delete", Gtk.IconSize.BUTTON);
            Gtk.Button close_btn = new Gtk.Button.from_icon_name ("process-stop", Gtk.IconSize.BUTTON);
            open_btn.set_label (_("Open"));
            open_btn.set_valign (Gtk.Align.CENTER);
            open_btn.clicked.connect (this.on_open_button_clicked);
            remove_btn.set_label (_("Remove"));
            remove_btn.set_valign (Gtk.Align.CENTER);
            remove_btn.clicked.connect (this.on_delete_button_clicked);
            close_btn.set_label (_("Close"));
            close_btn.set_valign (Gtk.Align.CENTER);
            close_btn.clicked.connect (this.on_close_button_clicked);

            Gtk.Button export_btn = new Gtk.Button.from_icon_name ("document-save", Gtk.IconSize.BUTTON);
            export_btn.set_label (_("Export"));
            export_btn.set_valign (Gtk.Align.CENTER);
            export_btn.clicked.connect (this.on_export_button_clicked);
            Gtk.Button import_btn = new Gtk.Button.from_icon_name ("document-open", Gtk.IconSize.BUTTON);
            import_btn.set_label (_("Import"));
            import_btn.set_valign (Gtk.Align.CENTER);
            import_btn.clicked.connect (this.on_import_button_clicked);

            button_box.pack_start (open_btn, false, true, 0);
            button_box.pack_start (remove_btn, false, true, 0);
            button_box.pack_start (export_btn, false, true, 0);
            button_box.pack_start (import_btn, false, true, 0);
            button_box.pack_end (close_btn, false, true, 0);

            this.delete_event.connect (on_delete_event);

            hbox.add (scrolled_window);
            hbox.add (button_box);
            vbox.add (hbox);
            this.show_all ();
            this.show ();
        }

        private bool on_delete_event (Gtk.Widget dialog, Gdk.EventAny event) {
            this.should_save_sessions ();
            this.destroy ();
            return true;
        }

        private Session get_current_session () {
            Gtk.TreeModel tree_model;
            Gtk.TreeIter iter;
            this.tree_view.get_selection ().get_selected (out tree_model, out iter);
            var session = Session ();
            tree_model.get (iter, NAME_COLUMN, out session.session_name, OBJECT_COLUMN, out session.session_files);
            return session;
        }

        private void on_open_button_clicked (Gtk.Button button) {
            Session session = this.get_current_session ();
            if (session.session_name != "" && session.session_name != null && session.session_files.length () > 0) {
                this.session_selected (session);
            }
            this.destroy ();
        }

        private void on_delete_button_clicked (Gtk.Button button) {
            Session session = this.get_current_session ();
            this.sessions.remove_session (session);
            this.model.on_session_removed (session);
            this.are_sessions_updated = true;
            this.should_save_sessions ();
        }

        private void on_close_button_clicked (Gtk.Button button) {
            this.should_save_sessions ();
            this.destroy ();
        }

        private void should_save_sessions () {
            if (are_sessions_updated) {
                this.sessions.save ();
                this.are_sessions_updated = false;
                this.sessions_updated ();
            }
        }

        private void on_export_button_clicked (Gtk.Button button) {
            sessions.export_sessions (this.parent_xed_window);
        }

        private void on_import_button_clicked (Gtk.Button button) {
            Gtk.MessageType message_type = Gtk.MessageType.ERROR;
            string msg = "Import failed!";
            if (sessions.import_sessions (this.parent_xed_window)) {
                message_type = Gtk.MessageType.INFO;
                msg = "Saved sessions succesfully imported.";
                this.sessions_updated ();
            }
            Gtk.MessageDialog msg_dialog = new Gtk.MessageDialog (
                this.parent_xed_window,
                Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
                message_type,
                Gtk.ButtonsType.CLOSE,
                msg
            );
            msg_dialog.response.connect (close_dialog);
            msg_dialog.run ();
        }

        private void close_dialog (Gtk.Dialog dialog, int response_id) {
            dialog.destroy ();
        }
    }
}