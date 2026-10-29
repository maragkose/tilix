export TERMINIO_ARCHIVE_PATH="/tmp/terminio/archive";

rm -rf ${TERMINIO_ARCHIVE_PATH}

CURRENT_DIR=$(pwd)

echo "Building application..."
cd ../../..
dub build --build=release --compiler=ldc2
strip terminio

./install.sh ${TERMINIO_ARCHIVE_PATH}/usr

# Remove compiled schema
rm ${TERMINIO_ARCHIVE_PATH}/usr/share/glib-2.0/schemas/gschemas.compiled

echo "Creating archive"
cd ${TERMINIO_ARCHIVE_PATH}
zip -r terminio.zip *

cp terminio.zip ${CURRENT_DIR}/terminio.zip
cd ${CURRENT_DIR}
