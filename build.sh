#!/bin/bash
set -e

BUILD_DIR="/tmp/tgh-build"
sudo rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/rootfs" "$BUILD_DIR/iso/boot/grub" "$BUILD_DIR/initramfs-root" dist

ALPINE_VER="3.20.3"
echo "[*] Alpine minirootfs indiriliyor..."
wget -q "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-${ALPINE_VER}-x86_64.tar.gz" -O alpine.tar.gz
tar -xzf alpine.tar.gz -C "$BUILD_DIR/rootfs"
rm alpine.tar.gz

# Paket Depoları
sudo cp /etc/resolv.conf "$BUILD_DIR/rootfs/etc/resolv.conf"
sudo bash -c "cat << 'EOF' > $BUILD_DIR/rootfs/etc/apk/repositories
https://dl-cdn.alpinelinux.org/alpine/v3.20/main
https://dl-cdn.alpinelinux.org/alpine/v3.20/community
EOF"

# Chroot Mount
sudo mount --bind /proc "$BUILD_DIR/rootfs/proc"
sudo mount --bind /sys "$BUILD_DIR/rootfs/sys"
sudo mount --bind /dev "$BUILD_DIR/rootfs/dev"

# Temel Sistem ve Disk/Boot Araçları
sudo chroot "$BUILD_DIR/rootfs" apk update
sudo chroot "$BUILD_DIR/rootfs" apk add --no-cache \
    linux-lts busybox e2fsprogs util-linux grub grub-bios rsync openrc iwd dialog \
    tzdata dbus shadow parted sfdisk neofetch bash mkinitfs \
    linux-firmware-intel linux-firmware-rtlwifi linux-firmware-ath10k linux-firmware-brcm

LTS_VER=$(ls "$BUILD_DIR/rootfs/lib/modules" | tail -n 1)
MOD_PATH="$BUILD_DIR/rootfs/lib/modules/$LTS_VER"

# Kurulum Betiğini Yerleştir
if [ -f tgh-install ]; then
    sudo cp tgh-install "$BUILD_DIR/rootfs/usr/local/bin/tgh-install"
    sudo chmod +x "$BUILD_DIR/rootfs/usr/local/bin/tgh-install"
fi

# Düz Metin Karşılama Ekranı (MOTD)
sudo bash -c "cat << 'EOF' > $BUILD_DIR/rootfs/etc/motd

=================================================================
             TAGCHAOS OS Universal Desktop System
=================================================================
  * Kurulumu başlatmak için : tgh-install
  * Wi-Fi bağlantısı için   : iwctl
  * Paket yöneticisi        : apk
=================================================================

EOF"

# Autologin
sudo tee "$BUILD_DIR/rootfs/usr/bin/autologin" << 'EOF'
#!/bin/sh
exec /bin/login -f root
EOF
sudo chmod +x "$BUILD_DIR/rootfs/usr/bin/autologin"
sudo sed -i 's|tty1::respawn:/sbin/getty.*|tty1::respawn:/sbin/getty -n -l /usr/bin/autologin 38400 tty1|' "$BUILD_DIR/rootfs/etc/inittab"

# Servisler
sudo chroot "$BUILD_DIR/rootfs" rc-update add iwd default 2>/dev/null || true
sudo chroot "$BUILD_DIR/rootfs" rc-update add dbus default 2>/dev/null || true

# Mount Temizliği
sudo umount "$BUILD_DIR/rootfs/proc" "$BUILD_DIR/rootfs/sys" "$BUILD_DIR/rootfs/dev"

# Çekirdek
sudo cp "$BUILD_DIR/rootfs/boot/vmlinuz-lts" "$BUILD_DIR/iso/boot/vmlinuz-lts"

# Rootfs Paketleme
echo "[*] System arşivi oluşturuluyor..."
sudo tar --exclude="./dev/*" --exclude="./proc/*" --exclude="./sys/*" \
         --exclude="./tmp/*" --exclude="./run/*" --exclude="./mnt/*" \
         --exclude="./boot/vmlinuz*" \
         -cJf "$BUILD_DIR/iso/system.tar.xz" -C "$BUILD_DIR/rootfs" .

# Live Initramfs Yapılandırması
INITRD_DIR="$BUILD_DIR/initramfs-root"
mkdir -p "$INITRD_DIR/bin" "$INITRD_DIR/sbin" "$INITRD_DIR/etc" "$INITRD_DIR/proc" \
         "$INITRD_DIR/sys" "$INITRD_DIR/dev" "$INITRD_DIR/mnt/cdrom" "$INITRD_DIR/lib"

sudo cp -a "$BUILD_DIR/rootfs/bin/busybox" "$INITRD_DIR/bin/"
sudo cp -a "$BUILD_DIR/rootfs/lib/ld-musl-"* "$INITRD_DIR/lib/" 2>/dev/null || true
sudo cp -a "$BUILD_DIR/rootfs/lib/libc.musl-"* "$INITRD_DIR/lib/" 2>/dev/null || true

sudo chroot "$INITRD_DIR" /bin/busybox --install -s || true

mkdir -p "$INITRD_DIR/lib/modules/$LTS_VER"
sudo cp -a "$MOD_PATH" "$INITRD_DIR/lib/modules/" || true

# Init Script
sudo tee "$INITRD_DIR/init" << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

modprobe ata_piix 2>/dev/null || true
modprobe ahci 2>/dev/null || true
modprobe sd_mod 2>/dev/null || true
modprobe sr_mod 2>/dev/null || true
modprobe virtio_blk 2>/dev/null || true
modprobe virtio_pci 2>/dev/null || true
modprobe nvme 2>/dev/null || true
modprobe usb_storage 2>/dev/null || true
modprobe isofs 2>/dev/null || true
modprobe ext4 2>/dev/null || true

mdev -s 2>/dev/null || true
sleep 2

FOUND_DEV=""
for dev in /dev/sr* /dev/sd* /dev/vd* /dev/nvme* /dev/cdrom; do
    [ -b "$dev" ] || continue
    mkdir -p /mnt/cdrom
    if mount -r "$dev" /mnt/cdrom 2>/dev/null; then
        if [ -f /mnt/cdrom/system.tar.xz ]; then
            FOUND_DEV="$dev"
            break
        fi
        umount /mnt/cdrom 2>/dev/null || true
    fi
done

if [ -n "$FOUND_DEV" ]; then
    mkdir -p /sysroot
    mount -t tmpfs -o size=85% tmpfs /sysroot
    tar -xf /mnt/cdrom/system.tar.xz -C /sysroot

    mkdir -p /sysroot/mnt/cdrom
    mount --move /mnt/cdrom /sysroot/mnt/cdrom
    mount --move /dev /sysroot/dev
    mount --move /proc /sysroot/proc
    mount --move /sys /sysroot/sys

    exec switch_root /sysroot /sbin/init
fi

exec /bin/sh
EOF
sudo chmod +x "$INITRD_DIR/init"

sudo bash -c "cd $INITRD_DIR && find . | cpio -o -H newc --owner=0:0 2>/dev/null | gzip -9 > $BUILD_DIR/iso/boot/initrd.img"

# GRUB Yapılandırması
cat << 'EOF' > "$BUILD_DIR/iso/boot/grub/grub.cfg"
set timeout=5
set default=0

insmod all_video
insmod gfxterm

menuentry "TAGCHAOS OS - Live Installer" {
    linux /boot/vmlinuz-lts quiet console=tty1
    initrd /boot/initrd.img
}
EOF

sudo chmod -R 755 "$BUILD_DIR/iso"
sudo grub-mkrescue -o dist/tagchaos-os.iso "$BUILD_DIR/iso"
sudo chown -R $USER:$USER dist/
