#!/usr/bin/env python3
"""Record a scripted demo from the vmtest VM via one QMP connection.

Usage: demo.py SOCK SCRIPT.txt OUTDIR DURATION [FPS]

SCRIPT.txt lines (t in seconds from start):
  <t> key k1 k2 ...
  <t> type <text ...>        (expanded to per-char keys, 90ms apart)
  <t> click X Y
  <t> move X Y
Blank lines and # comments ignored. Frames land in OUTDIR/f%05d.png.
Prints measured fps at the end.
"""
import json, os, socket, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qmp import Q, SHIFT, PLAIN


def parse_script(path):
    acts = []
    with open(path) as fh:
        for ln in fh:
            ln = ln.strip()
            if not ln or ln.startswith('#'):
                continue
            parts = ln.split()
            t = float(parts[0]); cmd = parts[1]; args = parts[2:]
            if cmd == 'type':
                text = ln.split(None, 2)[2]
                for i, ch in enumerate(text):
                    acts.append((t + i * 0.09, 'char', ch))
            else:
                acts.append((t, cmd, args))
    acts.sort(key=lambda a: a[0])
    return acts


def send_char(q, ch):
    if ch in SHIFT: q.keys(['shift', SHIFT[ch]])
    elif ch.isalnum() and ch.lower() == ch: q.keys([ch])
    elif ch in PLAIN: q.keys([PLAIN[ch]])
    else: print('skip char', repr(ch), file=sys.stderr)


def move(q, x, y, w=1280, h=800):
    ax, ay = int(x * 32767 / w), int(y * 32767 / h)
    q.cmd('input-send-event', events=[
        {'type': 'abs', 'data': {'axis': 'x', 'value': ax}},
        {'type': 'abs', 'data': {'axis': 'y', 'value': ay}}])


def keyevent(q, qcode, down):
    q.cmd('input-send-event', events=[
        {'type': 'key', 'data': {'down': down,
                                 'key': {'type': 'qcode', 'data': qcode}}}])


def wheel(q, direction):
    btn = 'wheel-down' if direction == 'down' else 'wheel-up'
    q.cmd('input-send-event', events=[{'type': 'btn', 'data': {'button': btn, 'down': True}}])
    q.cmd('input-send-event', events=[{'type': 'btn', 'data': {'button': btn, 'down': False}}])


def main():
    sock, script, outdir, dur = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
    fps = float(sys.argv[5]) if len(sys.argv) > 5 else 10.0
    os.makedirs(outdir, exist_ok=True)
    acts = parse_script(script)
    q = Q(sock)
    q.keys(['ctrl'])  # wake screen
    time.sleep(0.5)
    t0 = time.time()
    frame = 0
    ai = 0
    while True:
        now = time.time() - t0
        if now >= dur:
            break
        # dispatch due actions first
        while ai < len(acts) and acts[ai][0] <= now:
            _, cmd, a = acts[ai]; ai += 1
            try:
                if cmd == 'key': q.keys(a)
                elif cmd == 'char': send_char(q, a)
                elif cmd == 'click': q.click(int(a[0]), int(a[1]))
                elif cmd == 'move': move(q, int(a[0]), int(a[1]))
                elif cmd == 'down': keyevent(q, a[0], True)
                elif cmd == 'up': keyevent(q, a[0], False)
                elif cmd == 'wheel': wheel(q, a[0])
                elif cmd == 'bdown':
                    q.cmd('input-send-event', events=[{'type': 'btn', 'data': {'button': 'left', 'down': True}}])
                elif cmd == 'bup':
                    q.cmd('input-send-event', events=[{'type': 'btn', 'data': {'button': 'left', 'down': False}}])
            except Exception as e:
                print('action failed', cmd, a, e, file=sys.stderr)
        if now * fps >= frame:
            q.cmd('screendump',
                  filename=os.path.join(outdir, 'f%05d.ppm' % frame),
                  format='ppm')
            frame += 1
        time.sleep(0.004)
    real_fps = frame / dur
    print('frames=%d dur=%.1f real_fps=%.2f' % (frame, dur, real_fps))


if __name__ == '__main__':
    main()
