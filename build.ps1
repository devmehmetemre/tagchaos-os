# CHA OS Windows derleme yardımcısı (2 aşama: rootfs host'ta, ISO Alpine Docker'da)
docker build -t chaos-builder -f Dockerfile.builder .
docker run --rm -v "${PWD}:/work" -w /work chaos-builder sh ./build.sh --arch x86_64 --desktop xfce --version dev
docker run --rm -v "${PWD}:/work" -w /work alpine:3.22 sh tools/make-iso.sh --arch x86_64 --desktop xfce --version dev
Write-Host "Cikti: out/"
