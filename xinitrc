#!/bin/sh

# Ekran Çözünürlüğü Otomatik Ayarlama
xrandr --auto 2>/dev/null || true

# Arka Plan Rengi / Duvar Kağıdı (Koyu Mavi - Slate)
xsetroot -solid "#0f172a" 2>/dev/null || true

# Compositor (Pencere Gölgeleri ve Akıcılık)
picom -b 2>/dev/null || true

# Alt Görev Çubuğu ve Saat Panelini Başlat (tint2)
tint2 &

# Açılışta Ekran Ortasında Terminal Başlat
xterm -geometry 90x25+200+150 -bg "#1e293b" -fg "#f8fafc" -title "TAGCHAOS OS Terminal" &

# C Masaüstü Pencere Yöneticisini Başlat
exec /usr/local/bin/tgh-wm
