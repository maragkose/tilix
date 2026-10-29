#!/usr/bin/env sh
# exit on first error
set -o errexit

# Determine PREFIX.
if [ -z "$1" ]; then
    if [ -z "$PREFIX" ]; then
        PREFIX='/usr'
    fi
else
    PREFIX="$1"
fi
export PREFIX

if [ "$PREFIX" = "/usr" ] && [ "$(id -u)" != "0" ]; then
    # Make sure only root can run our script
    echo "This script must be run as root" 1>&2
    exit 1
fi

if [ ! -f terminio ]; then
    echo "The terminio executable does not exist, please run 'dub build --build=release' before using this script"
    exit 1
fi

# Check availability of required commands
COMMANDS="install glib-compile-schemas glib-compile-resources msgfmt desktop-file-validate gtk-update-icon-cache"
if [ "$PREFIX" = '/usr' ] || [ "$PREFIX" = "/usr/local" ]; then
    COMMANDS="$COMMANDS xdg-desktop-menu"
fi
PACKAGES="coreutils glib2 gettext desktop-file-utils gtk-update-icon-cache xdg-utils"
i=0
for COMMAND in $COMMANDS; do
    type $COMMAND >/dev/null 2>&1 || {
        j=0
        for PACKAGE in $PACKAGES; do
            if [ $i = $j ]; then
                break
            fi
            j=$(( $j + 1 ))
        done
        echo "Your system is missing command $COMMAND, please install $PACKAGE"
        exit 1
    }
    i=$(( $i + 1 ))
done

echo "Installing to prefix $PREFIX"

# Copy and compile schema
echo "Copying and compiling schema..."
install -Dm 644 data/gsettings/io.github.maragkose.Terminio.gschema.xml -t "$PREFIX/share/glib-2.0/schemas/"
glib-compile-schemas $PREFIX/share/glib-2.0/schemas/

export TERMINIO_SHARE="$PREFIX/share/terminio"

# Copy and compile icons
cd data/resources

echo "Building and copy resources..."
glib-compile-resources terminio.gresource.xml
install -Dm 644 terminio.gresource -t "$TERMINIO_SHARE/resources/"

cd ../..

# Copy shell integration script
echo "Copying scripts..."
install -Dm 755 data/scripts/* -t "$TERMINIO_SHARE/scripts/"

# Copy color schemes
echo "Copying color schemes..."
install -Dm 644 data/schemes/* -t "$TERMINIO_SHARE/schemes/"

# Create/Update LINGUAS file
find po -name "*\.po" -printf "%f\\n" | sed "s/\.po//g" | sort > po/LINGUAS

# Compile po files
echo "Copying and installing localization files"
for f in po/*.po; do
    echo "Processing $f"
    LOCALE=$(basename "$f" .po)
    msgfmt $f -o "$LOCALE.mo"
    install -Dm 644 "$LOCALE.mo" "$PREFIX/share/locale/$LOCALE/LC_MESSAGES/terminio.mo"
    rm -f "$LOCALE.mo"
done

# Generate desktop file
msgfmt --desktop --template=data/pkg/desktop/io.github.maragkose.Terminio.desktop.in -d po -o data/pkg/desktop/io.github.maragkose.Terminio.desktop
if [ $? -ne 0 ]; then
    echo "Note that localizating appdata requires a newer version of xgettext, copying instead"
    cp data/pkg/desktop/io.github.maragkose.Terminio.desktop.in data/pkg/desktop/io.github.maragkose.Terminio.desktop
fi

desktop-file-validate data/pkg/desktop/io.github.maragkose.Terminio.desktop

# Generate appdata file, requires xgettext 0.19.7
msgfmt --xml --template=data/metainfo/io.github.maragkose.Terminio.appdata.xml.in -d po -o data/metainfo/io.github.maragkose.Terminio.appdata.xml
if [ $? -ne 0 ]; then
    echo "Note that localizating appdata requires xgettext 0.19.7 or later, copying instead"
    cp data/metainfo/io.github.maragkose.Terminio.appdata.xml.in data/metainfo/io.github.maragkose.Terminio.appdata.xml
fi

# Copying Nautilus extension
echo "Copying Nautilus extension"
install -Dm 644 data/nautilus/open-terminio.py -t "$PREFIX/share/nautilus-python/extensions/"

# Copy D-Bus service descriptor
sed "s#@bindir@#$PREFIX/bin#" data/dbus/io.github.maragkose.Terminio.service.in > data/dbus/io.github.maragkose.Terminio.service
install -Dm 644 data/dbus/io.github.maragkose.Terminio.service -t "$PREFIX/share/dbus-1/services/"

# Copy man page
. $(dirname $(realpath "$0"))/data/scripts/install-man-pages.sh

# Copy Icons
cd data/icons/hicolor

find . -type f | while read f; do
    install -Dm 644 "$f" "$PREFIX/share/icons/hicolor/$f"
done

cd ../../..

# Copy executable, desktop and appdata file
install -Dm 755 terminio -t "$PREFIX/bin/"

install -Dm 644 data/pkg/desktop/io.github.maragkose.Terminio.desktop -t "$PREFIX/share/applications/"
install -Dm 644 data/metainfo/io.github.maragkose.Terminio.appdata.xml -t "$PREFIX/share/metainfo/"

# Update icon cache if Prefix is /usr
if [ "$PREFIX" = '/usr' ] || [ "$PREFIX" = "/usr/local" ]; then
    echo "Updating desktop file cache"
    xdg-desktop-menu forceupdate --mode system

    echo "Updating icon cache"
    gtk-update-icon-cache -f "$PREFIX/share/icons/hicolor/"
fi
