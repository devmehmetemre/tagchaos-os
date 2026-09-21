# CHA OS Windows derleme yardımcısı
docker build -t chaos-builder -f Dockerfile.builder .
docker run --rm -v "${PWD}:/work" chaos-builder sh ./build.sh --arch x86_64 --desktop xfce --version dev
Write-Host "Cikti: out/"
