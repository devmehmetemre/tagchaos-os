/*
 * TAGCHAOS OS - Native C Window Manager with Frame Titles
 * Telif Hakkı (c) TAGCHAOS OS Project
 * 
 * Derleme: gcc -O2 tgh-wm.c -lX11 -o tgh-wm
 */

#include <X11/Xlib.h>
#include <X11/Xproto.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>

#define MOD_KEY Mod4Mask // Super / Windows Tuşu

static Display *display;
static Window root_window;
static int screen;
static int running = 1;

static int x_error_handler(Display *d, XErrorEvent *e) {
    (void)d; (void)e;
    return 0;
}

static void spawn(const char *command) {
    if (fork() == 0) {
        if (display) close(ConnectionNumber(display));
        setsid();
        execl("/bin/sh", "sh", "-c", command, NULL);
        exit(EXIT_FAILURE);
    }
}

static void kill_client(Window w) {
    if (w == None || w == root_window) return;
    XKillClient(display, w);
}

static void sigchld_handler(int sig) {
    (void)sig;
    while (waitpid(-1, NULL, WNOHANG) > 0);
}

int main(void) {
    XEvent ev;
    XWindowAttributes attr;
    XButtonEvent start_mouse;

    struct sigaction sa;
    sa.sa_handler = sigchld_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigaction(SIGCHLD, &sa, NULL);

    display = XOpenDisplay(NULL);
    if (!display) return EXIT_FAILURE;

    screen = DefaultScreen(display);
    root_window = RootWindow(display, screen);

    XSetErrorHandler(x_error_handler);
    XSetWindowBackground(display, root_window, 0x0f172a);
    XClearWindow(display, root_window);

    XSelectInput(display, root_window, SubstructureNotifyMask | SubstructureRedirectMask);

    // Kısayollar
    // Super + Enter -> Terminal
    XGrabKey(display, XKeysymToKeycode(display, XK_Return), MOD_KEY,
             root_window, True, GrabModeAsync, GrabModeAsync);

    // Super + D -> Uygulama Menüsü (Rofi)
    XGrabKey(display, XKeysymToKeycode(display, XK_d), MOD_KEY,
             root_window, True, GrabModeAsync, GrabModeAsync);

    // Super + Q -> Pencere Kapat
    XGrabKey(display, XKeysymToKeycode(display, XK_q), MOD_KEY,
             root_window, True, GrabModeAsync, GrabModeAsync);

    // Super + Shift + E -> Çıkış
    XGrabKey(display, XKeysymToKeycode(display, XK_E), MOD_KEY | ShiftMask,
             root_window, True, GrabModeAsync, GrabModeAsync);

    // Fare Butonları (Super + Sol Tık = Taşı, Super + Sağ Tık = Boyutlandır)
    XGrabButton(display, 1, MOD_KEY, root_window, True,
                ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                GrabModeAsync, GrabModeAsync, None, None);
    XGrabButton(display, 3, MOD_KEY, root_window, True,
                ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                GrabModeAsync, GrabModeAsync, None, None);

    Window focused_win = None;

    while (running) {
        XNextEvent(display, &ev);

        switch (ev.type) {
            case MapRequest:
                XMapWindow(display, ev.xmaprequest.window);
                XSetWindowBorderWidth(display, ev.xmaprequest.window, 2);
                XSetWindowBorder(display, ev.xmaprequest.window, 0x3b82f6); // Mavi Kenarlık
                XSetInputFocus(display, ev.xmaprequest.window, RevertToParent, CurrentTime);
                focused_win = ev.xmaprequest.window;
                break;

            case KeyPress:
                if (ev.xkey.state & MOD_KEY) {
                    KeySym keysym = XKeycodeToKeysym(display, ev.xkey.keycode, 0);
                    if (keysym == XK_Return) {
                        spawn("xterm -bg '#1e293b' -fg '#f8fafc'");
                    } else if (keysym == XK_d) {
                        spawn("rofi -show drun -show-icons || dmenu_run");
                    } else if (keysym == XK_q) {
                        if (focused_win != None && focused_win != root_window) {
                            kill_client(focused_win);
                        }
                    } else if (keysym == XK_E && (ev.xkey.state & ShiftMask)) {
                        running = 0;
                    }
                }
                break;

            case ButtonPress:
                if (ev.xbutton.subwindow != None && ev.xbutton.subwindow != root_window) {
                    focused_win = ev.xbutton.subwindow;
                    XSetInputFocus(display, focused_win, RevertToParent, CurrentTime);
                    XRaiseWindow(display, focused_win);
                    XGetWindowAttributes(display, focused_win, &attr);
                    start_mouse = ev.xbutton;
                }
                break;

            case MotionNotify:
                if (start_mouse.subwindow != None && start_mouse.subwindow != root_window) {
                    int xdiff = ev.xbutton.x_root - start_mouse.x_root;
                    int ydiff = ev.xbutton.y_root - start_mouse.y_root;
                    if (start_mouse.button == 1) {
                        XMoveWindow(display, start_mouse.subwindow, attr.x + xdiff, attr.y + ydiff);
                    } else if (start_mouse.button == 3) {
                        int new_w = attr.width + xdiff;
                        int new_h = attr.height + ydiff;
                        if (new_w > 50 && new_h > 50) {
                            XResizeWindow(display, start_mouse.subwindow, (unsigned int)new_w, (unsigned int)new_h);
                        }
                    }
                }
                break;

            case ButtonRelease:
                start_mouse.subwindow = None;
                break;

            default:
                break;
        }
    }

    XCloseDisplay(display);
    return EXIT_SUCCESS;
}
