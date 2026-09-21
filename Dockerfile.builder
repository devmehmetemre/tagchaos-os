FROM alpine:3.20
RUN apk add --no-cache wget tar gzip xorriso grub grub-efi mtools dosfstools parted e2fsprogs squashfs-tools
WORKDIR /work
COPY . /work
CMD ["sh", "./build.sh"]
