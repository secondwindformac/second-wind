# vmdemo — scripted demo-video production from the test VM

Records marketing clips of the installed system (vmtest `target.qcow2`) headlessly,
with exact timing, then overlays Mac-style keystroke pills.

Pipeline (host only, no GUI):
1. Boot the VM with a QMP unix socket (see the vmtest notes; `-display none` is fine).
2. `demo.py SOCK clipN-*.txt OUTDIR DURATION` — replays the timeline (key/type/click/
   move/down/up) while grabbing QMP screendumps at ~12 fps into OUTDIR/f%05d.ppm.
3. `overlay.py OUTDIR DURATION "⌘ + Espacio|1.3|3.2" ...` — draws fading keystroke
   pills (DejaVu Sans Bold has U+2318) at the exact action times from the timeline.
4. `encode.sh OUTDIR out.webm 12 1` — VP8/WebM via GStreamer (no ffmpeg needed).

Gotchas learned the hard way:
- With Toshy active, the PHYSICAL Cmd key is QMP qcode `alt` (not `meta_l`).
- GNOME's built-in screencast is broken under virtio/llvmpipe (PipeWire format
  negotiation) — that is why we record via QMP screendump from the host.
- Warm up each app once before the take (first launch under llvmpipe ~6 s).
- The screen locks after ~5 min idle: send a `ctrl` tap before captures.
- QMP screendump does not compose the cursor plane (clips show no pointer).
- Burst QMP typing at 60 ms/char DROPS keys on this VM (spaces above all).
  90 ms (demo.py's pace) has never failed; 170 ms is bulletproof — use
  `slowtype.py` for setup/off-camera typing.
