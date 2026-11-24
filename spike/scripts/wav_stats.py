#!/usr/bin/env python3
"""Print RMS per 250 ms and the estimated fundamental of a 32-bit stereo WAV written by render_preset."""
import struct, sys, math
data = open(sys.argv[1], "rb").read()
n = struct.unpack_from("<I", data, 40)[0] // 4
s = struct.unpack_from(f"<{n}i", data, 44)
left = [v / 2**31 for v in s[0::2]]
sr = 44100
for i in range(0, len(left), sr // 4):
    w = left[i:i + sr // 4]
    rms = math.sqrt(sum(x * x for x in w) / max(1, len(w)))
    print(f"{i / sr:5.2f}s rms {20 * math.log10(rms) if rms else -999:7.1f} dBFS")
# strongest spectral peak, 20-2000 Hz in 1 Hz steps (Goertzel), on 0.4 s from 0.3 s
seg = left[int(0.3 * sr):int(0.7 * sr)]
def power(f):
    w = 2 * math.cos(2 * math.pi * f / sr); s1 = s2 = 0.0
    for x in seg:
        s1, s2 = x + w * s1 - s2, s1
    return s1 * s1 + s2 * s2 - w * s1 * s2
peaks = sorted(((power(f), f) for f in range(20, 2000)), reverse=True)[:3]
print("spectral peaks:", ", ".join(f"{f} Hz" for _, f in peaks))
