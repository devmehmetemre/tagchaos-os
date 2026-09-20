#!/bin/sh

# Ekran Çözünürlüğü Otomatik Ayarı
xrandr --auto 2>/dev/null || true

# Arka Plan İşlemleri ve WM
exec /usr/local/bin/tgh-wm
