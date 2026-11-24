#!/usr/bin/env python3
"""Run the firmware's own test-port scripts against the Engine (spike/host/drivers/perform_engine.cpp), as
test_port_emu.py runs them against delugemu: the Engine's DIN MIDI port is bridged to UDP, and deluge_probe.py (from
the firmware tree, unchanged) drives it with --udp ports.

    python3 spike/scripts/perform_run.py --script perform_skeleton.txt [--script ...] [--pace 1] \
        [--play-seconds 60] [--out piece.wav] [--card IMG]

Each --script is a path, or a name under the firmware's scripts/generative/. After the scripts, the Engine keeps
playing until --play-seconds of virtual time have passed since playback started (or --seconds in all), writes the
WAV and exits. Every run has a wall-clock timeout (--timeout).
"""
import argparse
import os
import re
import socket
import subprocess
import sys
import time

FW = os.environ.get("DELUGE_FW", os.path.expanduser("~/.cache/deluge-engine/firmware"))
SCRIPTS = os.path.join(FW, "scripts", "generative")
sys.path.insert(0, SCRIPTS)
import deluge_probe  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ENGINE = os.path.join(HERE, "..", "..", "build", "perform_engine")


def free_udp_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--script", action="append", default=[])
    ap.add_argument("--engine", default=ENGINE)
    ap.add_argument("--card", default=os.path.expanduser("~/source/delugemu-sd/deluge_sd.img"))
    ap.add_argument("--line", action="append", default=[],
                    help="a script line run after the scripts (e.g. --line 'button PLAY down'); repeatable")
    ap.add_argument("--pace", type=float, default=1.0, help="virtual seconds per wall second while scripts run")
    ap.add_argument("--ticks-per-read", type=int, default=None)
    ap.add_argument("--card-us", default=None, help="the Engine's modelled card time, COMMAND:SECTOR microseconds")
    ap.add_argument("--free-after-play", action="store_true", help="the Engine runs free once playback starts")
    ap.add_argument("--play-seconds", type=float, default=60)
    ap.add_argument("--seconds", type=float, default=600)
    ap.add_argument("--out", default=None)
    ap.add_argument("--events", default=None, help="regex: print matching test events after each script")
    ap.add_argument("--timeout", type=float, default=550, help="wall-clock limit for the whole run")
    ap.add_argument("--log", default=None, help="the Engine's stderr goes here (default: this process's stderr)")
    a = ap.parse_args()

    listen, send = free_udp_port(), free_udp_port()
    cmd = [a.engine, "--udp", f"{listen}:{send}", "--pace", str(a.pace), "--play-seconds", str(a.play_seconds),
           "--seconds", str(a.seconds)]
    if a.ticks_per_read:
        cmd += ["--ticks-per-read", str(a.ticks_per_read)]
    if a.out:
        cmd += ["--out", a.out]
    if a.card_us:
        cmd += ["--card-us", a.card_us]
    if a.free_after_play:
        cmd += ["--free-after-play"]
    log = open(a.log, "w") if a.log else None
    t0 = time.monotonic()
    proc = subprocess.Popen(cmd, env=dict(os.environ, DELUGE_SD_IMAGE=a.card), stderr=log or None,
                            stdin=subprocess.DEVNULL)
    results = []
    try:
        port = deluge_probe.wait_ready(lambda: deluge_probe.UdpLink(f"{listen}:{send}"), None, 30)
        print(f"[perform-run] test port ready after {time.monotonic() - t0:.2f} s wall", flush=True)
        port.subscribe()
        pattern = re.compile(a.events) if a.events else None
        for script in a.script:
            path = script if os.path.exists(script) else os.path.join(SCRIPTS, script)
            start = time.monotonic()
            try:
                failed, total = deluge_probe.run_one_script(port, path, events=pattern)
                error = None
            except deluge_probe.ScriptStopped as exc:
                failed, total, error = exc.failed, exc.total, exc.error
            line = deluge_probe.result_line(os.path.basename(path), failed, total, error)
            results.append(line)
            print(f"[perform-run] {line} ({time.monotonic() - start:.1f} s wall)", flush=True)
        if a.line:
            start = time.monotonic()
            failed, total = deluge_probe.run_script(port, [(f"--line {i + 1}", t) for i, t in enumerate(a.line)])
            line = deluge_probe.result_line("--line", failed, total)
            results.append(line)
            print(f"[perform-run] {line} ({time.monotonic() - start:.1f} s wall)", flush=True)
        # Ask for a final state, so the log shows where the scripts left the firmware.
        try:
            print("[perform-run] state:", port.state(), flush=True)
        except Exception as exc:  # noqa: BLE001 - the Engine may have ended already
            print("[perform-run] no state:", exc, flush=True)
        port.subscribe(False)
        if a.out:  # the Engine plays on to --play-seconds and writes the WAV
            rc = proc.wait(timeout=max(1, a.timeout - (time.monotonic() - t0)))
        else:
            proc.terminate()
            rc = 0 if proc.wait(timeout=10) in (0, -15) else proc.returncode
    except subprocess.TimeoutExpired:
        print("[perform-run] TIMEOUT: killing the Engine", flush=True)
        proc.kill()
        rc = -9
    finally:
        if proc.poll() is None:
            proc.kill()
    print(f"[perform-run] engine rc={rc}, {time.monotonic() - t0:.1f} s wall", flush=True)
    for line in results:
        print("[perform-run]", line)
    return 0 if rc == 0 and all(" 0 failed" in r or "failed" not in r for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
