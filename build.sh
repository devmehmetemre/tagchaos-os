#!/bin/sh
# CHA OS build - minirootfs tabanlı
# Kullanim: ./build.sh --arch x86_64 --desktop xfce --version 1.0.0
set -eu
ARCH="x86_64"; DESKTOP="xfce"; VERSION="1.0.0"; ALPINE_VER="v3.20"; MAKE_ISO="no"
while [ $# -gt 0 ]; do case "$1" in
  --arch) ARCH="$2"; shift 2;; --desktop) DESKTOP="$2"; shift 2;;
  --version) VERSION="$2"; shift 2;; --iso) MAKE_ISO="yes"; shift;;
  *) shift;;
esac; done

OUT="out"; ROOTFS="$OUT/rootfs-$ARCH"
mkdir -p "$OUT"
echo "[cha-os] minirootfs indiriliyor ($ALPINE_VER/$ARCH)..."
MINIROOT="alpine-minirootfs-3.20.0-$ARCH.tar.gz"
[ -f "$OUT/$MINIROOT" ] || wget -O "$OUT/$MINIROOT" "https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VER/releases/$ARCH/$MINIROOT"
rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
tar -xzf "$OUT/$MINIROOT" -C "$ROOTFS"

echo "[cha-os] profil paketleri + branding kopyalanıyor..."
cp -r branding "$ROOTFS/usr/share/chaos"
mkdir -p "$ROOTFS/usr/share/chaos/desktop"
cp profiles/desktop/xfce/chaos-xfce-defaults.sh "$ROOTFS/usr/share/chaos/desktop/" 2>/dev/null || true
cp profiles/desktop/lxqt/lxqt.conf "$ROOTFS/usr/share/chaos/desktop/" 2>/dev/null || true
cp profiles/desktop/sway/config "$ROOTFS/usr/share/chaos/desktop/sway-config" 2>/dev/null || true
cp branding/lightdm/lightdm-gtk-greeter.conf "$ROOTFS/usr/share/chaos/" 2>/dev/null || true
cp branding/sddm/sddm.conf "$ROOTFS/usr/share/chaos/sddm-chaos.conf" 2>/dev/null || true
cp branding/motd "$ROOTFS/etc/motd" 2>/dev/null || true
cp branding/issue "$ROOTFS/etc/issue" 2>/dev/null || true
cp cha-setup/cha-setup "$ROOTFS/usr/sbin/cha-setup"; chmod +x "$ROOTFS/usr/sbin/cha-setup"
cp cha-setup/cha-setup-install "$ROOTFS/usr/sbin/cha-setup-install"; chmod +x "$ROOTFS/usr/sbin/cha-setup-install"

echo "[cha-os] paket listesi: profiles/packages.$DESKTOP"
cat "profiles/packages.$DESKTOP" 2>/dev/null || echo "(uyarı: paket listesi yok, base kullanılacak)"

echo "[cha-os] rootfs tar + iso için hazır. ISO adımı Docker'da xorriso ile yapılır."
tar -czf "$OUT/chaos-$VERSION-$ARCH.tar.gz" -C "$ROOTFS" .
echo "[cha-os] OK: $OUT/chaos-$VERSION-$ARCH.tar.gz"
if [ "$MAKE_ISO" = "yes" ]; then
  echo "[cha-os] ISO üretiliyor..."
  if ! command -v apk >/dev/null 2>&1; then
    echo "[cha-os] UYARI: apk yok (Ubuntu/Windows). ISO için Alpine Docker kullanın:"
    echo "  docker run --rm -v \"\$PWD:/work\" -w /work alpine:3.20 sh tools/make-iso.sh --arch \"$ARCH\" --desktop \"$DESKTOP\" --version \"$VERSION\""
    exit 1
  fi
  sh tools/make-iso.sh --arch "$ARCH" --desktop "$DESKTOP" --version "$VERSION"
fi
