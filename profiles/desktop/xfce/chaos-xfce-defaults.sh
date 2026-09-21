#!/bin/sh
# CHA OS XFCE varsayılanları: koyu tema + wallpaper + panel logosu + ikon paketi
# chroot içinde veya live overlay'de root olarak çalışır.
set -eu
USER_HOME="${1:-/etc/skel}"
mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="CHA-Dark"/>
    <property name="IconThemeName" type="string" value="chaos"/>
  </property>
</channel>
EOF
cat > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="image-path" type="string" value="/usr/share/chaos/wallpaper.svg"/>
    </property>
  </property>
</channel>
EOF
# whisker-menu / panel logosu: chaos-logo
mkdir -p "$USER_HOME/.config/xfce4/panel"
echo "chaos-logo" > "$USER_HOME/.config/xfce4/panel/whisker-logo.txt"
echo "[xfce] varsayılanlar -> $USER_HOME"
