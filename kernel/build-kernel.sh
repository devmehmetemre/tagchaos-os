#!/bin/sh
# CHA OS kernel derleme yardımcısı (CI + yerel)
# Kullanım: sh kernel/build-kernel.sh --arch x86_64
set -eu
ARCH="x86_64"
[ "${1:-}" = "--arch" ] && ARCH="$2"
echo "[kernel] $ARCH için config hazırlanıyor..."
# Alpine linux-lts base config'i çek (v3.20, 6.6 LTS)
BASE="https://git.alpinelinux.org/aports/plain/main/linux-lts/config-lts.$ARCH?id=v3.20.0"
wget -O "kernel/config-chaos.$ARCH" "$BASE" || {
  echo "(uyarı: base config indirilemedi, fragment tek başına kullanılacak)";
  cp kernel/config-chaos.fragment "kernel/config-chaos.$ARCH";
}
echo "[kernel] fragment birleştirme kontrolü:"
grep -c "^CONFIG_" kernel/config-chaos.fragment
echo "[kernel] APKBUILD hazır: kernel/APKBUILD (abuild -r ile derlenir)"
