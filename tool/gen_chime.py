"""Synthesize SpeedChime's built-in warning sounds into assets/audio/.

PRD 4. 음원: 인터넷 녹음본을 쓰지 않고 직접 합성해 제작한다.
Usage:
  python3 tool/gen_chime.py            # regenerate every preset
  python3 tool/gen_chime.py classic    # one preset by name
Output: 44.1 kHz mono 16-bit WAV, exactly one loop period each.
Adding a preset here also needs an entry in lib/core/chime_sound.dart.
"""
import math
import struct
import sys
import wave

RATE = 44100
ATTACK_S = 0.004

# Struck-bar partials (ratio, gain): bright bell.
BELL = [(1.0, 1.0), (2.0, 0.35), (3.01, 0.12), (4.2, 0.05)]
# Mellow: almost pure tone.
SOFT = [(1.0, 1.0), (2.0, 0.12)]
# Odd harmonics: buzzy digital beep, like a meter's piezo.
BEEP = [(1.0, 1.0), (3.0, 0.33), (5.0, 0.2), (7.0, 0.14)]

PRESETS = {
    # 기본 "띵똥" (two-tone, E6 → C6).
    "classic": dict(
        file="chime.wav", period=1.0, decay=3.2, fade=0.12,
        partials=BELL, partial_decay=0.8,
        notes=[(0.00, 1318.5), (0.42, 1046.5)],
    ),
    # 트리플 벨 "띵띵띵" (rising C6 → E6 → G6).
    "triple": dict(
        file="chime_triple.wav", period=1.2, decay=4.0, fade=0.12,
        partials=BELL, partial_decay=0.8,
        notes=[(0.00, 1046.5), (0.16, 1318.5), (0.32, 1568.0)],
    ),
    # 부드러운 차임 (lower G5 → E5, slow decay).
    "soft": dict(
        file="chime_soft.wav", period=1.6, decay=2.2, fade=0.2,
        partials=SOFT, partial_decay=0.4,
        notes=[(0.00, 784.0), (0.50, 659.3)],
    ),
    # 디지털 "삐삐" (two short 2 kHz beeps, gated not decaying).
    "beep": dict(
        file="chime_beep.wav", period=0.8, decay=0.0, fade=0.03,
        partials=BEEP, partial_decay=0.0, gate=0.09,
        notes=[(0.00, 2000.0), (0.18, 2000.0)],
    ),
}


def render(p: dict) -> list:
    n = int(RATE * p["period"])
    gate = p.get("gate")
    out = []
    for i in range(n):
        t = i / RATE
        v = 0.0
        for start, f0 in p["notes"]:
            dt = t - start
            if dt < 0:
                continue
            if gate is not None:
                if dt > gate:
                    continue
                # short raised-cosine edges so the beep doesn't click
                edge = 0.006
                env = min(1.0, dt / edge, (gate - dt) / edge)
            else:
                env = math.exp(-p["decay"] * dt) * min(1.0, dt / ATTACK_S)
            for ratio, gain in p["partials"]:
                # higher partials decay faster, like a struck bar
                v += (gain * env * math.exp(-ratio * p["partial_decay"] * dt)
                      * math.sin(2 * math.pi * f0 * ratio * dt))
        out.append(v)
    # fade the tail so the loop point is click-free
    fade = int(RATE * p["fade"])
    for i in range(fade):
        out[n - fade + i] *= 1 - i / fade
    return out


def write(path: str, raw: list) -> None:
    peak = max(abs(x) for x in raw) or 1.0
    frames = b"".join(struct.pack("<h", int(x / peak * 0.85 * 32767)) for x in raw)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


def main() -> None:
    names = sys.argv[1:] or list(PRESETS)
    for name in names:
        p = PRESETS[name]
        path = f"assets/audio/{p['file']}"
        write(path, render(p))
        print(f"wrote {path} ({name}, {p['period']}s, {RATE} Hz)")


if __name__ == "__main__":
    main()
