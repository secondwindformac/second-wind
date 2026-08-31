#!/usr/bin/env python3
"""Type text into the VM slowly (default 170ms/char) over ONE QMP connection.
Usage: slowtype.py SOCK DELAY_MS "text" [ret|noret] [clearline]
clearline: send ctrl+u first to wipe any partial shell line.
"""
import sys, time, os
sys.path.insert(0, '/home/mas/Descargas/MacConLinux/scripts/vmdemo')
from qmp import Q, SHIFT, PLAIN

sock = sys.argv[1]
delay = float(sys.argv[2]) / 1000.0
text = sys.argv[3]
do_ret = len(sys.argv) > 4 and sys.argv[4] == 'ret'
clearline = 'clearline' in sys.argv[4:]

q = Q(sock)
q.keys(['ctrl'])  # wake
time.sleep(0.4)
if clearline:
    q.keys(['ctrl', 'u'])
    time.sleep(0.3)
for ch in text:
    if ch in SHIFT:
        q.keys(['shift', SHIFT[ch]])
    elif ch.isalnum() and ch.lower() == ch:
        q.keys([ch])
    elif ch in PLAIN:
        q.keys([PLAIN[ch]])
    else:
        print('skip char', repr(ch), file=sys.stderr)
    time.sleep(delay)
if do_ret:
    time.sleep(0.3)
    q.keys(['ret'])
print('typed ok')
