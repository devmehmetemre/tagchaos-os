#!/bin/sh
# CHA OS - bootable hibrit ISO üretici (Alpine live tarzı)
# Alpine container içinde root olarak çalışır. Harici bağımlılık: apk, grub-mkrescue/xorriso, mtools, squashfs-tools
# Kullanım: ./tools/make-iso.sh --arch x86_64 --desktop xfce --version 1.0.0
set -eu

ARCH="x86_64"; DESKTOP="xfce"; VERSION="dev"; ALPINE_VER="v3.20"
while [ $# -gt 0 ]; do case "$1" in
  --arch) ARCH="$2"; shift 2;; --desktop) DESKTOP="$2"; shift 2;;
  --version) VERSION="$2"; shift 2;; *) shift;;
esac; done

OUT="out"; ISO_ROOT="$OUT/iso-$ARCH-$DESKTOP"; APKVOL="$OUT/apkovl-$ARCH.tar.gz"
ISO_OUT="$OUT/chaos-$VERSION-$ARCH-$DESKTOP.iso"
mkdir -p "$OUT" "$ISO_ROOT/boot/grub" "tools"

echo "[iso] live overlay hazırlanıyor..."
PROFILE_OVERLAY="profiles/live-overlay"
sh "$PROFILE_OVERLAY/gen-apkovl.sh" --arch "$ARCH" --desktop "$DESKTOP" --out "$APKVOL"

echo "[iso] kernel + initramfs alınıyor (apk)..."
PKGROOT="/tmp/chaos-pkgroot-$ARCH"
rm -rf "$PKGROOT"; mkdir -p "$PKGROOT"
# native arch varsayımı: CI'da arch'a uygun runner kullanılır (aarch64 -> arm runner)
apk add --no-cache --initdb --root "$PKGROOT" --repository "https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VER/main" \
  linux-lts 2>&1 | tail -n 3
KV=$(ls "$PKGROOT/lib/modules" | head -n1)
[ -n "$KV" ] || { echo "kernel bulunamadı"; exit 1; }
echo "[iso] kernel: $KV"
cp "$PKGROOT/boot/vmlinuz-lts" "$ISO_ROOT/boot/vmlinuz" 2>/dev/null || cp "$PKGROOT/boot/vmlinuz-$KV" "$ISO_ROOT/boot/vmlinuz"

echo "[iso] initramfs üretiliyor..."
apk add --no-cache mkinitfs 2>&1 | tail -n 1
mkdir -p "$PKGROOT/etc/mkinitfs"
cat > "$PKGROOT/etc/mkinitfs/mkinitfs.conf" <<EOF
features="ata base ide keymap kms mmc nvme raid scsi usb virtio ext4 overlay squashfs"
EOF
# modloop için gerekli modüller paketinden initramfs üret
mkinitfs -o "$ISO_ROOT/boot/initramfs" -b "$PKGROOT" "$KV" 2>&1 | tail -n 3
# modloop (canlı sistemin /lib/modules squashfs'i)
apk add --no-cache --root "$PKGROOT" --repository "https://dl-cdn.alpinelinux.org/alpine/$ALPINE_VER/main" linux-modloop-lts 2>&1 | tail -n 1
MODLOOP=$(ls "$PKGROOT"/lib/modloop*.squashfs "$PKGROOT"/boot/modloop* 2>/dev/null | head -n1 || true)
if [ -n "$MODLOOP" ]; then cp "$MODLOOP" "$ISO_ROOT/boot/modloop.squashfs"; else echo "(uyarı: modloop bulunamadı, canlı boot yine de denenir)"; fi

mkdir -p "$ISO_ROOT/chaos"
cp "$APKVOL" "$ISO_ROOT/chaos/apkovl.tar.gz"
cp branding/wallpaper.svg "$ISO_ROOT/chaos/wallpaper.svg" 2>/dev/null || true

echo "[iso] grub.cfg yazılıyor..."
cat > "$ISO_ROOT/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0
menuentry "CHA OS $VERSION ($DESKTOP, live)" {
  linux /boot/vmlinuz nomodeset apkovl=chaos/apkovl.tar.gz modloop=/boot/modloop.squashfs console=tty0
  initrd /boot/initramfs
}
menuentry "CHA OS (KMS, debug)" {
  linux /boot/vmlinuz apkovl=chaos/apkovl.tar.gz modloop=/boot/modloop.squashfs console=tty0 debug
  initrd /boot/initramfs
}
EOF

echo "[iso] hibrit ISO yazılıyor: $ISO_OUT"
apk add --no-cache xorriso grub grub-efi mtools dosfstools 2>&1 | tail -n 1
grub-mkrescue -o "$ISO_OUT" "$ISO_ROOT" -- -volid CHAOS 2>&1 | tail -n 5
ls -lh "$ISO_OUT"
echo "[iso] OK"
