#!/usr/bin/env python3
"""Minimal QMP pilot for the Second Wind vmtest VM.
Usage: qmp.py SOCK CMD [args...]
  shot FILE.png          screendump (PNG)
  key k1 k2 ...          send-key combo (qcodes, e.g. ctrl alt f2 / ret / esc / meta_l spc)
  type "text"            type ASCII text (letters, digits, common symbols)
  click X Y [W H]        absolute click via usb-tablet (default screen 1280x800)
  wake                   tap ctrl to keep the screen unlocked (do before shot)
"""
import json, socket, sys, time

SHIFT = {c: k for c, k in zip('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')}
SHIFT.update({'!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7',
              '*': '8', '(': '9', ')': '0', '_': 'minus', '+': 'equal', '?': 'slash',
              ':': 'semicolon', '"': 'apostrophe', '<': 'comma', '>': 'dot', '~': 'grave_accent'})
PLAIN = {' ': 'spc', '-': 'minus', '=': 'equal', '.': 'dot', ',': 'comma', '/': 'slash',
         ';': 'semicolon', "'": 'apostrophe', '`': 'grave_accent', '\n': 'ret', '\t': 'tab'}

class Q:
    def __init__(self, path):
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(path)
        self.f = self.s.makefile('r')
        json.loads(self.f.readline())          # greeting
        self.cmd('qmp_capabilities')
    def cmd(self, name, **args):
        self.s.sendall((json.dumps({'execute': name, 'arguments': args}) + '\n').encode())
        while True:
            line = json.loads(self.f.readline())
            if 'return' in line or 'error' in line:
                if 'error' in line:
                    print('QMP error:', line['error'], file=sys.stderr)
                return line
    def keys(self, qcodes, hold=None):
        self.cmd('send-key', keys=[{'type': 'qcode', 'data': k} for k in qcodes],
                 **({'hold-time': hold} if hold else {}))
    def type(self, text):
        for ch in text:
            if ch in SHIFT: self.keys(['shift', SHIFT[ch]])
            elif ch.isalnum() and ch.lower() == ch: self.keys([ch])
            elif ch in PLAIN: self.keys([PLAIN[ch]])
            else: print('skip char', repr(ch), file=sys.stderr)
            time.sleep(0.06)
    def click(self, x, y, w=1280, h=800):
        ax, ay = int(x * 32767 / w), int(y * 32767 / h)
        mv = [{'type': 'abs', 'data': {'axis': 'x', 'value': ax}},
              {'type': 'abs', 'data': {'axis': 'y', 'value': ay}}]
        self.cmd('input-send-event', events=mv)
        time.sleep(0.15)
        self.cmd('input-send-event', events=[{'type': 'btn', 'data': {'button': 'left', 'down': True}}])
        time.sleep(0.08)
        self.cmd('input-send-event', events=[{'type': 'btn', 'data': {'button': 'left', 'down': False}}])

if __name__ == '__main__':
    sock, cmd, a = sys.argv[1], sys.argv[2], sys.argv[3:]
    q = Q(sock)
    if cmd == 'shot':
        q.keys(['ctrl'])                      # keep screen awake
        time.sleep(0.4)
        q.cmd('screendump', filename=a[0], format='png')
    elif cmd == 'key': q.keys(a)
    elif cmd == 'type': q.type(a[0])
    elif cmd == 'click': q.click(int(a[0]), int(a[1]), *(int(x) for x in a[2:]))
    elif cmd == 'wake': q.keys(['ctrl'])
    else: sys.exit('unknown cmd')
