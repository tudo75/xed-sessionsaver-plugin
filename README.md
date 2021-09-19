# xed-sessionsaver-plugin

Porting of the Gedit SessionSaver plugin to Xed

## Requirements

To interface with xed some libraries are needed:

* libpeas-1.0-dev
* libpeas-gtk-1.0
* libglib2.0-dev
* libgtk-3-dev
* libgtksourceview-4-dev
* libxml-2.0
* libxapp-dev
* xed-dev
* gxml-0.20 (included as submodule project)

## Install

Run <code>./run.sh</code> to install with meson build system.

Or if you want to do it manually:

    meson setup build --prefix=/usr
    ninja -v -C build com.github.tudo75.xed-sessionsaver-plugin-gmo
    ninja -v -C build
    ninja -v -C build install
    

Run <code>xed</code> and go to <i>Preferences->Plugin</i> and enable the <code>SessionSaver</code>. 
You can verify the plugin preferences pane and information with the bottom buttons.

## Uninstall

Run <code>./uninstall.sh</code> if you installed through meson system or if you would it manually:
    
    sudo ninja -v -C build uninstall
    sudo rm /usr/share/locale/en/LC_MESSAGES/com.github.tudo75.xed-sessionsaver-plugin.mo
    sudo rm /usr/share/locale/it/LC_MESSAGES/com.github.tudo75.xed-sessionsaver-plugin.mo

## Credits

Based on this Gedit Plugin

https://gitlab.gnome.org/GNOME/gedit-plugins/-/tree/master/plugins/sessionsaver