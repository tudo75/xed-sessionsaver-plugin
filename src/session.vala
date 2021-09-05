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

    public class Session : GLib.Object {

        public string session_name;
        public GLib.SList<GLib.File> session_files;

        public Session (string name,  GLib.SList<GLib.File> files) {
            this.session_name = name;
            if (files.length () == 0 || files == null) {
                this.session_files = new GLib.SList<GLib.File> ();
            } else {
                this.session_files = (GLib.SList<GLib.File>) files.copy ();
            }
        }

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

    public class SessionStore : Gee.ArrayList<Session> {

        // [Signal (run_last=true, type_none=true)]
        public signal void session_added ();
        // [Signal (run_last=true, type_none=true)]
        public signal void session_changed ();
        // [Signal (run_last=true, type_none=true)]
        public signal void session_removed ();

        public SessionStore () {}

        public Session get_item (int index) {
            return this [index];
        }

        public int compare_func (Session a, Session b) {            
            if (a.lt (b))
                return -1;
            if (a.eq (b))
                return 0;
            return  1;
        }

        public void add_session (Session session) {
            if (this.contains (session)) {
                int index = this.index_of (session);
                this [index] = session;
                this.session_changed ();
            } else {
                this.add (session);
                this.sort (compare_func);
                this.session_added ();
            }
        }

        public void remove_session (Session session) {
            if (this.contains (session)) {
                this.remove (session);
                this.session_removed ();
            }
        }
    }

    public class XMLSessionStore : SessionStore {

        private GXml.Document doc;
        private GXml.Element saved_sessions;
        private GLib.File f;

        public XMLSessionStore () throws GLib.Error {
            f = GLib.File.new_for_path (
                                GLib.Path.build_filename (
                                    GLib.Environment.get_user_config_dir(),
                                    "xed/saved-sessions.xml"
                                )
                            );
            if (! f.query_exists ()) {
                GXml.Document tmp_doc = new GXml.Document();
                GXml.DomElement tmp_saved_sessions = tmp_doc.create_element ("saved-sessions");
                tmp_doc.append_child (tmp_saved_sessions);
                tmp_doc.write_file (f);
            }
            doc = new GXml.Document.from_file (f);
            if (doc.child_element_count > 0)
                saved_sessions = (GXml.Element) doc.first_element_child;

        }

        public void load () throws GLib.Error {
            if (saved_sessions.child_element_count > 0) {
                GXml.DomHTMLCollection sessions = saved_sessions.get_elements_by_tag_name ("session");
                for (var i = 0; i < sessions.length; i++) {
                    Session new_session = new Session (sessions[i].get_attribute ("name"), new GLib.SList<GLib.File> ());
                    GXml.DomHTMLCollection files = sessions[i].get_elements_by_tag_name ("file");
                    for (var j = 0; j < files.length; j++) {
                        new_session.add_file (files[j].get_attribute ("path"));
                    }
                    this.add_session (new_session);
                }
            }
        }

        public void save () throws GLib.Error {
            for (var i = 0; i < this.size; i++) {
                Session current = this.get_item (i);
                GXml.Element new_session = this.get_session (doc, saved_sessions, current.session_name);
                GLib.SList<GLib.File> session_files = (GLib.SList<GLib.File>) current.session_files.copy ();
                foreach (var file in session_files)
                    this.insert_file (doc, new_session, file.get_uri ());
            }
            saved_sessions.write_file (f);
        }

        private GXml.Element get_session (GXml.Document doc, GXml.Element saved_sessions, string name) throws GLib.Error {
            if (saved_sessions.child_element_count > 0) {
                GXml.DomHTMLCollection sessions = saved_sessions.get_elements_by_tag_name ("session");
                for (var i = 0; i < sessions.length; i++) {
                    if (sessions[i].get_attribute ("name") == name) {
                        return (GXml.Element) sessions[i];
                    }
                }
            }
            return this.insert_session (doc, saved_sessions, name);
        }

        private GXml.Element insert_session (GXml.Document doc, GXml.Element saved_sessions, string name) throws GLib.Error {
            GXml.Element new_session = new GXml.Element ();
            new_session.initialize_document (doc, "session");
            new_session.set_attribute ("name", name);
            saved_sessions.append_child (new_session);
            return new_session;
        }

        private bool insert_file (GXml.Document doc, GXml.Element session, string path) throws GLib.Error {
            if (session.child_element_count > 0) {
                GXml.DomHTMLCollection files = session.get_elements_by_tag_name ("file");
                for (var i = 0; i < files.length; i++) {
                    if (files[i].get_attribute ("path") == path) {
                        return true;
                    }
                }
            }
            GXml.Element new_file = new GXml.Element ();
            new_file.initialize_document (doc, "file");
            new_file.set_attribute ("path", path);
            session.append_child (new_file);        
            return true;
        }
    }
}
