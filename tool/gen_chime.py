"""Synthesize the two-tone "ding-dong" chime used by SpeedChime.

PRD 4. 음원: 인터넷 녹음본을 쓰지 않고 두 음 벨소리를 합성해 제작한다.
Usage: python3 tool/gen_chime.py [out.wav]
Output: 44.1 kHz mono 16-bit WAV, one loop period (ding + dong + tail).
"""
import math
import struct
import sys
import wave

RATE = 44100
PERIOD_S = 1.6           # loop length: chime repeats every 1.6 s
NOTES = [                # (start s, fundamental Hz)
    (0.00, 1318.5),      # E6  "ding"
    (0.42, 1046.5),      # C6  "dong"
]
PARTIALS = [(1.0, 1.0), (2.0, 0.35), (3.01, 0.12), (4.2, 0.05)]  # (ratio, gain)
DECAY = 3.2              # exponential decay rate (1/s)
ATTACK_S = 0.004


def sample(t: float) -> float:
    v = 0.0
    for start, f0 in NOTES:
        dt = t - start
        if dt < 0:
            continue
        env = math.exp(-DECAY * dt) * min(1.0, dt / ATTACK_S)
        for ratio, gain in PARTIALS:
            # higher partials decay faster, like a struck bar
            v += gain * env * math.exp(-ratio * 0.8 * dt) * math.sin(2 * math.pi * f0 * ratio * dt)
    return v


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/chime.wav"
    n = int(RATE * PERIOD_S)
    raw = [sample(i / RATE) for i in range(n)]
    # fade the last 30 ms so the loop point is click-free
    fade = int(RATE * 0.03)
    for i in range(fade):
        raw[n - fade + i] *= 1 - i / fade
    peak = max(abs(x) for x in raw) or 1.0
    frames = b"".join(struct.pack("<h", int(x / peak * 0.85 * 32767)) for x in raw)
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f"wrote {out} ({PERIOD_S}s, {RATE} Hz)")


if __name__ == "__main__":
    main()
