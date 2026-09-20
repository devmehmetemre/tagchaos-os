CC = gcc
CFLAGS = -O2 -Wall -Wextra
LIBS = -lX11
PREFIX = /usr/local

all: tgh-wm

tgh-wm: tgh-wm.c
	$(CC) $(CFLAGS) tgh-wm.c $(LIBS) -o tgh-wm

install: tgh-wm
	install -Dm755 tgh-wm $(DESTDIR)$(PREFIX)/bin/tgh-wm

clean:
	rm -f tgh-wm

.PHONY: all install clean
