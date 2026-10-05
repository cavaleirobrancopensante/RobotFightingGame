"""Composes the game's original chiptune music and crowd sounds.

    python3 tools/make_music.py      (needs numpy, scipy, soundfile)

Writes:
  music/menu.ogg   - "Scrapyard Groove", for menus, garage and story
  music/fight.ogg  - "Steel Rain", for fights
  sfx/crowd_cheer.wav, sfx/crowd_ooh.wav

Everything here is synthesized from scratch, so it's 100% original and free to use.
Melodies are written as (beat, length_in_beats, midi_note) lists - edit and re-run.
"""
import os

import numpy as np
import soundfile as sf
from scipy.signal import butter, lfilter

RATE = 32000
ROOT = os.path.join(os.path.dirname(__file__), "..")
rng = np.random.default_rng(42)


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (RATE / 2), hi / (RATE / 2)], btype="band")
    return lfilter(b, a, x)


def lp(x, cut, order=2):
    b, a = butter(order, cut / (RATE / 2), btype="low")
    return lfilter(b, a, x)


def hp(x, cut, order=2):
    b, a = butter(order, cut / (RATE / 2), btype="high")
    return lfilter(b, a, x)


def adsr(n, a=0.005, d=0.08, s=0.6, r=0.05):
    e = np.full(n, s)
    na, nd, nr = int(a * RATE), int(d * RATE), int(r * RATE)
    na = max(1, min(na, n))
    e[:na] = np.linspace(0, 1, na)
    end_d = min(n, na + nd)
    if end_d > na:
        e[na:end_d] = np.linspace(1, s, end_d - na)
    nr = min(nr, n)
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def wave(kind, f, n, vib=0.0, vib_rate=5.5, duty=0.5):
    t = np.arange(n) / RATE
    freq = f * (1 + vib * np.sin(2 * np.pi * vib_rate * t) * np.clip(t * 4, 0, 1))
    ph = np.cumsum(freq) / RATE % 1.0
    if kind == "pulse":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri":
        return 2 * np.abs(2 * ph - 1) - 1
    if kind == "saw":
        return 2 * ph - 1
    return np.sin(2 * np.pi * ph)


# ---------------------------------------------------------------- instruments

def inst_lead(f, n):
    return wave("pulse", f, n, vib=0.012, duty=0.25) * adsr(n, 0.01, 0.1, 0.7, 0.06) * 0.22


def inst_lead2(f, n):  # softer, for the second pass
    return wave("tri", f, n, vib=0.01) * adsr(n, 0.01, 0.1, 0.8, 0.06) * 0.3


def inst_bass(f, n):
    return lp(wave("saw", f, n), 900) * adsr(n, 0.004, 0.1, 0.7, 0.03) * 0.45


def inst_stab(f, n):
    return wave("pulse", f, n, duty=0.5) * adsr(n, 0.002, 0.06, 0.0, 0.02) * 0.09


def inst_chug(f, n):  # crunchy power chord "guitar"
    x = wave("saw", f, n) + wave("saw", f * 1.498, n) + 0.5 * wave("saw", f * 2.004, n)
    return np.tanh(lp(x, 2200) * 2.5) * adsr(n, 0.003, 0.05, 0.5, 0.02) * 0.12


def inst_arp(f, n):
    return wave("pulse", f, n, duty=0.125) * adsr(n, 0.002, 0.05, 0.2, 0.02) * 0.07


def inst_pad(f, n):
    x = wave("saw", f * 0.997, n) + wave("saw", f * 1.003, n)
    return lp(x, 1400) * adsr(n, 0.25, 0.2, 0.8, 0.3) * 0.05


def kick(n=None):
    n = int(0.18 * RATE)
    t = np.arange(n) / RATE
    f = 45 + 110 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 14) * 0.9


def snare():
    n = int(0.16 * RATE)
    t = np.arange(n) / RATE
    nz = bp(rng.uniform(-1, 1, n), 1200, 7000) * np.exp(-t * 22)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30)
    return (nz * 0.9 + tone * 0.5) * 0.55


def hat(open_=False):
    n = int((0.12 if open_ else 0.035) * RATE)
    t = np.arange(n) / RATE
    return hp(rng.uniform(-1, 1, n), 7000) * np.exp(-t * (25 if open_ else 90)) * 0.22


# ---------------------------------------------------------------- song renderer

class Song:
    def __init__(self, bpm, bars):
        self.beat = 60.0 / bpm
        self.length = int(bars * 4 * self.beat * RATE)
        self.buf = np.zeros(self.length + RATE)

    def add(self, beat, samples):
        s = int(beat * self.beat * RATE)
        e = min(len(self.buf), s + len(samples))
        self.buf[s:e] += samples[: e - s]

    def note(self, inst, beat, beats, midi):
        n = int(beats * self.beat * RATE)
        self.add(beat, inst(mtof(midi), n))

    def chord(self, inst, beat, beats, notes):
        for m in notes:
            self.note(inst, beat, beats, m)

    def melody(self, inst, start_beat, notes, transpose=0):
        for b, length, m in notes:
            self.note(inst, start_beat + b, length * 0.95, m + transpose)

    def render(self, path):
        x = self.buf[: self.length]
        # wrap the tail (reverb-ish ring-out) back to the start so the loop is seamless
        tail = self.buf[self.length:]
        x[: len(tail)] += tail
        x = np.tanh(x * 1.2)
        x = x / (np.max(np.abs(x)) or 1) * 0.85
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sf.write(path, x.astype(np.float32), RATE, format="OGG", subtype="VORBIS")
        print("wrote", path, round(self.length / RATE, 1), "s")


# ---------------------------------------------------------------- "Scrapyard Groove" (menus)

def scrapyard_groove():
    s = Song(bpm=104, bars=16)
    # Am | Am | F | F | C | C | G | G  (x2)
    prog = [(57, [69, 72, 76]), (57, [69, 72, 76]), (53, [69, 72, 77]), (53, [69, 72, 77]),
            (48, [67, 72, 76]), (48, [67, 72, 76]), (55, [67, 71, 74]), (55, [67, 71, 74])]
    bass_pat = [(0, 0.75, 0), (1, 0.5, 0), (1.5, 0.5, 12), (2.5, 0.5, 0), (3, 0.5, 7), (3.5, 0.5, 10)]
    for bar in range(16):
        root, ch = prog[bar % 8]
        b0 = bar * 4
        for off, ln, iv in bass_pat:
            s.note(inst_bass, b0 + off, ln, root - 12 + iv)
        for off in (0.5, 1.5, 2.5, 3.5):            # off-beat funk stabs
            s.chord(inst_stab, b0 + off, 0.3, ch)
        if bar >= 8:                                 # second half: arpeggios + pad
            for k in range(8):
                s.note(inst_arp, b0 + k * 0.5, 0.4, ch[k % 3] + 12)
            s.chord(inst_pad, b0, 4, [m - 12 for m in ch])
        # drums
        for beat in (0, 1.75, 2.5):
            s.add(b0 + beat, kick())
        for beat in (1, 3):
            s.add(b0 + beat, snare())
        for k in range(8):
            swing = 0.08 if k % 2 else 0.0
            s.add(b0 + k * 0.5 + swing, hat(open_=(k == 7)))

    melody = [
        (0, 1, 76), (1, 0.5, 74), (1.5, 0.5, 72), (2, 1.5, 69), (3.5, 0.5, 72),
        (4, 0.5, 74), (4.5, 0.5, 76), (5, 1, 79), (6, 2, 76),
        (8, 1, 77), (9, 0.5, 76), (9.5, 0.5, 74), (10, 1.5, 72), (11.5, 0.5, 69),
        (12, 1, 72), (13, 1, 74), (14, 2, 72),
        (16, 1, 76), (17, 0.5, 79), (17.5, 0.5, 81), (18, 1.5, 79), (19.5, 0.5, 76),
        (20, 1, 74), (21, 1, 76), (22, 2, 72),
        (24, 1, 74), (25, 0.5, 71), (25.5, 0.5, 74), (26, 1.5, 79), (27.5, 0.5, 77),
        (28, 1, 76), (29, 1, 74), (30, 2, 71),
    ]
    s.melody(inst_lead, 0, melody)
    s.melody(inst_lead2, 32, melody, transpose=12)
    s.melody(inst_lead, 32, melody)
    s.render(os.path.join(ROOT, "music", "menu.ogg"))


# ---------------------------------------------------------------- "Steel Rain" (fights)

def steel_rain():
    s = Song(bpm=144, bars=16)
    # Em Em C D | Em Em C B  (x2)
    prog = [52, 52, 48, 50, 52, 52, 48, 47]
    for bar in range(16):
        root = prog[bar % 8]
        b0 = bar * 4
        for k in range(8):                           # driving 8th-note bass
            s.note(inst_bass, b0 + k * 0.5, 0.45, root - 12 + (12 if k in (3, 7) else 0))
        for k in range(8):                           # chugging power chords
            if k not in (3, 6):
                s.note(inst_chug, b0 + k * 0.5, 0.4, root)
        for beat in range(4):                        # four on the floor
            s.add(b0 + beat, kick())
        for beat in (1, 3):
            s.add(b0 + beat, snare())
        for k in range(16):
            s.add(b0 + k * 0.25, hat(open_=(k % 4 == 2)) * (1.0 if k % 2 == 0 else 0.6))
        if bar % 8 == 7:                             # snare fill
            for k in range(4):
                s.add(b0 + 3 + k * 0.25, snare() * 0.7)

    riff = [
        (0, 0.5, 76), (0.5, 0.5, 76), (1, 0.5, 74), (1.5, 0.5, 76), (2, 1, 79), (3, 1, 76),
        (4, 0.5, 74), (4.5, 0.5, 71), (5, 1, 74), (6, 1.5, 71), (7.5, 0.5, 67),
        (8, 1, 72), (9, 0.5, 71), (9.5, 0.5, 72), (10, 1, 76), (11, 1, 72),
        (12, 1, 74), (13, 0.5, 72), (13.5, 0.5, 74), (14, 2, 78),
        (16, 0.5, 76), (16.5, 0.5, 76), (17, 0.5, 74), (17.5, 0.5, 76), (18, 1, 79), (19, 1, 76),
        (20, 0.5, 74), (20.5, 0.5, 71), (21, 1, 74), (22, 1.5, 71), (23.5, 0.5, 67),
        (24, 1, 72), (25, 1, 76), (26, 1, 79), (27, 1, 76),
        (28, 1, 75), (29, 1, 78), (30, 2, 71),
    ]
    s.melody(inst_lead, 0, riff)
    s.melody(inst_lead, 32, riff, transpose=12)
    s.melody(inst_lead2, 32, riff)
    s.render(os.path.join(ROOT, "music", "fight.ogg"))


# ---------------------------------------------------------------- crowd

VOWELS = [(500, 900), (750, 1200), (350, 2200), (600, 1000)]


def crowd_voice(n, f0, f1, vowel, attack, decay=1.4):
    t = np.arange(n) / RATE
    f = np.linspace(f0, f1, n) * (1 + 0.02 * np.sin(2 * np.pi * rng.uniform(4, 7) * t))
    src = (np.cumsum(f) / RATE % 1.0) * 2 - 1
    fa, fb = vowel
    x = bp(src, fa * 0.8, fa * 1.25) + 0.6 * bp(src, fb * 0.85, fb * 1.2)
    env = np.clip(t / attack, 0, 1) * np.exp(-np.maximum(t - attack, 0) * rng.uniform(0.5, 1.0) * decay)
    return x * env


def crowd(path, seconds, voices, pitch_up=True, claps=0, ooh=False):
    n = int(seconds * RATE)
    out = np.zeros(n)
    # roar bed
    bed = bp(rng.uniform(-1, 1, n), 250, 2500, order=3)
    t = np.arange(n) / RATE
    swell = np.clip(t / 0.4, 0, 1) * np.exp(-np.maximum(t - seconds * 0.45, 0) * 1.2)
    out += bed * swell * 0.5
    for _ in range(voices):
        start = int(rng.uniform(0, 0.5 if ooh else seconds * 0.4) * RATE)
        ln = int(rng.uniform(0.8, seconds * 0.85) * RATE)
        ln = min(ln, n - start)
        base = rng.uniform(140, 420)
        if ooh:
            f0, f1, vowel = base * 1.15, base * 0.8, (450, 850)
        elif pitch_up:
            f0, f1, vowel = base, base * rng.uniform(1.1, 1.5), VOWELS[rng.integers(len(VOWELS))]
        else:
            f0, f1, vowel = base, base, VOWELS[rng.integers(len(VOWELS))]
        out[start:start + ln] += crowd_voice(ln, f0, f1, vowel, rng.uniform(0.05, 0.3), 2.5 if ooh else 0.5) * rng.uniform(0.3, 1.0)
    for _ in range(claps):
        s = int(rng.uniform(0.2, seconds - 0.1) * RATE)
        c = hp(rng.uniform(-1, 1, 400), 1200) * np.exp(-np.arange(400) / 60.0)
        out[s:s + 400] += c * rng.uniform(0.2, 0.6)
    out = np.tanh(out / (np.max(np.abs(out)) or 1) * 1.5)
    out = out / np.max(np.abs(out)) * 0.8
    fade = int(0.3 * RATE)
    out[-fade:] *= np.linspace(1, 0, fade)
    sf.write(path, (out * 32767).astype(np.int16), RATE, subtype="PCM_16")
    print("wrote", path)


if __name__ == "__main__":
    scrapyard_groove()
    steel_rain()
    crowd(os.path.join(ROOT, "sfx", "crowd_cheer.wav"), 3.5, voices=45, claps=90)
    crowd(os.path.join(ROOT, "sfx", "crowd_ooh.wav"), 1.6, voices=30, ooh=True)
