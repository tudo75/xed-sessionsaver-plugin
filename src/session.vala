/*
 * session.vala
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

    public struct Session {

        public string session_name;
        public unowned GLib.SList<GLib.File> session_files;

        public bool lt (Session session) {
            return (this.session_name.down () < session.session_name.down ());
        }

        public bool eq (Session session) {
            return (this.session_name.down () == session.session_name.down ());
        }

        public void add_file (string filename) {
            this.session_files.append (GLib.File.new_for_uri (filename));
        }
    }

    public class SessionStore : Gee.ArrayList<Session?> {

        // [Signal (run_last=true, type_none=true)]
        public signal void session_added ();
        // [Signal (run_last=true, type_none=true)]
        public signal void session_changed ();
        // [Signal (run_last=true, type_none=true)]
        public signal void session_removed (Session session);

        public SessionStore () {
            this.sort ((CompareDataFunc<Session?>) session_compare);
        }

        public Session get_item (int index) {
            return this[index];
        }

        public int session_compare (Session a, Session b) {          
            if (a.lt (b))
                return -1;
            if (a.eq (b))
                return 0;
            return  1;
        }

        public void add_session (Session session) {
            bool contains = false;
            int index = 0;
            for (var i = 0; i < this.size; i++) {
                if (this.get_item (i).session_name == session.session_name) {
                    contains = true;
                    index = i;
                }
            }
            if (contains) {
                this [index] = session;
                this.sort ((CompareDataFunc<Session?>) session_compare);
                this.session_changed ();
            } else {
                this.add (session);
                this.sort ((CompareDataFunc<Session?>) session_compare);
                this.session_added ();
            }
        }

        public void remove_session (Session session) {
            for (var i = 0; i < this.size; i++) {
                if (this.get_item (i).session_name == session.session_name) {
                    this.remove_at (i);
                    this.sort ((CompareDataFunc<Session?>) session_compare);
                    this.session_removed (session);
                }
            }
        }
    }

    public class SchemaSessionStore : SessionStore {

        private GLib.Settings settings;

        public SchemaSessionStore () {
            //get settings from compiled schema
            settings = new GLib.Settings ("com.github.tudo75.xed-sessionsaver-plugin");
            GLib.Variant sessionsVariant = settings.get_value ("sessions");
                        
            VariantIter iter = sessionsVariant.iterator ();
            while (true) {
                GLib.Variant itemVariant = iter.next_value ();
                if (itemVariant == null)
                    break;

                Session new_session = {"", new GLib.SList<GLib.File> ()};
                var i = 0;
                foreach (var item in itemVariant) {
                    if (i == 0) {
                        new_session.session_name = item.get_string ();
                    } else {
                        new_session.add_file (item.get_string ());
                    }
                    i++;
                }
                this.add_session (new_session);
            }
        }

        public void save () {
            VariantBuilder sessions = new VariantBuilder (new VariantType ("aas"));
            for (var i = 0; i < this.size; i++) {
                Session current = this.get_item (i);
                VariantBuilder session = new VariantBuilder (new VariantType ("as"));;
                session.add ("s", current.session_name);
                if (current.session_files.length () > 0) {
                    foreach (var file in current.session_files) {
                        if (file != null && file.get_uri () != "") {
                            session.add ("s", file.get_uri ());
                        }
                    }
                }
                sessions.add ("as", session);
            }
            GLib.Variant sessionsVariant = new GLib.Variant ("aas", sessions);
            settings.set_value ("sessions", sessionsVariant);
        }

        public void export_sessions (Xed.Window parent_window) {
            GLib.Variant sessionsVariant = settings.get_value ("sessions");
            Json.Node root = Json.gvariant_serialize (sessionsVariant);
            Json.Generator generator = new Json.Generator ();
            generator.set_root (root);
            // print ("JSON:\n%s\n", generator.to_data (null));
            // print ("JSON pretty node:\n%s\n", Json.to_string (root, true));

            Gtk.FileChooserNative export_dialog = new Gtk.FileChooserNative(_("Save saved-sessions.json"),
                                       parent_window,
                                       Gtk.FileChooserAction.SAVE,
                                       _("Save"),
                                       _("Cancel")
                                       );
            export_dialog.set_do_overwrite_confirmation (true);
            export_dialog.set_current_name ("saved-sessions.json");
            int response = export_dialog.run ();
            if (response == Gtk.ResponseType.ACCEPT) {
                GLib.File f = export_dialog.get_file ();
                try {
                    GLib.FileOutputStream file_stream = f.replace (null,
                                                            false,
                                                            GLib.FileCreateFlags.REPLACE_DESTINATION);
                    var data_stream = new DataOutputStream (file_stream);
                    data_stream.put_string (Json.to_string (root, true));
                } catch (GLib.Error e) {
                    print ("Error creating exported file: %s\n", e.message);
                }
            }
        }

        public bool import_sessions (Xed.Window parent_window) {
            Gtk.FileChooserNative import_dialog = new Gtk.FileChooserNative(_("Open saved-sessions.json"),
                                       parent_window,
                                       Gtk.FileChooserAction.OPEN,
                                       _("Open"),
                                       _("Cancel")
                                       );
            int response = import_dialog.run ();
            if (response == Gtk.ResponseType.ACCEPT) {
                GLib.File f = import_dialog.get_file ();
                try {
                    GLib.DataInputStream dis = new GLib.DataInputStream (f.read ());
                    string line;
                    string content = "";
                    while ((line = dis.read_line (null)) != null) {
                        content += line;
                    }
                    Json.Parser parser = new Json.Parser ();
                    parser.load_from_data (content);
            		Json.Node node = parser.get_root ();
                    GLib.Variant sessionsVariant = Json.gvariant_deserialize (node, "aas");
                    settings.set_value ("sessions", sessionsVariant);
                } catch (GLib.Error e) {
                    print ("Error importing file: %s\n", e.message);
                    return false;
                }
            }
            return true;    
        }
    }
}
