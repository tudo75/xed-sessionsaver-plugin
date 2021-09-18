#!/bin/bash

meson setup build --prefix=/usr --wipe
# meson setup build --prefix=/usr
ninja -C build -v com.github.tudo75.xed-sessionsaver-plugin-pot
ninja -C build -v com.github.tudo75.xed-sessionsaver-plugin-update-po
ninja -C build -v com.github.tudo75.xed-sessionsaver-plugin-gmo
ninja -v -C build
ninja -v -C build install
