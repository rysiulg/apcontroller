#!/bin/sh
set -eu
SOURCE=$(cd "${1:-.}" && pwd)
WORK=${APC_BUILD_DIR:-/mnt/usbstorage/apcontroller-build}
APK=${APK_BUILDER:-$WORK/tools/apk.static}
VERSION=$(tr -d '\r\n' < "$SOURCE/VERSION")
ARCH=${APC_ARCH:-$(head -n 1 /etc/apk/arch)}
case "$VERSION:$ARCH" in *[!a-zA-Z0-9_.:-]*) echo 'Invalid version or architecture' >&2; exit 1;; esac
KEY="$WORK/.signing/apcontroller-local.pem"
OUT="$WORK/releases/$VERSION"
STAGE="$WORK/stage/$VERSION"
umask 077
mkdir -p "$WORK/.signing" "$OUT/$ARCH" "$OUT/keys" "$STAGE/apcontroller" "$STAGE/luci-app-apcontroller" "$STAGE/luci-i18n-apcontroller-pl"
chmod 700 "$WORK/.signing"
if [ ! -s "$KEY" ]; then openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 -out "$KEY"; fi
chmod 600 "$KEY"
openssl pkey -in "$KEY" -pubout -out "$OUT/keys/apcontroller-local.pem"
cp -a "$SOURCE/runtime/usr" "$STAGE/apcontroller/"
rm -rf "$STAGE/apcontroller/usr/lib/lua" "$STAGE/apcontroller/usr/share/luci" "$STAGE/apcontroller/usr/share/rpcd"
mkdir -p "$STAGE/apcontroller/etc/config" "$STAGE/apcontroller/etc/apk/protected_paths.d" "$STAGE/apcontroller/lib/apk/packages"
cp "$SOURCE/packaging/default.config" "$STAGE/apcontroller/etc/config/apcontroller"
printf '%s\n' '+usr/share/apcontroller/apcontroller.user' '+etc/apcontroller/known_hosts' > "$STAGE/apcontroller/etc/apk/protected_paths.d/apcontroller.list"
printf '%s\n' /etc/config/apcontroller /usr/share/apcontroller/apcontroller.user /etc/apk/protected_paths.d/apcontroller.list > "$STAGE/apcontroller/lib/apk/packages/apcontroller.conffiles"
cp "$STAGE/apcontroller/lib/apk/packages/apcontroller.conffiles" "$STAGE/apcontroller/lib/apk/packages/apcontroller.conffiles_static"
printf '%s\n' "$VERSION" > "$STAGE/apcontroller/usr/share/apcontroller/VERSION"
mkdir -p "$STAGE/luci-app-apcontroller/usr/share" "$STAGE/luci-i18n-apcontroller-pl/usr/lib/lua/luci/i18n"
cp -a "$SOURCE/runtime/www" "$STAGE/luci-app-apcontroller/"
cp -a "$SOURCE/runtime/usr/share/luci" "$SOURCE/runtime/usr/share/rpcd" "$STAGE/luci-app-apcontroller/usr/share/"
cp "$SOURCE/runtime/usr/lib/lua/luci/i18n/apcontroller.pl.lmo" "$STAGE/luci-i18n-apcontroller-pl/usr/lib/lua/luci/i18n/"
find "$STAGE" -type d -exec chmod 755 '{}' ';'
find "$STAGE" -type f -exec chmod 644 '{}' ';'
chmod 755 "$STAGE/apcontroller/usr/bin/"* "$STAGE/apcontroller/usr/libexec/rpcd/apcontroller" "$STAGE/apcontroller/usr/share/apcontroller/poller" "$STAGE/apcontroller/usr/share/apcontroller/receiver"
"$APK" mkpkg --sign-key "$KEY" -I "name:apcontroller" -I "version:$VERSION" -I "arch:$ARCH" -I 'license:GPL-3.0-only' -I 'origin:apcontroller' -I 'description:AP controller with central client names and serialized polling' -I 'depends:libc busybox sshpass openssh-client ucode ucode-mod-fs ucode-mod-ubus ucode-mod-uci jsonfilter uci rpcd-mod-luci' -F "$STAGE/apcontroller" -s "post-install:$SOURCE/packaging/postinst.sh" -s "post-upgrade:$SOURCE/packaging/postinst.sh" -o "$OUT/$ARCH/apcontroller-$VERSION.apk"
"$APK" mkpkg --sign-key "$KEY" -I "name:luci-app-apcontroller" -I "version:$VERSION" -I "arch:$ARCH" -I 'license:GPL-3.0-only' -I 'origin:apcontroller' -I 'description:LuCI AP controller and client aliases' -I "depends:libc luci-base apcontroller>=$VERSION" -F "$STAGE/luci-app-apcontroller" -o "$OUT/$ARCH/luci-app-apcontroller-$VERSION.apk"
"$APK" mkpkg --sign-key "$KEY" -I "name:luci-i18n-apcontroller-pl" -I "version:$VERSION" -I "arch:$ARCH" -I 'license:GPL-3.0-only' -I 'origin:apcontroller' -I 'description:Polish translation of AP controller' -I "depends:libc luci-app-apcontroller>=$VERSION" -F "$STAGE/luci-i18n-apcontroller-pl" -o "$OUT/$ARCH/luci-i18n-apcontroller-pl-$VERSION.apk"
"$APK" mkndx --keys-dir "$OUT/keys" --sign-key "$KEY" --description "APController $VERSION" --output "$OUT/$ARCH/packages.adb" "$OUT/$ARCH/"*.apk
KEY_HASH=$(sha256sum "$OUT/keys/apcontroller-local.pem" | awk '{print $1}')
sed "s/@KEY_HASH@/$KEY_HASH/g" "$SOURCE/packaging/install.sh.in" > "$OUT/install.sh"
cp "$SOURCE/README.md" "$OUT/README.md"
(cd "$OUT"; sha256sum "$ARCH/"*.apk "$ARCH/packages.adb" keys/apcontroller-local.pem install.sh > SHA256SUMS)
chmod -R a+rX "$OUT"
echo "Signed release: $OUT"
