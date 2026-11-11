"""(1.137) Our Lady of the Harbour's bell: three slow strikes of a big bronze bell, into
sfx/church_bell.wav. Run from the project root:  python3 tools/make_church_bell.py
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sfx")

# a church bell's partials (hum, prime, minor third, fifth, nominal, upper ones), relative to the prime
PARTIALS = [(0.5, 0.55, 5.0), (1.0, 0.8, 3.6), (1.19, 0.5, 2.6), (1.5, 0.3, 2.0), (2.0, 0.45, 1.6), (2.52, 0.18, 1.0), (3.0, 0.12, 0.7)]


def strike(f, dur):
    t = np.arange(int(RATE * dur)) / RATE
    x = np.zeros_like(t)
    for ratio, amp, decay in PARTIALS:
        # a slow beat between two close tones: the bell's warble
        x += amp * np.exp(-t / decay) * (np.sin(2 * np.pi * f * ratio * t) + 0.35 * np.sin(2 * np.pi * (f * ratio + 1.3) * t))
    clang = np.exp(-t / 0.03) * np.random.default_rng(137).standard_normal(len(t)) * 0.25
    return x + clang


def main():
    total = 7.5
    out = np.zeros(int(RATE * total))
    for k, f in enumerate([196.0, 196.0, 174.6]):
        s = strike(f, total - k * 2.0)
        start = int(RATE * k * 2.0)
        out[start:start + len(s)] += s
    fade = np.ones_like(out)
    fade[-RATE:] = np.linspace(1, 0, RATE)
    out *= fade
    data = (out / np.max(np.abs(out)) * 0.8 * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, "church_bell.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    main()
