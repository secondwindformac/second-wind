#!/bin/bash
# encode.sh FRAMEDIR OUT.webm FPS_NUM FPS_DEN
# Concats PPM frames (P6 1280x800) into raw RGB and encodes to VP8/WebM.
set -e
DIR="$1"; OUT="$2"; NUM="$3"; DEN="${4:-1}"
RAW="$DIR/all.rgb"
python3 - "$DIR" "$RAW" <<'EOF'
import glob, sys, os
d, raw = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(d, 'f*.ppm')))
with open(raw, 'wb') as out:
    for f in files:
        data = open(f, 'rb').read()
        # P6 header: "P6\n1280 800\n255\n" — find 3rd newline
        idx = 0
        for _ in range(3):
            idx = data.index(b'\n', idx) + 1
        pix = data[idx:]
        assert len(pix) == 1280*800*3, (f, len(pix))
        out.write(pix)
print('frames:', len(files))
EOF
gst-launch-1.0 -q filesrc location="$RAW" ! \
  rawvideoparse format=rgb width=1280 height=800 framerate="$NUM/$DEN" ! \
  videoconvert ! vp8enc deadline=1 cpu-used=5 target-bitrate=2500000 threads=4 keyframe-max-dist=30 ! \
  webmmux ! filesink location="$OUT"
rm -f "$RAW"
ls -la "$OUT"
