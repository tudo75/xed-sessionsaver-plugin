/*
 * sessionsaver.vala
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


    /*
    * Register plugin extension types
    */
    [CCode (cname="G_MODULE_EXPORT peas_register_types")]
    [ModuleInit]
    public void peas_register_types (TypeModule module) 
    {
        var objmodule = module as Peas.ObjectModule;

        // Register my plugin extension
        objmodule.register_extension_type (typeof (Xed.AppActivatable), typeof (SessionSaverPlugin.SessionSaverApp));
        objmodule.register_extension_type (typeof (Xed.WindowActivatable), typeof (SessionSaverPlugin.SessionSaverWindow));
        objmodule.register_extension_type (typeof (Xed.ViewActivatable), typeof (SessionSaverPlugin.SessionSaverView));
        // Register my config dialog
        objmodule.register_extension_type (typeof (PeasGtk.Configurable), typeof (SessionSaverPlugin.ConfigSessionSaver));
    }
    
    /*
    * AppActivatable
    */
    public class SessionSaverApp : Xed.AppActivatable, Peas.ExtensionBase {

        public SessionSaverApp () {
            GLib.Object ();
        }

        public Xed.App app {
            owned get; construct;
        }

        public void activate () {
            print ("SessionSaverApp activated\n");

        }

        public void deactivate () {
            print ("SessionSaverApp deactivated\n");
        }
    }
    
    /*
    * WindowActivatable
    */
    public class SessionSaverWindow : Xed.WindowActivatable, Peas.ExtensionBase {

        private uint merge_id;
        private Gtk.UIManager manager;
        private XMLSessionStore sessions;
        
        public SessionSaverWindow () {
            GLib.Object ();
        }

        public Xed.Window window {
            owned get; construct;
        }

        public void activate () {
            print ("SessionSaverWindow activated\n");
            try {
                sessions = new XMLSessionStore ();
            } catch (GLib.Error e) {
                print ("Errore XMLSessionStore: %s\n", e.message);
            }
            manager = window.get_ui_manager ();

            Gtk.ActionGroup action_group = new Gtk.ActionGroup ("sessionsaver");
            Gtk.Action action_manage_sessions = new Gtk.Action ("manage-session", _("Manage Saved Sessions"), _("Manage Saved Sessions"), "win.managedsession");
            action_group.add_action (action_manage_sessions);
            Gtk.Action action_save_sessions = new Gtk.Action ("save-session", _("Save Session"), _("Save Session"), "win.savesession");
            action_group.add_action (action_save_sessions);
            merge_id = manager.new_merge_id ();
            manager.insert_action_group (action_group, -1);
            manager.add_ui (merge_id, "/MenuBar/ToolsMenu/ToolsOps_3", "manage-session", "manage-session", Gtk.UIManagerItemType.MENUITEM, false);
            manager.add_ui (merge_id, "/MenuBar/ToolsMenu/ToolsOps_3", "save-session", "save-session", Gtk.UIManagerItemType.MENUITEM, false);

        }

        public void deactivate () {
            print ("SessionSaverWindow deactivated\n");
            manager.remove_ui (merge_id);
        }

        public void update_state () {
            print ("SessionSaverWindow update_state\n");
        }
    }
    
    /*
    * ViewActivatable
    */
    public class SessionSaverView : Xed.ViewActivatable, Peas.ExtensionBase {

        public SessionSaverView () {
            GLib.Object ();
        }

        public Xed.View view {
            owned get; construct;
        }

        public void activate () {
            print ("SessionSaverView activated\n");
        }

        public void deactivate () {
            print ("SessionSaverView deactivated\n");
        }
    }

    /*
    * Plugin config dialog
    */
    public class ConfigSessionSaver : Peas.ExtensionBase, PeasGtk.Configurable
    {
        public ConfigSessionSaver () 
        {
            GLib.Object ();
        }

        public Gtk.Widget create_configure_widget () 
        {

            var label = new Gtk.Label ("");
            label.set_markup (_("<big>Xed SessionSaver Plugin Settings</big>"));
            label.set_margin_top (10);
            label.set_margin_bottom (15);
            label.set_margin_start (10);
            label.set_margin_end (10);

            Gtk.Grid main_grid = new Gtk.Grid ();
            main_grid.set_valign (Gtk.Align.START);
            main_grid.set_margin_top (10);
            main_grid.set_margin_bottom (10);
            main_grid.set_margin_start (10);
            main_grid.set_margin_end (10);
            main_grid.set_column_homogeneous (false);
            main_grid.set_row_homogeneous (false);
            main_grid.set_vexpand (true);
            main_grid.attach (label, 0, 0, 1, 1);

            return main_grid;
        }
    }
}