#!/bin/bash
source ./projectConfig.sh

WORKING_DIR="$(pwd)"
BUILD_DIR="$(pwd)/build_${ARCH}"

# if --OnlySign is passed, not build and pack
if [[ "$1" == "--OnlySign" ]]; then
    echo "Only signing the app bundle..."
else
    ./buildMacOs.sh
    ./packLibraries.sh
fi

cd "${BUILD_DIR}"

printf "\e[1;32mAssign all the libraries inside the app bundle\e[0m\n"
find "$APP_PATH" -type f -name "*.dylib" -exec \
codesign --deep --force --verify --verbose --timestamp --options runtime --sign "$DEVELOPER_ID" {} \;

printf "\e[1;32mAssign .app\e[0m\n"
codesign --deep --force --verify --verbose --timestamp --options runtime --sign "$DEVELOPER_ID" "$APP_PATH"

DMG_DIR="./Dmg"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -r "$APP_PATH" "$DMG_DIR/"

DMG_NAME="$WORKING_DIR/${APP_NAME}_${ARCH}.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDBZ "$DMG_NAME"
rm -rf "$DMG_DIR"

codesign --deep --force --verify --verbose --timestamp --options runtime --sign "$DEVELOPER_ID" "$DMG_NAME"
echo "Signing completed."

echo "Notarizing the app bundle..."
xcrun notarytool submit "$DMG_NAME" \
    --keychain-profile "$ACCOUNT_PROFILE" \
    --wait

printf "\e[1;32mVerifying the app bundle...\e[0m\n"
spctl --assess --type exec -vv "${DMG_NAME}"
codesign --verify --deep --strict --verbose=2 "${DMG_NAME}"

