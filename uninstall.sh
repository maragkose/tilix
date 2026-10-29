#!/usr/bin/env sh

if [ -z  "$1" ]; then
    export PREFIX=/usr
    # Make sure only root can run our script
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
else
    export PREFIX=$1
fi

echo "Uninstalling from prefix ${PREFIX}"

rm ${PREFIX}/bin/terminio
rm ${PREFIX}/share/glib-2.0/schemas/io.github.maragkose.Terminio.gschema.xml
glib-compile-schemas ${PREFIX}/share/glib-2.0/schemas/
rm -rf ${PREFIX}/share/terminio

find ${PREFIX}/share/locale -type f -name "terminio.mo" -delete
find ${PREFIX}/share/icons/hicolor -type f -name "io.github.maragkose.Terminio.png" -delete
find ${PREFIX}/share/icons/hicolor -type f -name "io.github.maragkose.Terminio*.svg" -delete
rm ${PREFIX}/share/nautilus-python/extensions/open-terminio.py
rm ${PREFIX}/share/dbus-1/services/io.github.maragkose.Terminio.service
rm ${PREFIX}/share/applications/io.github.maragkose.Terminio.desktop
rm ${PREFIX}/share/metainfo/io.github.maragkose.Terminio.appdata.xml
rm ${PREFIX}/share/man/man1/terminio.1.gz
rm ${PREFIX}/share/man/*/man1/terminio.1.gz
