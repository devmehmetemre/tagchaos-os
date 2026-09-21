#!/bin/sh
# CHA OS live apkovl üretici: ISO açılışında uygulanacak overlay
# İçerik: hostname, motd, issue, autostart cha-setup, dark wallpaper referansı
# Kullanım: gen-apkovl.sh --arch x86_64 --desktop xfce --out out/apkovl.tar.gz
set -eu
ARCH="x86_64"; DESKTOP="xfce"; OUT="out/apkovl.tar.gz"
while [ $# -gt 0 ]; do case "$1" in
  --arch) ARCH="$2"; shift 2;; --desktop) DESKTOP="$2"; shift 2;;
  --out) OUT="$2"; shift 2;; *) shift;;
esac; done
TMP=$(mktemp -d)
HOST="chaos-live"
mkdir -p "$TMP/etc" "$TMP/root" "$TMP/usr/share/chaos" "$TMP/etc/profile.d" "$TMP/etc/runlevels/default"
echo "$HOST" > "$TMP/etc/hostname"
cp branding/motd "$TMP/etc/motd"
cp branding/issue "$TMP/etc/issue" 2>/dev/null || true
cp branding/os-release "$TMP/etc/os-release" 2>/dev/null || true
cp branding/wallpaper.svg "$TMP/usr/share/chaos/" 2>/dev/null || true
cp -r branding/icons "$TMP/usr/share/chaos/" 2>/dev/null || true
cp -r branding/themes "$TMP/usr/share/chaos/" 2>/dev/null || true
mkdir -p "$TMP/etc/skel" "$TMP/etc/lightdm" "$TMP/etc/sddm.conf.d"
# masaüstü varsayılanları overlay'e göm
sh profiles/desktop/xfce/chaos-xfce-defaults.sh "$TMP/etc/skel" 2>/dev/null || true
cp profiles/desktop/lxqt/lxqt.conf "$TMP/etc/skel/lxqt.conf" 2>/dev/null || true
mkdir -p "$TMP/etc/skel/.config/sway"
cp profiles/desktop/sway/config "$TMP/etc/skel/.config/sway/config" 2>/dev/null || true
cp branding/lightdm/lightdm-gtk-greeter.conf "$TMP/etc/lightdm/lightdm-gtk-greeter.conf" 2>/dev/null || true
cp branding/sddm/sddm.conf "$TMP/etc/sddm.conf.d/chaos.conf" 2>/dev/null || true
# live oturumda ilk konsolda cha-setup önerisi
cat > "$TMP/etc/profile.d/chaos-live.sh" <<EOF
# CHA OS live
if [ "\$(id -u)" -eq 0 ] && [ -z "\$CHAOS_LIVE_SEEN" ]; then
  export CHAOS_LIVE_SEEN=1
  cat /etc/motd
  echo ""
  echo "Kurmak için: cha-setup"
fi
EOF
# cha-setup + installer overlay'e göm
mkdir -p "$TMP/usr/sbin"
cp cha-setup/cha-setup "$TMP/usr/sbin/"; chmod +x "$TMP/usr/sbin/cha-setup"
cp cha-setup/cha-setup-install "$TMP/usr/sbin/"; chmod +x "$TMP/usr/sbin/cha-setup-install"
# openrc: live'da ağ + konsol
ln -sf /etc/init.d/networking "$TMP/etc/runlevels/default/" 2>/dev/null || true
tar -czf "$OUT" -C "$TMP" etc root usr
rm -rf "$TMP"
echo "[apkovl] OK: $OUT"
