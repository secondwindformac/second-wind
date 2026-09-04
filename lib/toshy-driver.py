#!/usr/bin/env python3
"""Drive Toshy's interactive installer unattended (R10 blocker).

setup_toshy.py (pinned by TOSHY_SHA) guards steps with input() prompts.
`yes` answers the y/n ones but NOT the "attention" gates: those print a
random 4-letter secret code and demand it typed back, so feeding "y"
aborts the install ("Code does not match!") — exactly what the clean-VM
R10 run hit. There is no non-interactive flag, by design.

This driver runs the installer under a pty, mirrors its output untouched
(so toshy-install.log stays complete), remembers the LAST secret code seen
in the stream, and answers each prompt shape the pinned version has:

  •  "... enter the secret code 'XxYz': "            → the remembered code
  •  "Enter the secret code shown above ...: "       → the remembered code
  •  "... [y/n] / [y/N] / [Y/n]: "                   → y
  •  "Press Enter to continue ..."                   → newline

Answering the code gates is correct for our flow: they only confirm a
human read a notice (e.g. "the Xremap extension is not enabled in the
LIVE session") — and our firstboot reboots right after the install, which
is precisely what loads the extension. Usage:

    toshy-driver.py <command...>        # e.g. python3 setup_toshy.py install

Exit code = the installer's exit code (124 on inactivity stall).
"""
import os
import pty
import re
import select
import subprocess
import sys

CODE_RE = re.compile(r"secret code[^'\"]*['\"]([A-Za-z]{2,8})['\"]")
ASK_CODE_RE = re.compile(r"[Ee]nter the secret code[^:]*:\s*$")
ASK_YN_RE = re.compile(r"\[[yY]/[nN]\][^:]*:\s*$")
ASK_ENTER_RE = re.compile(r"Press Enter to continue[^\n]*$")
# Strip ANSI colors before matching (the installer uses fancy_str styling).
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

STALL_LIMIT = 300  # seconds with zero output → assume a prompt we missed


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: toshy-driver.py <command...>", file=sys.stderr)
        return 2

    master, slave = pty.openpty()
    proc = subprocess.Popen(
        sys.argv[1:], stdin=slave, stdout=slave, stderr=slave, close_fds=True
    )
    os.close(slave)

    buf = ""
    code = None
    stalled = 0.0
    while True:
        ready, _, _ = select.select([master], [], [], 1.0)
        if not ready:
            if proc.poll() is not None:
                break
            stalled += 1.0
            if stalled >= STALL_LIMIT:
                proc.kill()
                os.close(master)
                return 124
            continue
        stalled = 0.0
        try:
            chunk = os.read(master, 4096)
        except OSError:  # EIO when the child side closes — normal at exit
            chunk = b""
        if not chunk:
            if proc.poll() is not None:
                break
            continue
        sys.stdout.buffer.write(chunk)
        sys.stdout.flush()
        buf = (buf + chunk.decode(errors="replace"))[-4096:]
        text = ANSI_RE.sub("", buf)
        for match in CODE_RE.finditer(text):
            code = match.group(1)
        tail = text[-300:]
        answer = None
        if ASK_CODE_RE.search(tail):
            answer = code  # None → keep waiting; code always prints first
        elif ASK_YN_RE.search(tail):
            answer = "y"
        elif ASK_ENTER_RE.search(tail):
            answer = ""
        if answer is not None:
            os.write(master, (answer + "\n").encode())
            buf = ""  # consume the prompt so it is never answered twice

    os.close(master)
    proc.wait()
    return proc.returncode if proc.returncode is not None else 1


if __name__ == "__main__":
    sys.exit(main())
