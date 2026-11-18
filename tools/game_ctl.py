"""Drive the running Limul Engine window: capture it and inject keyboard input.

Why this exists: the engine has no headless test path, and the only trustworthy signal for
"does this Lua/JSON actually work" is a real frame from the real exe. Screenshots alone are
not enough because most of the interesting state (missing atlases, thrown Lua errors) is
silent on screen -- so also read bin/logs/asset-issues.log after each step.

Usage:
    python tools/game_ctl.py shot [out.png]        full screen capture
    python tools/game_ctl.py win                   window geometry / foreground state
    python tools/game_ctl.py key <name> [...]      hold+release keys (VK-based SendInput)
    python tools/game_ctl.py tap <name> <count>    press/release a key count times with a gap
    python tools/game_ctl.py raw <vk_hex> <ms>     scancode SendInput, if VK is ignored

Keys are named like the game's own controls: LEFT RIGHT UP DOWN ENTER ESCAPE SPACE A B
LETTER_0..9 F1..F12.
"""

import sys
import time
import ctypes
import ctypes.wintypes as wt

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

INPUT_KEYBOARD = 1
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_SCANCODE = 0x0008

VK = {
    'LEFT': 0x25, 'UP': 0x26, 'RIGHT': 0x27, 'DOWN': 0x28,
    'ENTER': 0x0D, 'RETURN': 0x0D, 'ESCAPE': 0x1B, 'ESC': 0x1B, 'SPACE': 0x20,
    'BACKSPACE': 0x08, 'TAB': 0x09, 'SHIFT': 0x10, 'CONTROL': 0x11, 'ALT': 0x12,
    'DELETE': 0x2E, 'HOME': 0x24, 'END': 0x23, 'PAGEUP': 0x21, 'PAGEDOWN': 0x22,
    'A': 0x41, 'B': 0x42, 'C': 0x43, 'D': 0x44, 'E': 0x45, 'F': 0x46, 'G': 0x47,
    'H': 0x48, 'I': 0x49, 'J': 0x4A, 'K': 0x4B, 'L': 0x4C, 'M': 0x4D, 'N': 0x4E,
    'O': 0x4F, 'P': 0x50, 'Q': 0x51, 'R': 0x52, 'S': 0x53, 'T': 0x54, 'U': 0x55,
    'V': 0x56, 'W': 0x57, 'X': 0x58, 'Y': 0x59, 'Z': 0x5A,
    'F1': 0x70, 'F2': 0x71, 'F3': 0x72, 'F4': 0x73, 'F5': 0x74, 'F6': 0x75,
    'F7': 0x76, 'F8': 0x77, 'F9': 0x78, 'F10': 0x79, 'F11': 0x7A, 'F12': 0x7B,
}
for _i in range(10):
    VK['LETTER_%d' % _i] = VK['0123456789'[_i]] = 0x30 + _i

# scan code set 1, for the KEYEVENTF_SCANCODE fallback
SCAN = {
    'LEFT': 0x4B, 'UP': 0x48, 'RIGHT': 0x4D, 'DOWN': 0x50,
    'ENTER': 0x1C, 'ESCAPE': 0x01, 'SPACE': 0x39,
}


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [('wVk', wt.WORD), ('wScan', wt.WORD), ('dwFlags', wt.DWORD),
                ('time', wt.DWORD), ('dwExtraInfo', ctypes.c_void_p)]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [('biSize', wt.DWORD), ('biWidth', ctypes.c_long),
                ('biHeight', ctypes.c_long), ('biPlanes', wt.WORD),
                ('biBitCount', wt.WORD), ('biCompression', wt.DWORD),
                ('biSizeImage', wt.DWORD), ('biXPelsPerMeter', ctypes.c_long),
                ('biYPelsPerMeter', ctypes.c_long), ('biClrUsed', wt.DWORD),
                ('biClrImportant', wt.DWORD)]


class INPUT(ctypes.Structure):
    class _U(ctypes.Union):
        _fields_ = [('ki', KEYBDINPUT)]
    _anonymous_ = ('u',)
    _fields_ = [('type', wt.DWORD), ('u', _U)]


def _send(vk, scan, flags):
    inp = INPUT(type=INPUT_KEYBOARD)
    inp.wVk = vk
    inp.wScan = scan
    inp.dwFlags = flags
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))


def foreground_title():
    h = user32.GetForegroundWindow()
    n = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(h, n, 512)
    return h, n.value


def require_game():
    """Refuse to type into whatever else the user has focused: the keyboard state is shared,
    and a blind ESCAPE storm once quit the game and landed in a browser."""
    h, name = foreground_title()
    low = (name or '').lower()
    if 'limul' not in low and 'funkin' not in low:
        raise SystemExit('foreground is %r (hwnd=%d) -- not the game, refusing to send keys'
                         % (name, h))
    return h


def press(name, hold=0.06, scancode=False):
    require_game()
    vk = VK.get(name.upper())
    if vk is None:
        raise SystemExit('unknown key %r' % name)
    if scancode:
        scan = SCAN.get(name.upper())
        if scan is None:
            raise SystemExit('no scan code mapped for %r' % name)
        _send(0, scan, KEYEVENTF_SCANCODE)
        time.sleep(hold)
        _send(0, scan, KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP)
    else:
        _send(vk, 0, 0)
        time.sleep(hold)
        _send(vk, 0, KEYEVENTF_KEYUP)


EXTENDED = {'LEFT', 'UP', 'RIGHT', 'DOWN', 'INSERT', 'DELETE', 'HOME', 'END',
            'PAGEUP', 'PAGEDOWN'}


def post_key(name, hold=0.05):
    """PostMessage fallback: SendInput only reaches the window the OS thinks is focused,
    and a background-launched game often never gets that, so the keys just vanish."""
    key = name.upper()
    vk = VK.get(key)
    if vk is None:
        raise SystemExit('unknown key %r' % name)
    scan = SCAN.get(key, 0)
    hwnd = require_game()
    lparam = (scan << 16) | 1
    if key in EXTENDED:
        lparam |= 0x01000000  # KF_EXTENDED -- arrows/home/end/... are E0 make codes
    user32.PostMessageW(hwnd, 0x0100, vk, lparam)               # WM_KEYDOWN
    time.sleep(hold)
    user32.PostMessageW(hwnd, 0x0101, vk, lparam | 0xC0000000)  # WM_KEYUP
    if vk == 0x0D:
        user32.PostMessageW(hwnd, 0x0102, 0x0D, 0)              # WM_CHAR, some toolkits need it
    print('posted', name, 'to hwnd=%d lp=0x%08X' % (hwnd, lparam))


def activate_window(title_part='Limul'):
    hwnd = user32.FindWindowW(None, title_part)
    found = []
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)

    def cb(h, l):
        if user32.IsWindowVisible(h):
            n = ctypes.create_unicode_buffer(512)
            user32.GetWindowTextW(h, n, 512)
            if n.value:
                found.append((h, n.value))
        return True

    user32.EnumWindows(EnumWindowsProc(cb), 0)
    for h, name in found:
        if title_part.lower() in name.lower() or 'funkin' in name.lower():
            user32.ShowWindow(h, 9)  # SW_RESTORE
            user32.SetForegroundWindow(h)
            user32.SetFocus(h)
            print('focused hwnd=%d title=%r' % (h, name))
            return h
    print('no game window found; visible titles:')
    for h, name in found[:25]:
        print('   %r' % name)
    return None


def window_info():
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)
    out = []

    def cb(h, l):
        if not user32.IsWindowVisible(h):
            return True
        n = ctypes.create_unicode_buffer(512)
        user32.GetWindowTextW(h, n, 512)
        if not n.value:
            return True
        if 'limul' in n.value.lower() or 'funkin' in n.value.lower():
            r = wt.RECT()
            user32.GetWindowRect(h, ctypes.byref(r))
            fg = user32.GetForegroundWindow()
            out.append((h, n.value, (r.left, r.top, r.right, r.bottom), fg == h))
        return True

    user32.EnumWindows(EnumWindowsProc(cb), 0)
    for h, name, rect, focused in out:
        print('hwnd=%d title=%r rect=%s foreground=%s' % (h, name, rect, focused))
    if not out:
        print('no game window')
    return out


def screenshot(path):
    """BitBlt the primary screen. Returns the path; black image means the game is in an
    exclusive-mode surface and PrintWindow is needed instead."""
    SM_XRES = 0
    SM_YRES = 1
    SRCCOPY = 0x00CC0020
    w = user32.GetSystemMetrics(SM_XRES)
    h = user32.GetSystemMetrics(SM_YRES)
    hdc = user32.GetDC(0)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mem, bmp)
    gdi32.BitBlt(mem, 0, 0, w, h, hdc, 0, 0, SRCCOPY)

    bmi = BITMAPINFOHEADER()
    bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bmi.biWidth = w
    bmi.biHeight = -h  # top-down
    bmi.biPlanes = 1
    bmi.biBitCount = 24
    bmi.biCompression = 0
    buf = ctypes.create_string_buffer(w * h * 4)
    got = gdi32.GetDIBits(hdc, bmp, 0, h, buf, ctypes.byref(bmi), 0)
    if got == 0:
        raise SystemExit('GetDIBits returned 0 -- capture failed')
    stride = ((w * 3 + 3) // 4) * 4
    rows = bytearray()
    for y in range(got):
        start = y * stride
        row = bytearray(buf.raw[start:start + w * 3])
        row[0::3], row[2::3] = row[2::3], row[0::3]  # BGR -> RGB
        rows += row
    write_png(path, w, got, bytes(rows))
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(0, hdc)
    print('wrote %s (%dx%d)' % (path, w, got))
    return path


def write_png(path, w, h, rgb):
    """Minimal PNG writer (no zlib compress object needed -- use the builtin)."""
    import zlib
    raw = b''.join(b'\x00' + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    def chunk(tag, data):
        c = tag + data
        return (len(data)).to_bytes(4, 'big') + c + (
            __import__('binascii').crc32(c) & 0xffffffff).to_bytes(4, 'big')
    import binascii
    ihdr = w.to_bytes(4, 'big') + h.to_bytes(4, 'big') + bytes([8, 2, 0, 0, 0])
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr)
           + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)


PW_RENDERFULLCONTENT = 0x00000002


def find_windows(title_part='limul'):
    found = []
    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)

    def cb(h, l):
        if user32.IsWindowVisible(h):
            n = ctypes.create_unicode_buffer(512)
            user32.GetWindowTextW(h, n, 512)
            if n.value and title_part.lower() in n.value.lower():
                r = wt.RECT()
                user32.GetWindowRect(h, ctypes.byref(r))
                found.append((h, n.value, (r.right - r.left) * (r.bottom - r.top)))
        return True

    user32.EnumWindows(EnumWindowsProc(cb), 0)
    found.sort(key=lambda t: t[2], reverse=True)
    return found


def window_screenshot(hwnd, path):
    """PrintWindow capture -- BitBlt returns black for the engine's GL surface."""
    r = wt.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    w, h = r.right - r.left, r.bottom - r.top
    if w <= 0 or h <= 0:
        raise SystemExit('bad window rect %r' % ((w, h),))
    hdc = user32.GetWindowDC(hwnd)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mem, bmp)
    ok = user32.PrintWindow(hwnd, mem, PW_RENDERFULLCONTENT)

    bmi = BITMAPINFOHEADER()
    bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bmi.biWidth = w
    bmi.biHeight = -h
    bmi.biPlanes = 1
    bmi.biBitCount = 24
    bmi.biCompression = 0
    buf = ctypes.create_string_buffer(w * h * 4)
    got = gdi32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bmi), 0)
    if got == 0:
        raise SystemExit('GetDIBits returned 0 -- capture failed')
    stride = ((w * 3 + 3) // 4) * 4
    rows = bytearray()
    for y in range(got):
        start = y * stride
        row = bytearray(buf.raw[start:start + w * 3])
        row[0::3], row[2::3] = row[2::3], row[0::3]
        rows += row
    write_png(path, w, got, bytes(rows))
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(hwnd, hdc)
    print('wrote %s (%dx%d) printwindow=%s' % (path, w, got, bool(ok)))
    return ok


def force_foreground(hwnd):
    """SetForegroundWindow is refused while another app owns the foreground. Tapping ALT
    first makes this process the last input provider, which lifts that restriction."""
    user32.ShowWindow(hwnd, 9)
    _send(0x12, 0, 0)   # ALT down
    _send(0x12, 0, KEYEVENTF_KEYUP)
    time.sleep(0.05)
    fg = user32.GetForegroundWindow()
    fg_tid = user32.GetWindowThreadProcessId(fg, None)
    my_tid = ctypes.windll.kernel32.GetCurrentThreadId()
    if fg_tid != my_tid:
        user32.AttachThreadInput(my_tid, fg_tid, True)
    user32.BringWindowToTop(hwnd)
    user32.SetForegroundWindow(hwnd)
    user32.SetFocus(hwnd)
    if fg_tid != my_tid:
        user32.AttachThreadInput(my_tid, fg_tid, False)
    now = user32.GetForegroundWindow()
    print('hwnd=%d foreground now=%d %s' % (hwnd, now, 'OK' if now == hwnd else 'STILL NOT FOREGROUND'))


def post_to(hwnd, name, hold=0.05):
    """PostMessage WM_KEYDOWN/UP straight to the window -- works even unfocused."""
    key = name.upper()
    vk = VK.get(key)
    if vk is None:
        raise SystemExit('unknown key %r' % name)
    scan = SCAN.get(key, 0)
    lparam = (scan << 16) | 1
    if key in EXTENDED:
        lparam |= 0x01000000
    user32.PostMessageW(hwnd, 0x0100, vk, lparam)
    time.sleep(hold)
    user32.PostMessageW(hwnd, 0x0101, vk, lparam | 0xC0000000)
    if vk == 0x0D:
        user32.PostMessageW(hwnd, 0x0102, 0x0D, 0)
    print('posted', name, 'to hwnd=%d lp=0x%08X' % (hwnd, lparam))


def main(argv):
    if not argv:
        raise SystemExit(__doc__)
    cmd = argv[0]
    if cmd == 'shot':
        out = argv[1] if len(argv) > 1 else 'shot.png'
        screenshot(out)
    elif cmd == 'win':
        window_info()
    elif cmd == 'pshot':
        target = argv[1] if len(argv) > 1 else 'Limul'
        out = argv[2] if len(argv) > 2 else 'shot.png'
        if target.isdigit():
            hwnd = int(target)
        else:
            wins = find_windows(target)
            if not wins:
                raise SystemExit('no window matching %r' % target)
            hwnd = wins[0][0]
            print('target hwnd=%d title=%r' % (hwnd, wins[0][1]))
        window_screenshot(hwnd, out)
    elif cmd == 'focushwnd':
        force_foreground(int(argv[1]))
    elif cmd == 'posth':
        hwnd = int(argv[1])
        for name in argv[2:]:
            post_to(hwnd, name)
            time.sleep(0.2)
    elif cmd == 'focus':
        activate_window(argv[1] if len(argv) > 1 else 'Limul')
    elif cmd == 'key':
        sc = '--scancode' in argv
        for name in [a for a in argv[1:] if not a.startswith('--')]:
            press(name, scancode=sc)
            print('key', name, 'scancode' if sc else 'vk')
    elif cmd == 'tap':
        name, count = argv[1], int(argv[2])
        gap = float(argv[3]) if len(argv) > 3 else 0.28
        sc = '--scancode' in argv
        for i in range(count):
            press(name, scancode=sc)
            print('tap %d/%d %s' % (i + 1, count, name))
            time.sleep(gap)
    elif cmd == 'post':
        for name in argv[1:]:
            post_key(name)
            time.sleep(0.15)
    elif cmd == 'sleep':
        time.sleep(float(argv[1]))
        print('slept', argv[1])
    else:
        raise SystemExit('unknown command %r' % cmd)


if __name__ == '__main__':
    main(sys.argv[1:])
