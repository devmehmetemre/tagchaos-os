# CHA OS — Alpine tabanlı minimal OS

Hedef: minimal, tam özelleştirilebilir, hafif + güçlü makinelerde hızlı Alpine tabanlı dağıtım.

## Yapı
- `build.sh` — minirootfs'ten rootfs + ISO imajı üretir (Docker + alpine-make-rootfs + xorriso)
- `cha-setup/` — `cha-setup` TUI kurulum aracı (POSIX sh + dialog)
- `profiles/` — mkimage profili ve paket listeleri
- `branding/` — MOTD, issue, os-release, wallpaper, GRUB teması, logo
- `kernel/` — hafifletilmiş kernel config fragmenti
- `.github/workflows/build.yml` — GitHub Actions ile otomatik derleme

## Hızlı Başlangıç (Windows + Docker)
```powershell
docker build -t chaos-builder -f Dockerfile.builder .
.\build.ps1
```

## Linux'ta
```sh
./build.sh --arch x86_64 --desktop xfce --version 1.0.0
```

Çıktı: `out/chaos-1.0.0-x86_64.iso` + `out/chaos-1.0.0-x86_64.tar.gz`
