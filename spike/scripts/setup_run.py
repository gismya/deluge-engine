#!/usr/bin/env python3
"""Issue #42 spike: render Setups built in memory (spike/host/drivers/setup_engine.cpp) and check them.

    python3 spike/scripts/setup_run.py [--card IMG] [--card-us 300:40] [--only routing|swap|audition]

Writes scripts to build/setup-scripts/, renders to ~/.cache/deluge-engine/notes/setup-wav/ (factory content: never
commit them), and prints the numbers spike/setup-findings.md quotes. Every Engine run has a wall-clock timeout.
Pure Python (no numpy on this machine), so the checks take a minute or two.
"""
import argparse
import math
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ENGINE = os.path.join(ROOT, "build", "setup_engine")
SCRIPTS = os.path.join(ROOT, "build", "setup-scripts")
WAVS = os.path.expanduser("~/.cache/deluge-engine/notes/setup-wav")
SR = 44100

ORGAN = "SYNTHS/026 PW Organ.XML"
SOFT = "SYNTHS/025 Soft Synth Organ.XML"
KIT = "KITS/000 TR-808.XML"
SAW = "SYNTHS/020 Soft Saw Lead.XML"
DBASS = "SYNTHS/169 Double Bass.XML"
STRINGS = "SYNTHS/131 Warm Strings.XML"

opts = None


def render(name, lines, card_us=None, flags=()):
    os.makedirs(SCRIPTS, exist_ok=True)
    os.makedirs(WAVS, exist_ok=True)
    script = os.path.join(SCRIPTS, name + ".txt")
    with open(script, "w") as f:
        f.write("\n".join(lines) + "\n")
    out = os.path.join(WAVS, name + ".wav")
    env = dict(os.environ, DELUGE_SD_IMAGE=opts.card)
    cmd = [ENGINE, "--script", script, "--out", out, "--card-us", card_us or opts.card_us, *flags]
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=120)
    if r.returncode != 0 or "wrote" not in r.stderr:
        sys.exit(f"{name}: engine failed rc={r.returncode}\n{r.stderr[-3000:]}")
    return read_wav(out), r.stderr


def read_wav(path):
    data = open(path, "rb").read()
    n = struct.unpack_from("<I", data, 40)[0] // 4
    s = struct.unpack_from(f"<{n}i", data, 44)
    return [v / 2**31 for v in s]  # interleaved L R


def db(x):
    return 20 * math.log10(x) if x > 0 else -999.0


def rms(xs):
    return math.sqrt(sum(x * x for x in xs) / len(xs)) if xs else 0.0


def seg(a, t0, t1):
    return a[2 * int(t0 * SR):2 * int(t1 * SR)]


def residual(a, b, t0=0.0, t1=None):
    """Level of a - b against the level of a, over [t0, t1): (residual dBFS, signal dBFS, max |a-b|)."""
    n = min(len(a), len(b))
    i0, i1 = 2 * int(t0 * SR), min(n, 2 * int(t1 * SR)) if t1 else n
    d = [a[i] - b[i] for i in range(i0, i1)]
    return db(rms(d)), db(rms(a[i0:i1])), max((abs(x) for x in d), default=0.0)


def add(*xs):
    n = min(len(x) for x in xs)
    return [sum(x[i] for x in xs) for i in range(n)]


def sub(a, b):
    n = min(len(a), len(b))
    return [a[i] - b[i] for i in range(n)]


def f0(a, t0, dur=0.1, lo=40, hi=1500):
    """Fundamental by normalised autocorrelation of the left channel: the first lag whose correlation is within 10%
    of the best (so octave errors go to the fundamental's period, not a multiple)."""
    x = seg(a, t0, t0 + dur)[0::2]
    m = sum(x) / len(x)
    x = [v - m for v in x]
    e = sum(v * v for v in x) or 1
    lags = range(int(SR / hi), int(SR / lo))
    r = {k: sum(x[i] * x[i + k] for i in range(len(x) - k)) / e for k in lags}
    # local maxima only
    peaks = [k for k in lags if k - 1 in r and k + 1 in r and r[k] >= r[k - 1] and r[k] >= r[k + 1]]
    if not peaks:
        return 0.0
    best = max(r[k] for k in peaks)
    k = next(k for k in peaks if r[k] >= 0.9 * best)
    # parabolic interpolation
    y0, y1, y2 = r[k - 1], r[k], r[k + 1]
    den = y0 - 2 * y1 + y2
    frac = 0.5 * (y0 - y2) / den if den else 0.0
    return SR / (k + frac)


def env10(a, t0, t1):
    """RMS per 10 ms window (both channels), dBFS."""
    out = []
    t = t0
    while t < t1 - 1e-9:
        out.append((round(t, 3), db(rms(seg(a, t, t + 0.01)))))
        t += 0.01
    return out


def goertzel(x, f, hann=False):
    w = 2 * math.cos(2 * math.pi * f / SR)
    s1 = s2 = 0.0
    n = len(x)
    if hann:  # Hann window: far less leakage from loud neighbours, amplitude scaled back up by 2
        x = [v * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1))) * 2 for i, v in enumerate(x)]
    for v in x:
        s1, s2 = v + w * s1 - s2, s1
    return math.sqrt(max(0.0, s1 * s1 + s2 * s2 - w * s1 * s2)) * 2 / n


def harmonics(a, t0, hz, n=8, dur=0.2):
    """Levels (dBFS) of the first n harmonics of hz on the left channel over [t0, t0 + dur)."""
    x = seg(a, t0, t0 + dur)[0::2]
    return [db(goertzel(x, hz * k)) for k in range(1, n + 1)]


def env_delta(a, b, t0, t1, win=0.05, floor=-60):
    """Largest level difference (dB) between a and b over win-long windows in [t0, t1) where a is above floor."""
    worst = 0.0
    t = t0
    while t < t1 - 1e-9:
        la, lb = db(rms(seg(a, t, t + win))), db(rms(seg(b, t, t + win)))
        if la > floor:
            worst = max(worst, abs(la - lb))
        t += win
    return worst


def voices(log):
    return [int(m) for m in re.findall(r"voices (\d+) at", log)]


def timings(log):
    return [l.strip() for l in log.splitlines() if " took " in l]


# ---- 1. Routing


def routing():
    print("\n## 1. Routing: one instrument per channel\n")
    binds = {1: f"0.2 bind 1 {ORGAN}", 2: f"0.2 bind 2 {SOFT}", 10: f"0.2 bind 10 {KIT} 36"}
    notes = {
        1: ["1.0 on 1 45", "2.0 off 1 45", "2.5 on 1 52", "3.0 off 1 52"],
        2: ["1.5 on 2 63", "2.5 off 2 63", "3.0 on 2 70", "3.5 off 2 70"],
        10: ["1.2 on 10 36", "1.25 off 10 36", "1.7 on 10 38", "1.75 off 10 38", "2.2 on 10 42", "2.25 off 10 42",
             "2.7 on 10 36", "2.75 off 10 36"],
    }
    end = ["5.0 end"]
    allb = list(binds.values())
    alone, bound_all, logs = {}, {}, {}
    for ch in (1, 2, 10):
        alone[ch], la = render(f"r_alone_{ch}", [binds[ch]] + notes[ch] + end)
        bound_all[ch], lb = render(f"r_allbound_{ch}", allb + notes[ch] + end)
        logs[ch] = (voices(la), voices(lb))
    together, log = render("r_together", allb + notes[1] + notes[2] + notes[10] + end)
    quiet, _ = render("r_quiet", allb + end)
    unbound, logu = render("r_unbound", allb + ["1.0 on 5 60", "1.5 off 5 60", "2.0 on 3 48", "2.5 off 3 48",
                                                "3.0 on 16 72", "3.5 off 16 72"] + end)
    for t in timings(log):
        print("   ", t)
    print("\nEach channel's notes with only its own preset bound (alone) vs with all three bound:")
    print("  voice counts over the render (every change), alone / all bound:")
    for ch in (1, 2, 10):
        print(f"    ch {ch:2d}: {logs[ch][0]} / {logs[ch][1]}")
    for ch in (1, 2, 10):
        r, sg, mx = residual(bound_all[ch], alone[ch], 0.9)
        print(f"  ch {ch:2d}: signal {sg:6.1f} dBFS; 50 ms level envelope differs by at most "
              f"{env_delta(alone[ch], bound_all[ch], 0.9, 5.0):.2f} dB (windows above -60 dBFS); sample difference "
              f"{r:.1f} dBFS (the LFOs and render windows start at other times, so samples don't line up)")
    print("  per note: f0 by autocorrelation 0.2-0.3 s after note-on, level 0.1-0.4 s, harmonics 1-8 (0.2-0.4 s), "
          "alone / all bound:")
    for ch, t, note in ((1, 1.0, 45), (1, 2.5, 52), (2, 1.5, 63), (2, 3.0, 70)):
        hz = 440 * 2 ** ((note - 69) / 12)
        a, b = f0(alone[ch], t + 0.2), f0(bound_all[ch], t + 0.2)
        # harmonics of the measured f0 (Soft Synth Organ's oscillators are transposed up an octave)
        ha, hb = harmonics(alone[ch], t + 0.2, a), harmonics(bound_all[ch], t + 0.2, a)
        dh = max(abs(x - y) for x, y in zip(ha, hb) if x > -60)
        print(f"    ch {ch} note {note} ({hz:.1f} Hz): f0 {a:.1f} / {b:.1f} Hz; level "
              f"{db(rms(seg(alone[ch], t + 0.1, t + 0.4))):.1f} / {db(rms(seg(bound_all[ch], t + 0.1, t + 0.4))):.1f} "
              f"dBFS; harmonics above -60 dBFS within {dh:.2f} dB")
    print("  kit hits (ch 10), peak in the 50 ms after each note-on, alone / all bound:")
    for t, note in ((1.2, 36), (1.7, 38), (2.2, 42), (2.7, 36)):
        pa = max(abs(x) for x in seg(alone[10], t, t + 0.05))
        pb = max(abs(x) for x in seg(bound_all[10], t, t + 0.05))
        print(f"    note {note} at {t} s: {db(pa):.2f} / {db(pb):.2f} dBFS")
    print("  crosstalk: each all-bound render's level at the other channel's f0, 0.2-0.4 s after that channel's "
          "note-on time:")
    f_1, f_2 = f0(alone[1], 1.2), f0(alone[2], 1.7)
    for ch, och, t, hz in ((1, 2, 1.5, f_2), (2, 1, 1.0, f_1)):
        own = harmonics(bound_all[och], t + 0.2, hz, 1)[0]
        here = harmonics(bound_all[ch], t + 0.2, hz, 1)[0]
        print(f"    {hz:.1f} Hz (ch {och}'s f0) in the ch {ch} render: {here:.1f} dBFS (in ch {och}'s own: {own:.1f} "
              f"dBFS)")
    r, sg, mx = residual(together, add(bound_all[1], bound_all[2], bound_all[10]), 0.9, 1.2)
    print(f"All notes together vs the sum of the three single-channel renders, 0.9-1.2 s (only ch 1 has played): "
          f"difference {r:.1f} dBFS vs signal {sg:.1f} dBFS (three dither floors vs one)")
    summed = add(bound_all[1], bound_all[2], bound_all[10])
    print(f"  whole render: 50 ms level envelope within {env_delta(together, summed, 0.9, 5.0):.2f} dB of the sum")
    r, sg, mx = residual(unbound, quiet)
    print(f"Notes on unbound channels 5, 3, 16 vs no notes at all: whole render {sg:.1f} dBFS (dither), difference "
          f"{r:.1f} dBFS (max |diff| {mx:.2e}); voices {voices(logu) or [0]}")


# ---- 2. Swap


def track(a, hz, t0, t1, win=0.1, hop=0.005):
    """Level (dBFS) of one frequency over time, Hann-windowed Goertzel on win-long windows every hop (left)."""
    out = []
    t = t0
    while t < t1 - 1e-9:
        out.append((round(t, 4), db(goertzel(seg(a, t, t + win)[0::2], hz, True))))
        t += hop
    return out


def silences(a, t0, t1, win=0.001, floor=-100):
    """(start, end) of runs of win-long windows below floor dBFS in [t0, t1): digital silence plus dither."""
    runs, start = [], None
    t = t0
    while t < t1 - 1e-9:
        quiet = db(rms(seg(a, t, t + win))) < floor
        if quiet and start is None:
            start = t
        if not quiet and start is not None:
            runs.append((round(start, 4), round(t, 4)))
            start = None
        t += win
    if start is not None:
        runs.append((round(start, 4), round(t1, 4)))
    return runs


def swap_case(mode, target, card, new_note=64, during=False):
    tag = f"{mode}_{os.path.basename(target)[:3]}_{card.replace(':', '-')}" + ("_during" if during else "")
    ch1 = ["1.0 on 1 93", "4.0 off 1 93"]  # A6: well clear of the ch 2 sounds' partials (all under 1 kHz f0)
    # ch 2 holds note 63 on the old preset across the swap. The "2.0 on" after the swap line waits for the swap to
    # finish (the driver runs one command at a time), so it is the first note the new preset can get.
    ch2 = ["1.0 on 2 63", f"2.0 {mode} 2 {target}", f"2.0 on 2 {new_note}", f"3.5 off 2 {new_note}", "3.5 off 2 63"]
    if during:
        # With --midi-during-load notes don't wait for the swap: this one arrives 50 ms into the load.
        ch2 = ["1.0 on 2 63", f"2.0 {mode} 2 {target}", "2.05 on 2 67", "3.5 off 2 67", "3.5 off 2 63"]
    base = [f"0.2 bind 1 {ORGAN}", f"0.2 bind 2 {SOFT}"]
    flags = ["--midi-during-load"] if during else []
    both, log = render(f"s_{tag}", base + ch1 + ch2 + ["5.0 end"], card, flags)
    only2, log2 = render(f"s_{tag}_ch2", base + ch2 + ["5.0 end"], card, flags)
    only1, _ = render(f"s_{tag}_ch1", base + ch1 + ["5.0 end"], card, flags)
    sw = [t for t in timings(log) if mode + " ch" in t][0]
    m = re.search(r"at ([\d.]+) s took ([\d.]+) ms virtual, ([\d.]+) ms wall.*?(\d+) overruns", sw)
    t_swap, load_ms, wall_ms, overruns = float(m[1]), float(m[2]), float(m[3]), int(m[4])
    t_done = t_swap + load_ms / 1000
    total_overruns = int(re.search(r"DMA overruns (\d+)", log.splitlines()[-1])[1])
    total_overruns -= int(re.search(r"virtual, (\d+) DMA overruns so far", log)[1])
    print(f"- {mode} ch 2 -> {target}, card {card}{', a note sent during the load' if during else ''}: swap from "
          f"{t_swap:.4f} s took {load_ms:.1f} ms virtual ({wall_ms:.1f} ms wall); DMA overruns in the swap "
          f"{overruns}, after boot in the whole render {total_overruns}")
    # The held ch 1 note: its fundamental (no ch 2 sound has a partial near it) in the full render vs the
    # ch1-only render, 50 ms windows every 5 ms from 1.5 to 3.5 s.
    f1_hz = f0(only1, 1.5, hi=4000)
    tb, t1 = track(both, f1_hz, 1.5, 3.5), track(only1, f1_hz, 1.5, 3.5)
    dev = max(abs(x[1] - y[1]) for x, y in zip(tb, t1))
    lo = min(v for _, v in tb)
    hi = max(v for _, v in tb)
    print(f"    held ch 1 note: its {f1_hz:.1f} Hz level 1.5-3.5 s stays {lo:.2f}..{hi:.2f} dBFS, within {dev:.2f} dB "
          f"of the ch1-only render (100 ms Hann windows every 5 ms)")
    # ch 2 on its own, 1 ms windows: when the old note stops (first window 20 dB under its level before the swap)
    # and the silence (below -60 dBFS) before the next sound.
    env = [(t, db(rms(seg(only2, t, t + 0.001)))) for t in [t_swap - 0.02 + i * 0.001 for i in range(400 + int(load_ms))]]
    old_level = sorted(v for t, v in env if t < t_swap)[len([1 for t, v in env if t < t_swap]) // 2]
    cut = next((t for t, v in env if t >= t_swap and v < old_level - 20), None)
    quiet = silences(only2, t_swap, t_done + 0.25, floor=-60)
    gaps = [f"{a:.3f}-{b:.3f} s ({(b - a) * 1000:.0f} ms)" for a, b in quiet]
    f_new = f0(only2, t_done + 0.3) if not during else 0
    print(f"    ch 2 alone: old note at {old_level:.0f} dBFS (1 ms median) until the swap; first 1 ms window 20 dB "
          f"under that: {cut if cut is None else f'{cut:.3f}'} s; below -60 dBFS (1 ms windows) after the swap: "
          f"{', '.join(gaps) or 'never'}" + (f"; new note f0 {f_new:.0f} Hz" if f_new else ""))
    if during:
        v = re.findall(r"voices (\d+) at ([\d.]+)", log2)
        print(f"    ch 2 alone, voice count changes 1.9-2.6 s: {[(int(n), float(t)) for n, t in v if 1.9 < float(t) < 2.6]}")


def swap():
    print("\n## 2. Changing one binding while another channel holds a note\n")
    for mode in ("swap", "swapx"):
        for target in (SAW, DBASS):
            for card in (opts.card_us, "0:0"):
                swap_case(mode, target, card)
    swap_case("swap", DBASS, opts.card_us, during=True)


# ---- 3. Audition channel


def aligned(a, b, t0, t1, maxlag=64):
    """Best lag (samples, b against a) over [t0, t1) on the left channel and the residual (dBFS) after it."""
    i0, i1 = int(t0 * SR), int(t1 * SR)
    x, y = a[0::2], b[0::2]
    best = None
    for lag in range(-maxlag, maxlag + 1):
        d = [x[i] - y[i + lag] for i in range(i0, i1)]
        r = rms(d)
        if best is None or r < best[1]:
            best = (lag, r)
    return best[0], db(best[1])


def audition():
    print("\n## 3. An audition instrument on channel 16, added and removed while others play\n")
    # ch 1 holds A6 (its 1.76 kHz is clear of the kick and the strings' partials); ch 10 plays a kick every 250 ms.
    base = [f"0.2 bind 1 {ORGAN}", f"0.2 bind 10 {KIT} 36", "1.0 on 1 93", "5.0 off 1 93"]
    drums = []
    for k in range(16):
        t = 1.0 + 0.25 * k
        drums += [f"{t:.3f} on 10 36", f"{t + 0.05:.3f} off 10 36"]
    aud = [f"2.0 bind 16 {STRINGS}", "2.5 on 16 60", "3.0 off 16 60", "3.5 unbind 16"]
    ref, logr = render("a_ref", base + drums + ["6.0 end"])
    empty, log0 = render("a_addremove_silent", base + drums + [f"2.0 bind 16 {STRINGS}", "3.5 unbind 16", "6.0 end"])
    played, log = render("a_addremove_played", base + drums + aud + ["6.0 end"])
    alone, _ = render("a_audition_only", [f"0.2 bind 1 {ORGAN}", f"0.2 bind 10 {KIT} 36"] + aud + ["6.0 end"])
    for t in timings(log):
        print("   ", t)
    for name, r in (("added and removed, no notes", empty), ("added, played, removed", played)):
        n = min(len(r), len(ref))
        first = next((i for i in range(n) if r[i] != ref[i]), None)
        print(f"- {name}: samples identical to the never-added render until "
              f"{first / 2 / SR if first is not None else 'the end'} s (ch 16's bind starts at 2.001 s)")
        f1 = 1761.7  # PW Organ's A6, measured on its own in section 2 (the kicks spoil an autocorrelation here)
        ta, tb = track(ref, f1, 1.5, 4.5), track(r, f1, 1.5, 4.5)
        print(f"    held ch 1 note ({f1:.0f} Hz): level within {max(abs(x[1] - y[1]) for x, y in zip(ta, tb)):.2f} dB of "
              f"the never-added render, 1.5-4.5 s (100 ms Hann windows every 5 ms)")
        lags, res, peaks = [], [], []
        for k in range(16):
            t = 1.0 + 0.25 * k
            lag, rr = aligned(ref, r, t - 0.01, t + 0.2)
            lags.append(lag)
            res.append(rr)
            pa = max(abs(x) for x in seg(ref, t - 0.005, t + 0.05))
            pb = max(abs(x) for x in seg(r, t - 0.005, t + 0.05))
            peaks.append(abs(db(pa) - db(pb)))
        print(f"    kicks every 250 ms from 1.0 s, lag against the never-added render (samples): {lags}")
        print(f"    kick peaks within {max(peaks):.2f} dB; residual after the lag, worst kick: {max(res):.1f} dBFS "
              f"(the 200 ms around a kick is about {db(rms(seg(ref, 1.0, 1.2))):.0f} dBFS)")
    e = env10(alone, 2.4, 3.7)
    print("Audition alone, 10 ms levels 2.4-3.7 s (note 2.5-3.0, unbind at 3.5):",
          " ".join(f"{t:.2f}:{v:.0f}" for t, v in e[::5]))
    print("  1 ms levels at the unbind:", " ".join(f"{t:.3f}:{db(rms(seg(alone, t, t + 0.001))):.0f}"
                                                for t in [3.495 + 0.001 * i for i in range(12)]))
    print(f"  overruns after boot: ref {overruns(logr)}, silent {overruns(log0)}, played {overruns(log)}")


def overruns(log):
    return int(re.search(r"DMA overruns (\d+)", log.splitlines()[-1])[1]) - int(
        re.search(r"virtual, (\d+) DMA overruns so far", log)[1])


def main():
    global opts
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--card", default=os.path.expanduser("~/source/delugemu-sd/deluge_sd.img"))
    ap.add_argument("--card-us", default="300:40", help="the Engine's modelled card time, COMMAND:SECTOR us")
    ap.add_argument("--only", default=None, choices=["routing", "swap", "audition"])
    opts = ap.parse_args()
    for name, fn in (("routing", routing), ("swap", swap), ("audition", audition)):
        if opts.only in (None, name):
            fn()


if __name__ == "__main__":
    main()
