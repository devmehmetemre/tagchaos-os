#!/bin/sh
# CHA OS - bootable hibrit ISO üretici (Alpine live tarzı)
# Alpine container içinde root olarak çalışır. Harici bağımlılık: apk, grub-mkrescue/xorriso, mtools, squashfs-tools
# Kullanım: ./tools/make-iso.sh --arch x86_64 --desktop xfce --version 1.0.0
# Bu script SADECE Alpine içinde çalışır (apk gerekir).
# CI'da Ubuntu host üzerinde DEĞİL, `docker run alpine:3.22` içinde çağrılır.
# Bkz: .github/workflows/build.yml -> "Build ISO (Alpine Docker)"
set -eu
set -o pipefail 2>/dev/null || true  # borulu komut hatası yutulmasın (grub-mkrescue | tail)
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

echo "[iso] canlı repo hazırlanıyor (apks/$ARCH, resmi mkimage düzeni)..."
apk add --no-cache abuild 2>&1 | tail -n 1
# NOT: -i (install) doas ister, container'da yok. Anahtarı üretip pub'ı root olarak kopyala.
ls ~/.abuild/*.rsa >/dev/null 2>&1 || abuild-keygen -a -n </dev/null 2>&1 | tail -n 2
cp ~/.abuild/*.rsa.pub /etc/apk/keys/ 2>/dev/null || true
ls /etc/apk/keys/*.pub >/dev/null 2>&1 || { echo "HATA: abuild anahtarı üretilemedi"; exit 1; }
ADIR="$ISO_ROOT/apks/$ARCH"; mkdir -p "$ADIR"
# tek doğruluk kaynağı: apkovl world + masaüstü profili + kernel
# (chaos-*/lsblk gibi dosya/komut satırları repo filtresiyle elenir)
WORLD_PKGS=$(tar -xzOf "$APKVOL" etc/apk/world 2>/dev/null | grep -v -e '^#' -e '^$' | tr '\n' ' ')
DESK_PKGS=$(grep -v -e '^#' -e '^$' "profiles/packages.$DESKTOP" 2>/dev/null | grep -v -e '^chaos-' -e '^lsblk$' | tr '\n' ' ')
FETCH_LIST=""
for p in alpine-base linux-lts linux-virt linux-firmware-none $WORLD_PKGS $DESK_PKGS; do
  if apk search -q -x "$p" 2>/dev/null | grep -qx "$p"; then
    FETCH_LIST="$FETCH_LIST $p"
  else
    echo "(uyarı: $p repoda yok, atlanıyor)"
  fi
done
echo "[iso] repo paketleri:$FETCH_LIST"
apk fetch --recursive -o "$ADIR" $FETCH_LIST 2>&1 | tail -n 3
for p in $FETCH_LIST; do ls "$ADIR/$p"-*.apk >/dev/null 2>&1 || { echo "HATA: $p ISO reposunda yok"; exit 1; }; done
apk index --description "CHA OS $VERSION" --rewrite-arch "$ARCH" --index "$ADIR/APKINDEX.tar.gz" --output "$ADIR/APKINDEX.tar.gz" "$ADIR"/*.apk 2>&1 | tail -n 2
abuild-sign "$ADIR/APKINDEX.tar.gz" 2>&1 | tail -n 2
touch "$ISO_ROOT/apks/.boot_repository"
echo "[iso] repo: $(ls "$ADIR"/*.apk | wc -l) paket, APKINDEX imzalı"

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
# Kernel tek başına alınır (deps'leri sanal paket içerir, --recursive takılır).
apk fetch -o "$CACHE" "$KPKG" 2>&1 | tail -n 2
ls "$CACHE"/$KPKG-*.apk >/dev/null 2>&1 || { echo "HATA: $KPKG indirilemedi"; ls -la "$CACHE"; exit 1; }
# initramfs'in /init'i için mini-kök ŞART: busybox(sh), apk, nlplug-findfs, musl...
# (sadece kernel açılırsa initramfs'te /bin/sh olmaz -> "No working init found" paniği!)
echo "[iso] mini-kök indiriliyor (alpine-base+mkinitfs)..."
apk fetch --recursive -o "$CACHE" alpine-base mkinitfs 2>&1 | tail -n 2
for f in "$CACHE"/*.apk; do tar -xzf "$f" -C "$PKGROOT"; done
echo "[iso] PKGROOT: $(ls "$PKGROOT" | tr '\n' ' ') | sh: $(ls -l "$PKGROOT/bin/sh" 2>/dev/null || echo YOK)"
KV=$(ls "$PKGROOT/lib/modules" 2>/dev/null | head -n1 || true)
[ -n "$KV" ] || { echo "HATA: modüller açılamadı"; find "$PKGROOT" -maxdepth 3 | head -n 20; exit 1; }
echo "[iso] kernel: $KV"
FLAVOR=${KV##*-}
MODLOOP_FILE="modloop-$FLAVOR"
cp "$PKGROOT"/boot/vmlinuz-* "$ISO_ROOT/boot/vmlinuz"

echo "[iso] initramfs üretiliyor..."
apk add --no-cache mkinitfs squashfs-tools kmod 2>&1 | tail -n 1
# DİKKAT: mkinitfs, -b dizinindeki config'i DEĞİL -c ile verileni okur;
# features.d tanımlarını da -P ile host'tan almalıyız (basedir'de features.d yok).
MKCONF="$OUT/mkinitfs-$ARCH-$DESKTOP.conf"
# resmi profil seti (cdrom=ISO medyası, dhcp=ağ) + bizimkiler (overlay=canlı kök, kms/nvme)
MKFEATURES="ata base bootchart cdrom dhcp ext4 ide keymap kms mmc nvme overlay raid scsi squashfs usb virtio"
case "$ARCH" in x86_64) MKFEATURES="$MKFEATURES nfit";; aarch64|arm*) MKFEATURES="$MKFEATURES phy";; esac
cat > "$MKCONF" <<EOF
features="$MKFEATURES"
EOF
# mkinitfs initfs_apk_keys(): basedir'de etc/apk/keys varsa ama BOŞSA
# `cp .../*` patlar ve && zinciri exit 1 ile build'i öldürür.
# Host anahtarlarını önden kopyala: patlamayı önler + canlı boot
# apkovl doğrulaması için anahtarlar initramfs'e gömülür.
mkdir -p "$PKGROOT/etc/apk/keys"
cp /etc/apk/keys/* "$PKGROOT/etc/apk/keys/" 2>/dev/null || true
echo "[iso] apk anahtarları: $(ls "$PKGROOT/etc/apk/keys" | wc -l) adet"
MKLOG="$OUT/mkinitfs-$ARCH-$DESKTOP.log"
if mkinitfs -P /etc/mkinitfs/features.d -c "$MKCONF" -o "$ISO_ROOT/boot/initramfs" -b "$PKGROOT" "$KV" >"$MKLOG" 2>&1; then
  tail -n 3 "$MKLOG"
else
  echo "HATA: mkinitfs başarısız, tam log:"; cat "$MKLOG"; exit 1
fi
echo "[iso] initramfs içeriği (kritik dosyalar):"
mkdir -p /tmp/chk-initramfs && rm -rf /tmp/chk-initramfs/* && (cd /tmp/chk-initramfs && gzip -dc "$ISO_ROOT/boot/initramfs" 2>/dev/null | cpio -t 2>/dev/null | grep -E "^(\./)?(init|bin/sh|bin/busybox|sbin/nlplug-findfs|sbin/apk)" || echo "(liste alınamadı)")
# modloop diye hazır paket YOK (Alpine resmi ISO da bunu derleme sırasında üretir).
# Biz de paketlenmiş modüllerden üretiyoruz:
echo "[iso] modloop üretiliyor (mksquashfs -> $MODLOOP_FILE)..."
mksquashfs "$PKGROOT/lib/modules/$KV" "$ISO_ROOT/boot/$MODLOOP_FILE" -comp xz -noappend 2>&1 | tail -n 2

mkdir -p "$ISO_ROOT/chaos"
cp "$APKVOL" "$ISO_ROOT/chaos/apkovl.tar.gz"
# apkovl otomatik tespiti (*.apkovl.tar.gz taraması) kökte de bulsun diye kopya
cp "$APKVOL" "$ISO_ROOT/chaos-$VERSION.apkovl.tar.gz"
cp branding/wallpaper.svg "$ISO_ROOT/chaos/wallpaper.svg" 2>/dev/null || true

echo "[iso] grub.cfg yazılıyor..."
cat > "$ISO_ROOT/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0
# NOT: apkovl= ve modloop= parametresi YOK (bilerek).
# - apkovl: initramfs medya üzerindeki *.apkovl.tar.gz dosyasını otomatik bulur.
#   Göreli yol yazılırsa (apkovl=chaos/...) overlay HİÇ uygulanmaz!
# - modloop: chaos-modloop servisi medyadaki modloop-*.squashfs dosyasını bağlar.
# - modules=: gerekli modüller initramfs'teyken yüklenir, switch_root sonrası da durur.
menuentry "CHA OS $VERSION ($DESKTOP, live)" {
  linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage console=tty0
  initrd /boot/initramfs
}
menuentry "CHA OS (KMS, debug)" {
  linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage console=tty0 debug
  initrd /boot/initramfs
}
EOF

echo "[iso] hibrit ISO yazılıyor: $ISO_OUT"
case "$ARCH" in
  x86_64) GRUB_PKGS="grub grub-bios grub-efi";;  # bios=i386-pc (BIOS VM), efi=x86_64-efi (UEFI)
  *) GRUB_PKGS="grub grub-efi";;                 # aarch64: UEFI-only
esac
apk add --no-cache xorriso mtools dosfstools $GRUB_PKGS 2>&1 | tail -n 1
grub-mkrescue -o "$ISO_OUT" "$ISO_ROOT" -- -volid CHAOS 2>&1 | tail -n 5
ls -lh "$ISO_OUT"
echo "[iso] boot kaydı doğrulanıyor (El Torito)..."
xorriso -indev "$ISO_OUT" -report_el_torito as_mkisofs >"$OUT/eltorito.log" 2>&1 || true
cat "$OUT/eltorito.log"
# Asıl hüküm: El Torito spec'e göre 17. sektörde "EL TORITO SPECIFICATION" yazar.
if grep -qi "eltorito" "$OUT/eltorito.log" || dd if="$ISO_OUT" bs=2048 skip=17 count=1 2>/dev/null | grep -q "EL TORITO"; then
  echo "[iso] boot kaydı OK (BIOS+UEFI)"
else
  echo "HATA: ISO'da El Torito boot kaydı yok, bu ISO açılmaz"; exit 1
fi
echo "[iso] OK"
