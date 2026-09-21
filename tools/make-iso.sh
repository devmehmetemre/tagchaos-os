#!/bin/sh
# CHA OS - bootable hibrit ISO üretici (Alpine live tarzı)
# Alpine container içinde root olarak çalışır. Harici bağımlılık: apk, grub-mkrescue/xorriso, mtools, squashfs-tools
# Kullanım: ./tools/make-iso.sh --arch x86_64 --desktop xfce --version 1.0.0
# Bu script SADECE Alpine içinde çalışır (apk gerekir).
# CI'da Ubuntu host üzerinde DEĞİL, `docker run alpine:3.22` içinde çağrılır.
# Bkz: .github/workflows/build.yml -> "Build ISO (Alpine Docker)"
set -eu
command -v apk >/dev/null 2>&1 || { echo "HATA: apk bulunamadı. Bu scripti Alpine Docker içinde çalıştırın:"; echo "  docker run --rm -v \"\$PWD:/work\" -w /work alpine:3.22 sh tools/make-iso.sh --arch x86_64 --desktop xfce"; exit 1; }

ARCH="x86_64"; DESKTOP="xfce"; VERSION="dev"
# NOT: repo sürümü pinlenmez; container imajı (alpine:3.22) ne ise o kullanılır.
# Bkz: .github/workflows/build.yml -> docker run alpine:3.22
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

echo "[iso] repolar (container):"
cat /etc/apk/repositories
apk update 2>&1 | tail -n 2

echo "[iso] kernel paketi seçiliyor..."
KPKG=""
for cand in linux-lts linux-virt; do
  if apk search -q -x "$cand" 2>/dev/null | grep -qx "$cand"; then KPKG="$cand"; break; fi
done
[ -n "$KPKG" ] || { echo "HATA: kernel paketi yok. Örnek arama:"; apk search -q "linux-" | head -n 20; exit 1; }
echo "[iso] kernel paketi: $KPKG"

PKGROOT="/tmp/chaos-pkgroot-$ARCH"
CACHE="$OUT/apkcache-$ARCH-$DESKTOP"
rm -rf "$PKGROOT" "$CACHE"; mkdir -p "$PKGROOT" "$CACHE"
# --root bootstrap yerine: apk fetch (container DB, imzalı) + tar ile aç.
# Neden: --root --initdb anahtar/repo sorunları çıkarıyor, fetch deterministik.
apk fetch -o "$CACHE" "$KPKG" 2>&1 | tail -n 2
ls "$CACHE"/$KPKG-*.apk >/dev/null 2>&1 || { echo "HATA: $KPKG indirilemedi"; ls -la "$CACHE"; exit 1; }
for f in "$CACHE"/*.apk; do tar -xzf "$f" -C "$PKGROOT"; done
KV=$(ls "$PKGROOT/lib/modules" 2>/dev/null | head -n1 || true)
[ -n "$KV" ] || { echo "HATA: modüller açılamadı"; find "$PKGROOT" -maxdepth 3 | head -n 20; exit 1; }
echo "[iso] kernel: $KV"
cp "$PKGROOT"/boot/vmlinuz-* "$ISO_ROOT/boot/vmlinuz"

echo "[iso] initramfs üretiliyor..."
apk add --no-cache mkinitfs squashfs-tools 2>&1 | tail -n 1
mkdir -p "$PKGROOT/etc/mkinitfs"
cat > "$PKGROOT/etc/mkinitfs/mkinitfs.conf" <<EOF
features="ata base ide keymap kms mmc nvme raid scsi usb virtio ext4 overlay squashfs"
EOF
mkinitfs -o "$ISO_ROOT/boot/initramfs" -b "$PKGROOT" "$KV" 2>&1 | tail -n 3
# modloop diye hazır paket YOK (Alpine resmi ISO da bunu derleme sırasında üretir).
# Biz de paketlenmiş modüllerden üretiyoruz:
echo "[iso] modloop üretiliyor (mksquashfs)..."
mksquashfs "$PKGROOT/lib/modules/$KV" "$ISO_ROOT/boot/modloop.squashfs" -comp xz -noappend 2>&1 | tail -n 2

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
