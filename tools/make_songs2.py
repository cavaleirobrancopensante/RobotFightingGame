"""Port Ferrum's second record: songs written by hand, each with its own shape and sound, plus the
overture for the opening cutscene (timed to its eight shots).

    python3 tools/make_songs2.py            (needs numpy, scipy, soundfile; reuses make_music.py)
    python3 tools/make_songs2.py overture   (only the named songs)

Unlike make_songs.py (one recipe, many seeds), every song here is its own little composition:
a lo-fi rain loop, a harbour waltz in 3/4, a twelve-bar shuffle, Kane's cold tower, a scrapyard
gamelan, a dockside bossa and a night-shift synthwave. All synthesized from scratch, 100% original.
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy.signal import fftconvolve, lfilter

sys.path.insert(0, os.path.dirname(__file__))
import make_music as mm  # noqa: E402

RATE = mm.RATE
rng = np.random.default_rng(2047)


# ---------------------------------------------------------------- tools

def save_ogg(path, x):
    """Writes in blocks: one huge write makes libsndfile's vorbis encoder crash on long files."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with sf.SoundFile(path, "w", RATE, 1, format="OGG", subtype="VORBIS") as f:
        for k in range(0, len(x), RATE * 4):
            f.write(x[k:k + RATE * 4].astype(np.float32))


def secs(n):
    return int(n * RATE)


def reverb(x, seconds=1.8, mix=0.25, bright=4000):
    """A plate-ish reverb: noise with an exponential tail, convolved."""
    n = secs(seconds)
    t = np.arange(n) / RATE
    ir = rng.uniform(-1, 1, n) * np.exp(-t * 6.9 / seconds)
    ir = mm.lp(ir, bright)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fftconvolve(x, ir)[: len(x)]
    return x * (1 - mix) + wet * mix * 1.4


def delay(x, beat_s, feedback=0.35, mix=0.3):
    """Echoes every beat_s seconds, each one quieter by `feedback`."""
    d = secs(beat_s)
    y = np.copy(x)
    gain = mix
    for k in range(1, 6):
        if k * d >= len(x):
            break
        y[k * d:] += x[: len(x) - k * d] * gain
        gain *= feedback
    return y


def pluck(f, n, bright=0.5, decay=0.996):
    """Karplus-Strong string: guitars, nylon, harp."""
    p = max(2, int(RATE / f))
    exc = rng.uniform(-1, 1, p)
    exc = mm.lp(np.concatenate([exc, np.zeros(8)]), 1500 + 6000 * bright)[:p]
    x = np.zeros(n)
    x[:p] = exc
    a = np.zeros(p + 2)
    a[0] = 1.0
    a[p] = -decay * 0.5
    a[p + 1] = -decay * 0.5
    y = lfilter([1.0], a, x)
    return y * mm.adsr(n, 0.001, 0.05, 1.0, 0.03) * 0.5


def accordion(f, n):
    x = mm.wave("saw", f * 0.996, n, vib=0.004, vib_rate=5) + mm.wave("pulse", f * 1.004, n, duty=0.4) * 0.7
    x = mm.bp(x, 300, 3200)
    return x * mm.adsr(n, 0.04, 0.1, 0.85, 0.08) * 0.09


def harmonica(f, n):
    x = mm.wave("pulse", f, n, vib=0.012, vib_rate=6, duty=0.3)
    # a little bend up into the note
    t = np.arange(n) / RATE
    bend = 1 - 0.03 * np.exp(-t * 18)
    ph = np.cumsum(f * bend) / RATE % 1.0
    x = 0.6 * x + 0.6 * np.where(ph < 0.3, 1.0, -1.0)
    return mm.bp(x, 500, 3500) * mm.adsr(n, 0.03, 0.1, 0.7, 0.06) * 0.1


def flute(f, n):
    t = np.arange(n) / RATE
    x = mm.wave("sine", f, n, vib=0.008, vib_rate=5) + 0.15 * mm.wave("sine", f * 2, n)
    breath = mm.bp(rng.uniform(-1, 1, n), f * 0.8, min(f * 3, 12000)) * 0.25
    return (x + breath) * mm.adsr(n, 0.06, 0.1, 0.8, 0.08) * 0.13


def metallophone(f, n):
    """Gamelan-ish bar: inharmonic partials, a shimmer from a detuned twin."""
    t = np.arange(n) / RATE
    x = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.92 * t) * np.exp(-t * 4)
         + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 9))
    x += np.sin(2 * np.pi * (f + 3.5) * t) * 0.7
    return x * np.exp(-t * 2.2) * 0.07


def glass(f, n):
    t = np.arange(n) / RATE
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 3)
    return x * np.exp(-t * 1.6) * mm.adsr(n, 0.002, 0.0, 1.0, 0.1) * 0.09


def soft_sine(f, n):
    return mm.wave("sine", f, n, vib=0.006) * mm.adsr(n, 0.02, 0.2, 0.6, 0.1) * 0.16


def rhodes(f, n):
    t = np.arange(n) / RATE
    x = np.sin(2 * np.pi * f * t + 1.2 * np.sin(2 * np.pi * f * t) * np.exp(-t * 3))
    x += 0.4 * np.sin(2 * np.pi * f * 1.003 * t)
    return x * np.exp(-t * 1.2) * mm.adsr(n, 0.003, 0.0, 1.0, 0.1) * 0.06


def brass(f, n):
    x = sum(mm.wave("saw", f * d, n, vib=0.006) for d in (0.996, 1.0, 1.005))
    t = np.arange(n) / RATE
    cut = 900 + 2600 * np.clip(t * 6, 0, 1)
    x = mm.lp(x, 2800) * (0.5 + 0.5 * np.clip(t * 6, 0, 1))
    return x * mm.adsr(n, 0.05, 0.15, 0.8, 0.12) * 0.06


def strings(f, n):
    x = sum(mm.wave("saw", f * d, n, vib=0.005, vib_rate=4.5) for d in (0.993, 1.0, 1.007))
    return mm.lp(x, 2200) * mm.adsr(n, 0.4, 0.2, 0.9, 0.5) * 0.035


def sub(f, n):
    return mm.wave("sine", f, n) * mm.adsr(n, 0.01, 0.1, 0.9, 0.05) * 0.5


def muted_bass(f, n):
    return mm.lp(mm.wave("tri", f, n) + 0.3 * mm.wave("saw", f, n), 500) * mm.adsr(n, 0.004, 0.15, 0.4, 0.04) * 0.5


def brush():
    n = secs(0.18)
    t = np.arange(n) / RATE
    return mm.bp(rng.uniform(-1, 1, n), 2000, 9000) * np.exp(-t * 14) * 0.12


def rim():
    n = secs(0.06)
    t = np.arange(n) / RATE
    return (np.sin(2 * np.pi * 1700 * t) * 0.6 + mm.bp(rng.uniform(-1, 1, n), 2500, 6000)) * np.exp(-t * 60) * 0.25


def tick():
    n = secs(0.02)
    t = np.arange(n) / RATE
    return mm.hp(rng.uniform(-1, 1, n), 5000) * np.exp(-t * 300) * 0.3


def clank(pitch=1.0):
    n = secs(0.35)
    t = np.arange(n) / RATE
    x = sum(np.sin(2 * np.pi * f * pitch * t) * np.exp(-t * d) for f, d in ((523, 9), (1307, 14), (2211, 20), (3397, 26)))
    return (x * 0.25 + mm.bp(rng.uniform(-1, 1, n), 2000, 8000) * np.exp(-t * 50)) * 0.18


def tom(f=90):
    n = secs(0.5)
    t = np.arange(n) / RATE
    fr = f * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(fr) / RATE) * np.exp(-t * 6) * 0.6


def gated_snare():
    s = mm.snare()
    n = secs(0.3)
    x = np.zeros(n)
    x[: len(s)] = s
    x = reverb(x, 0.8, 0.6)
    x[secs(0.22):] *= np.linspace(1, 0, n - secs(0.22))
    return x * 1.2


def boom():
    n = secs(4.0)
    t = np.arange(n) / RATE
    f = 32 + 60 * np.exp(-t * 6)
    x = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 0.9)
    x += mm.lp(rng.uniform(-1, 1, n), 1800) * np.exp(-t * 3) * 0.6
    return x * 0.9


def noise_bed(n, lo, hi, level):
    return mm.bp(rng.uniform(-1, 1, n), lo, hi) * level


class Track:
    """A song as a buffer you place notes into by beat, with a free bar length (3/4 works)."""

    def __init__(self, bpm, beats, tail=2.0):
        self.beat = 60.0 / bpm
        self.length = secs(beats * self.beat)
        self.buf = np.zeros(self.length + secs(tail))
        self.bus = {}

    def at(self, beat):
        return int(beat * self.beat * RATE)

    def add(self, beat, x, bus=None):
        s = self.at(beat)
        if s >= len(self.buf):
            return
        e = min(len(self.buf), s + len(x))
        target = self.buf
        if bus is not None:
            if bus not in self.bus:
                self.bus[bus] = np.zeros(len(self.buf))
            target = self.bus[bus]
        target[s:e] += x[: e - s]

    def note(self, inst, beat, beats, midi, vel=1.0, bus=None):
        self.add(beat, inst(mm.mtof(midi), max(64, secs(beats * self.beat))) * vel, bus)

    def chord(self, inst, beat, beats, notes, vel=1.0, bus=None, strum=0.0):
        for k, m in enumerate(notes):
            self.note(inst, beat + k * strum, beats, m, vel, bus)

    def mixdown(self, buses=None):
        x = np.copy(self.buf)
        for name, b in self.bus.items():
            fx = (buses or {}).get(name)
            x += fx(b) if fx else b
        return x

    def write(self, path, buses=None, loop=True, master=1.0):
        x = self.mixdown(buses)
        if loop:
            body = x[: self.length]
            tail = x[self.length:]
            body[: len(tail)] += tail
            x = body
        # level by loudness (RMS), not by the loudest click, then a soft limiter for the peaks
        x = x / (np.sqrt(np.mean(x ** 2)) or 1) * 0.2 * master
        x = np.tanh(x * 1.3) / 1.3
        x = x / max(1.0, np.max(np.abs(x)) / 0.9)
        save_ogg(path, x)
        print("wrote", path, round(len(x) / RATE, 1), "s")


def N(name):
    """'C4' -> midi."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    k = names[name[0]]
    i = 1
    if name[1] in "#b":
        k += 1 if name[1] == "#" else -1
        i = 2
    return 12 * (int(name[i:]) + 1) + k


def tune(t, inst, start, text, vel=1.0, bus=None, swing=0.0):
    """'E5:1 D5:.5 r:.5 ...' -> notes from beat `start`. Returns the beat after the last note."""
    b = start
    for tok in text.split():
        name, ln = tok.split(":")
        ln = float(ln)
        if name != "r":
            sb = b + (swing if (b % 1) >= 0.49 and (b % 1) < 0.51 else 0.0)
            t.note(inst, sb, ln * 0.95, N(name), vel, bus)
        b += ln
    return b


# ---------------------------------------------------------------- 1. Rain on the Docks (lo-fi)

def rain_on_the_docks(out):
    bpm = 74
    bars = 16
    t = Track(bpm, bars * 4)
    sw = 0.16   # lazy swing on the off-beats
    chords = [["F3", "A3", "C4", "E4", "G4"], ["E3", "G3", "B3", "D4", "F#4"],
              ["D3", "F3", "A3", "C4", "E4"], ["C3", "E3", "G3", "B3", "D4"]]
    roots = ["F2", "E2", "D2", "C2"]
    for bar in range(bars):
        b0 = bar * 4
        ch = [N(x) for x in chords[bar % 4]]
        t.chord(rhodes, b0, 2.6, ch, 0.9, "keys", strum=0.03)
        t.chord(rhodes, b0 + 2.5 + sw, 1.4, ch[1:], 0.6, "keys", strum=0.02)
        t.note(muted_bass, b0, 1.4, N(roots[bar % 4]))
        t.note(muted_bass, b0 + 2.5 + sw, 1.0, N(roots[bar % 4]) + 7, 0.7)
        if bar >= 1:
            t.add(b0, mm.kick() * 0.55)
            t.add(b0 + 1.5 + sw, mm.kick() * 0.35)
            t.add(b0 + 2.75, mm.kick() * 0.4)
            t.add(b0 + 1, brush() * 1.6)
            t.add(b0 + 3, brush() * 1.6)
            for k in range(8):
                t.add(b0 + k * 0.5 + (sw if k % 2 else 0), mm.hat() * (0.35 if k % 2 else 0.5))
    mel_a = "r:1 A4:.5 C5:.5 E5:1.5 D5:.5 C5:1 A4:1 r:2 G4:.5 A4:.5 C5:1 B4:1 G4:1 r:1"
    mel_b = "E5:1.5 G5:.5 E5:1 D5:1 C5:2 A4:1 G4:1 A4:3 r:1 r:4"
    tune(t, soft_sine, 16, mel_a, 0.9, "lead", sw)
    tune(t, soft_sine, 32, mel_b, 0.9, "lead", sw)
    tune(t, soft_sine, 48, mel_a, 0.8, "lead", sw)
    # rain and vinyl crackle all the way through
    n = len(t.buf)
    rain = noise_bed(n, 2500, 9000, 0.012)
    crackle = np.zeros(n)
    pops = rng.integers(0, n, int(n / RATE * 9))
    crackle[pops] = rng.uniform(-0.5, 0.5, len(pops))
    t.buf += rain + mm.lp(crackle, 5000) * 0.5
    t.write(out, {"keys": lambda x: reverb(mm.lp(x, 3500), 1.6, 0.3), "lead": lambda x: reverb(delay(x, 0.75 * 60 / bpm, 0.3, 0.25), 2.0, 0.35)})


# ---------------------------------------------------------------- 2. Harbour Waltz (3/4)

def harbour_waltz(out):
    bpm = 150
    bars = 32
    t = Track(bpm, bars * 3)
    # D minor: Dm Dm A7 A7 Gm Dm A7 Dm, then Bb F Gm A
    prog = [("D2", ["D4", "F4", "A4"]), ("D2", ["D4", "F4", "A4"]), ("A1", ["C#4", "E4", "G4"]), ("A1", ["C#4", "E4", "G4"]),
            ("G1", ["D4", "G4", "Bb4"]), ("D2", ["D4", "F4", "A4"]), ("A1", ["C#4", "E4", "G4"]), ("D2", ["D4", "F4", "A4"]),
            ("Bb1", ["D4", "F4", "Bb4"]), ("F2", ["C4", "F4", "A4"]), ("G1", ["D4", "G4", "Bb4"]), ("A1", ["C#4", "E4", "A4"]),
            ("Bb1", ["D4", "F4", "Bb4"]), ("F2", ["C4", "F4", "A4"]), ("A1", ["C#4", "E4", "G4"]), ("D2", ["D4", "F4", "A4"])]
    for bar in range(bars):
        b0 = bar * 3
        root, ch = prog[bar % 16]
        t.note(mm.inst_bass, b0, 0.9, N(root) + 12, 0.8)
        for k in (1, 2):
            t.chord(accordion, b0 + k, 0.7, [N(x) for x in ch], 0.55, "acc")
        t.add(b0, mm.kick() * 0.5)
        t.add(b0 + 1, brush() * 1.2)
        t.add(b0 + 2, brush() * 1.0)
    a = "A4:1 D5:1 E5:1 F5:2 E5:1 D5:1 C#5:1 D5:1 E5:3 A4:1 E5:1 F5:1 G5:2 F5:1 E5:1 D5:1 C#5:1 D5:3"
    b = "F5:1 Bb5:1 A5:1 G5:2 F5:1 E5:1 F5:1 G5:1 A5:3 Bb5:1 A5:1 G5:1 F5:2 E5:1 G5:1 F5:1 E5:1 D5:3"
    tune(t, accordion, 0, a, 1.5, "lead")
    tune(t, accordion, 24, b, 1.5, "lead")
    tune(t, flute, 48, a, 1.0, "lead")
    tune(t, accordion, 72, b, 1.5, "lead")
    # gulls and water
    t.buf += noise_bed(len(t.buf), 200, 900, 0.012)
    t.write(out, {"acc": lambda x: reverb(x, 1.2, 0.2), "lead": lambda x: reverb(x, 1.5, 0.25)})


# ---------------------------------------------------------------- 3. Rust Belt Shuffle (12-bar blues)

def rust_belt_shuffle(out):
    bpm = 104
    choruses = 2
    t = Track(bpm, 12 * 4 * choruses)
    form = ["E", "A", "E", "E", "A", "A", "E", "E", "B", "A", "E", "B"]
    roots = {"E": N("E2"), "A": N("A2"), "B": N("B2")}
    tri = 2.0 / 3.0   # shuffle: the off-beat sits on the last triplet
    for c in range(choruses):
        for i, ch in enumerate(form):
            b0 = (c * 12 + i) * 4
            r = roots[ch]
            # the boogie riff on a plucked guitar: root-fifth, root-sixth
            for beat in range(4):
                up = 9 if beat % 2 else 7
                t.note(lambda f, n: pluck(f, n, 0.4, 0.993), b0 + beat, 0.6, r + 12, 0.9, "gtr")
                t.note(lambda f, n: pluck(f, n, 0.4, 0.993), b0 + beat, 0.6, r + 12 + up, 0.7, "gtr")
                t.note(lambda f, n: pluck(f, n, 0.4, 0.993), b0 + beat + tri, 0.3, r + 12, 0.7, "gtr")
                t.note(lambda f, n: pluck(f, n, 0.4, 0.993), b0 + beat + tri, 0.3, r + 12 + up, 0.5, "gtr")
                t.note(muted_bass, b0 + beat, 0.6, r + [0, 4, 7, 9][beat], 0.9)
                t.add(b0 + beat, mm.hat() * 0.5)
                t.add(b0 + beat + tri, mm.hat() * 0.35)
            t.add(b0, mm.kick() * 0.8)
            t.add(b0 + 2, mm.kick() * 0.7)
            t.add(b0 + 1, mm.snare() * 0.6)
            t.add(b0 + 3, mm.snare() * 0.6)
    # harmonica answers between the riffs
    lick1 = "r:2 G4:.67 A4:.33 B4:1 r:4 E5:.67 D5:.33 B4:1 G4:1 E4:2"
    lick2 = "r:2 D5:.67 E5:.33 G5:1.5 E5:.5 D5:1 B4:1 A4:1 r:1"
    lick3 = "r:1 B4:.67 D5:.33 E5:1 D5:.67 B4:.33 A4:1 G4:2 E4:2 r:3"
    for c in range(choruses):
        base = c * 48
        tune(t, harmonica, base, lick1, 1.0, "harp")
        tune(t, harmonica, base + 16, lick2, 1.0, "harp")
        tune(t, harmonica, base + 32, lick3, 1.0, "harp")
    t.write(out, {"gtr": lambda x: reverb(x, 0.9, 0.18), "harp": lambda x: reverb(x, 1.4, 0.25)})


# ---------------------------------------------------------------- 4. Kane Tower (cold, corporate)

def kane_tower(out):
    bpm = 90
    bars = 16
    t = Track(bpm, bars * 4, tail=4.0)
    roots = ["E2", "E2", "F2", "E2", "E2", "E2", "D2", "F2"]
    for bar in range(bars):
        b0 = bar * 4
        r = N(roots[bar % 8])
        for k in range(8):
            t.note(sub, b0 + k * 0.5, 0.35, r, 0.55 if k % 2 else 0.8)
        for k in range(16):
            t.add(b0 + k * 0.25, tick() * (1.0 if k % 4 == 0 else 0.4))
        if bar >= 4:
            t.add(b0, mm.kick() * 0.5)
            t.add(b0 + 2.5, mm.kick() * 0.3)
        if bar % 4 == 0:
            t.chord(strings, b0, 15.5, [r + 24, r + 27, r + 31, r + 34], 0.7, "pad")
    motif = "E5:1.5 F5:.5 B4:2 r:4 E5:1.5 F5:.5 G5:1 F5:1 E5:4 r:4"
    for start in (8, 24, 40, 56):
        tune(t, glass, start, motif, 1.0, "glass")
    t.write(out, {"pad": lambda x: reverb(x, 3.5, 0.5, 2500), "glass": lambda x: reverb(delay(x, 0.75 * 60 / bpm, 0.45, 0.4), 3.0, 0.45)})


# ---------------------------------------------------------------- 5. Junkyard Gamelan

def junkyard_gamelan(out):
    bpm = 108
    bars = 16
    t = Track(bpm, bars * 4)
    # a slendro-ish pentatonic on D
    sl = [N(x) for x in ["D4", "E4", "G4", "A4", "C5", "D5", "E5", "G5", "A5"]]
    core = [0, 2, 1, 3, 2, 4, 3, 1, 0, 3, 2, 4, 5, 4, 3, 2]
    for bar in range(bars):
        b0 = bar * 4
        # the core melody, one note a beat, low
        for k in range(4):
            idx = core[(bar * 4 + k) % len(core)]
            t.note(metallophone, b0 + k, 1.5, sl[idx] - 12, 1.0, "bars")
        # interlocking 16ths: two parts that fill each other's gaps
        if bar >= 2:
            for k in range(16):
                idx = core[(bar * 4 + k // 4) % len(core)]
                if k % 2 == 0:
                    t.note(metallophone, b0 + k * 0.25, 0.5, sl[min(8, idx + 2)], 0.45, "bars")
                else:
                    t.note(metallophone, b0 + k * 0.25, 0.5, sl[min(8, idx + 3)], 0.4, "bars")
        # a big gong every 4 bars, clanks in threes against the fours
        if bar % 4 == 0:
            t.note(lambda f, n: metallophone(f, n) * 3, b0, 8, sl[0] - 24, 1.0, "bars")
        for k in range(16):
            if k % 3 == 0:
                t.add(b0 + k * 0.25, clank(1.0 + 0.1 * (k % 2)) * 0.9)
        if bar >= 4:
            t.add(b0, tom(70) * 0.8)
            t.add(b0 + 2.5, tom(90) * 0.5)
    t.write(out, {"bars": lambda x: reverb(x, 2.2, 0.3)})


# ---------------------------------------------------------------- 6. Dockside Bossa

def dockside_bossa(out):
    bpm = 132
    bars = 16
    t = Track(bpm, bars * 4)
    # Am7 D9 Gmaj7 Cmaj7 F#m7b5 B7 Em7 E7
    chords = [["A2", "G3", "C4", "E4"], ["D3", "F#3", "C4", "E4"], ["G2", "F#3", "B3", "D4"], ["C3", "E3", "B3", "D4"],
              ["F#2", "E3", "A3", "C4"], ["B2", "D#3", "A3", "C4"], ["E2", "D3", "G3", "B3"], ["E2", "D3", "G#3", "B3"]]
    clave = [0, 1.5, 3, 5, 6]   # 3-2 over two bars (in beats)
    for bar in range(bars):
        b0 = bar * 4
        ch = [N(x) for x in chords[bar % 8]]
        nylon = lambda f, n: pluck(f, n, 0.25, 0.995)
        for off in (0, 1.5, 2.5, 3.5):
            t.chord(nylon, b0 + off, 1.0, ch[1:], 0.7, "gtr", strum=0.015)
        t.note(muted_bass, b0, 1.4, ch[0], 0.9)
        t.note(muted_bass, b0 + 1.5, 0.5, ch[0] + 7, 0.6)
        t.note(muted_bass, b0 + 2, 1.4, ch[0] + 7, 0.7)
        t.note(muted_bass, b0 + 3.5, 0.5, ch[0], 0.6)
        for c in clave:
            if bar % 2 == (0 if c < 4 else 1):
                t.add(b0 + (c % 4), rim())
        for k in range(8):
            t.add(b0 + k * 0.5, brush() * (0.8 if k % 2 else 0.5))
    a = "E5:1.5 D5:.5 C5:1 A4:1 B4:1.5 C5:.5 D5:2 D5:1.5 C5:.5 B4:1 G4:1 A4:4"
    b = "C5:1 E5:1 G5:1.5 F#5:.5 E5:2 D5:1 B4:1 C5:1 A4:1 B4:2 G#4:2 r:2"
    tune(t, flute, 16, a, 1.0, "lead")
    tune(t, flute, 32, b, 1.0, "lead")
    tune(t, flute, 48, a, 0.9, "lead")
    t.write(out, {"gtr": lambda x: reverb(x, 1.2, 0.2), "lead": lambda x: reverb(x, 1.8, 0.3)})


# ---------------------------------------------------------------- 7. Night Shift (synthwave)

def night_shift(out):
    bpm = 100
    bars = 16
    t = Track(bpm, bars * 4)
    prog = [("A1", ["A3", "C4", "E4"]), ("F1", ["F3", "A3", "C4"]), ("C2", ["G3", "C4", "E4"]), ("G1", ["G3", "B3", "D4"])]
    for bar in range(bars):
        b0 = bar * 4
        root, ch = prog[bar % 4]
        r = N(root)
        for k in range(8):
            t.note(mm.inst_bass, b0 + k * 0.5, 0.45, r + (12 if k % 2 else 0), 0.9)
        t.chord(lambda f, n: strings(f, n) * 1.6, b0, 4, [N(x) for x in ch], 1.0, "pad")
        for k in range(16):
            t.note(mm.inst_arp, b0 + k * 0.25, 0.22, [N(x) for x in ch][[0, 1, 2, 1][k % 4]] + 12, 1.0, "arp")
        if bar >= 2:
            for beat in range(4):
                t.add(b0 + beat, mm.kick() * 0.9)
            t.add(b0 + 1, gated_snare())
            t.add(b0 + 3, gated_snare())
            for k in range(8):
                t.add(b0 + k * 0.5, mm.hat(open_=k % 2 == 1) * 0.5)
    lead = lambda f, n: mm.lp(mm.wave("saw", f, n, vib=0.01) + mm.wave("saw", f * 1.008, n), 3000) * mm.adsr(n, 0.02, 0.2, 0.7, 0.1) * 0.08
    a = "E5:1.5 D5:.5 C5:1 B4:1 C5:2 A4:2 G4:1.5 A4:.5 B4:1 C5:1 D5:4"
    b = "E5:1 G5:1 A5:2 G5:1 E5:1 D5:2 C5:1 D5:1 E5:2 B4:4"
    tune(t, lead, 16, a, 1.0, "lead")
    tune(t, lead, 32, b, 1.0, "lead")
    tune(t, lead, 48, a, 1.0, "lead")

    def sidechain(x):
        # the pad ducks under every kick: the pumping that makes it synthwave
        env = np.ones(len(x))
        for beat in range(bars * 4):
            s = t.at(beat)
            e = min(len(x), s + secs(0.3))
            env[s:e] = np.linspace(0.25, 1.0, e - s)
        return reverb(x * env, 2.0, 0.3)
    t.write(out, {"pad": sidechain, "arp": lambda x: delay(x, 0.75 * 60 / bpm, 0.4, 0.3),
                  "lead": lambda x: reverb(delay(x, 0.5 * 60 / bpm, 0.35, 0.25), 2.2, 0.35)})


# ---------------------------------------------------------------- 8. The overture (opening cutscene)
# Timed to the shots (seconds): 0 city, 8 stadium, 15 your dad's night, 27 OVERLORD, 37 the fall,
# 47 the scrapyard, 60 the road, 70 the bell. Written in seconds, not bars, so it follows the film.

THEME = [(0, 1, "D5"), (1, .5, "A4"), (1.5, .5, "D5"), (2, 1, "E5"), (3, 1, "F#5"), (4, 1.5, "G5"), (5.5, .5, "F#5"),
         (6, 1, "E5"), (7, 1, "A4"), (8, 1.5, "B4"), (9.5, .5, "C#5"), (10, 1, "D5"), (11, 1, "E5"), (12, 4, "D5")]


def overture(out):
    total = 80.0
    n = secs(total)
    buf = np.zeros(n + secs(6))
    buses = {"verb": np.zeros(len(buf))}

    def put(at_s, x, bus=None, vel=1.0):
        s = secs(at_s)
        e = min(len(buf), s + len(x))
        (buses[bus] if bus else buf)[s:e] += x[: e - s] * vel

    def nt(inst, at_s, dur_s, name, vel=1.0, bus="verb"):
        put(at_s, inst(mm.mtof(N(name) if isinstance(name, str) else name), secs(dur_s)), bus, vel)

    def theme(inst, at_s, beat_s, key_shift=0, vel=1.0, minor=False, bus="verb"):
        for b, ln, name in THEME:
            m = N(name) + key_shift
            if minor and name[0] == "F":
                m -= 1   # F# -> F: the theme in D minor
            if minor and name[0] == "C":
                m -= 1
            put(at_s + b * beat_s, inst(mm.mtof(m), secs(ln * beat_s * 0.95)), bus, vel)

    # 0-8 the city: harbour wind, a low D drone, bells far off
    put(0, noise_bed(secs(15), 150, 800, 0.05) * np.minimum(1, np.arange(secs(15)) / secs(3)))
    for k, name in enumerate(["D3", "A3", "F4"]):
        nt(strings, 0.5 + k * 0.4, 14.5, name, 0.9)
    for at, name in [(2.0, "A5"), (3.5, "F5"), (5.0, "D5"), (6.5, "E5")]:
        nt(glass, at, 2.5, name, 0.9)
    # 8-15 the stadium: drums gather, the crowd swells, the chord opens to D major
    for k in range(12):
        put(8.0 + k * 0.55, tom(70 + (k % 3) * 12), "verb", 0.4 + k * 0.05)
    crowd = mm.lp(rng.uniform(-1, 1, secs(8)), 1600) * np.linspace(0, 0.18, secs(8))
    put(8.0, crowd)
    for k, name in enumerate(["D3", "F#3", "A3", "D4"]):
        nt(brass, 12.0 + k * 0.25, 3.0, name, 0.8)
    # 15-27 your dad's night: the theme, heroic, with drums (beat = 0.5 s, 120 bpm)
    bs = 0.5
    for k in range(24):
        at = 15.0 + k * bs
        put(at, mm.kick() * 0.8)
        if k % 2:
            put(at, mm.snare() * 0.6, "verb")
        put(at + bs / 2, mm.hat() * 0.5)
    for bar in range(3):
        for k, name in enumerate([["D3", "F#3", "A3"], ["G2", "B2", "D3"], ["A2", "C#3", "E3"]][bar]):
            nt(strings, 15.0 + bar * 4, 4.0, name, 1.2)
        nt(mm.inst_bass, 15.0 + bar * 4, 3.8, ["D2", "G1", "A1"][bar], 0.8, None)
    theme(brass, 15.0, bs, 0, 1.0)
    theme(lambda f, n: mm.inst_lead2(f, n) * 0.6, 15.0, bs, 12, 0.6)
    nt(brass, 23.0, 4.0, "D4", 0.7)
    # 27 OVERLORD: everything stops. One hit, then a low grinding drone, metal pulses like footsteps
    put(27.0, boom(), None, 1.0)
    for name in ["D2", "D#2"]:
        nt(lambda f, n: mm.lp(mm.wave("saw", f, n), 400) * mm.adsr(n, 0.5, 0.2, 0.9, 1.0) * 0.12, 28.0, 9.0, name, 1.0, None)
    for k in range(6):
        put(29.0 + k * 1.3, clank(0.5) * 2.0, "verb")
        put(29.0 + k * 1.3, tom(48) * 0.6, "verb")
    # 37-47 the fall: one held note, very high, and a quiet minor pad under it
    nt(lambda f, n: mm.wave("sine", f, n, vib=0.004) * mm.adsr(n, 1.0, 0.2, 0.9, 2.0) * 0.12, 37.0, 10.0, "A5", 1.0)
    for name in ["D3", "F3", "A3"]:
        nt(strings, 38.0, 9.0, name, 0.6)
    # 47-60 the scrapyard: wind again; the theme alone on a music box, slow and in minor
    put(47.0, noise_bed(secs(13), 150, 900, 0.045) * np.minimum(1, np.arange(secs(13)) / secs(2)))
    theme(lambda f, n: inst_box(f, n), 48.5, 0.7, 12, 1.0, minor=True)
    nt(strings, 55.0, 5.0, "F3", 0.5)
    nt(strings, 55.0, 5.0, "A3", 0.5)
    # 58: the hum of ECHO waking: a rising sine
    hum = mm.wave("sine", 110, secs(2.0)) * np.linspace(0, 0.2, secs(2.0))
    put(58.0, hum)
    # 60-70 the road: the theme returns, faster and bigger (beat = 0.42 s)
    bs2 = 0.42
    for k in range(24):
        at = 60.0 + k * bs2
        put(at, mm.kick() * 0.9)
        if k % 2:
            put(at, mm.snare() * 0.7, "verb")
        for h in range(2):
            put(at + h * bs2 / 2, mm.hat(open_=h == 1) * 0.45)
    for bar in range(3):
        at = 60.0 + bar * 4 * bs2 * 2
        for name in [["D3", "F#3", "A3"], ["B2", "D3", "F#3"], ["G2", "B2", "D3"]][bar]:
            nt(strings, at, 8 * bs2, name, 1.3)
        nt(mm.inst_bass, at, 8 * bs2, ["D2", "B1", "G1"][bar], 0.9, None)
    theme(brass, 60.0, bs2, 0, 1.1)
    theme(lambda f, n: mm.inst_lead2(f, n) * 0.7, 60.0, bs2, 12, 0.7)
    # 70-78 the bell: a last big chord rings out under the bar noise
    for name in ["D3", "A3", "D4", "F#4", "A4"]:
        nt(brass, 70.1, 3.0, name, 0.8)
        nt(strings, 70.1, 7.0, name, 0.9)
    put(70.1, tom(60) * 1.2, "verb")
    x = buf + reverb(buses["verb"], 2.4, 0.35)
    x = x[: n]
    fade = secs(3.0)
    x[-fade:] *= np.linspace(1, 0, fade)
    x = np.tanh(x * 1.2)
    x = x / (np.max(np.abs(x)) or 1) * 0.85
    save_ogg(out, x)
    print("wrote", out, round(len(x) / RATE, 1), "s")


def inst_box(f, n):
    """Music box: a bright tine with a quick decay."""
    t = np.arange(n) / RATE
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 4.2 * t) * np.exp(-t * 12)
    return x * np.exp(-t * 3.0) * 0.16


SONGS = {
    "rain_docks": rain_on_the_docks,
    "harbour_waltz": harbour_waltz,
    "rust_shuffle": rust_belt_shuffle,
    "kane_tower": kane_tower,
    "gamelan": junkyard_gamelan,
    "bossa": dockside_bossa,
    "night_shift": night_shift,
    "overture": overture,
}


if __name__ == "__main__":
    out_dir = os.path.join(mm.ROOT, "music")
    only = sys.argv[1:]
    for name, fn in SONGS.items():
        if not only or name in only:
            fn(os.path.join(out_dir, name + ".ogg"))
