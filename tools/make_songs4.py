"""The makers' record (1.94): three songs for every maker in Port Ferrum, two for the menus and one
for fights. Same tools as make_songs2.py / make_songs3.py (Track, tune, instruments).

    Scrapworks      Tin Can Skiffle, Jug Band Shuffle            | fight: Pots and Pans Stomp
    Old Iron        Shift Whistle Swing, Cast Iron Heart          | fight: Foundry Rockabilly
    Brassworks      Music Box Waltz, Bandstand in the Park        | fight: Steam Engine March
    Hellfire        Slow Burn Blues, Welding Shop Groove          | fight: Anvil and Engine
    Volta           Sunset Coupe, Night Drive                     | fight: Overdrive Arc
    Nimbus          Jet Age Lounge, Above the Clouds              | fight: Tailwind Breaks
    Kane            (Kane Tower, make_songs2.py), Please Hold      | fight: Dynamics
    Tenryu          Summer Night City, Garden at Dawn             | fight: Strike a Pose!
    Menagerie       Calliope Waltz, Tango of the Beasts           | fight: Big Top Galop

    python3 tools/make_songs4.py               (needs numpy, scipy, soundfile)
    python3 tools/make_songs4.py iron_ballad   (only the named songs)
All synthesized from scratch, 100% original.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_music as mm  # noqa: E402
from make_songs2 import (Track, N, tune, rhodes, muted_bass, brush, rim, pluck, strings, glass, soft_sine,  # noqa: E402
                         accordion, harmonica, flute, sub, reverb, delay, secs, noise_bed, tick, brass, metallophone,
                         clank, tom, gated_snare, boom)
from make_songs3 import piano, slap, upright, clap  # noqa: E402

RATE = mm.RATE
rng = np.random.default_rng(1994)


# ---------------------------------------------------------------- instruments

def env_t(n):
    return np.arange(n) / RATE


def washboard():
    n = secs(0.07)
    return mm.bp(rng.uniform(-1, 1, n), 2500, 9000) * np.exp(-env_t(n) * 40) * 0.5


def jug(f, n):
    x = mm.wave("sine", f, n, vib=0.03, vib_rate=5.5) + 0.3 * mm.wave("tri", f * 2, n)
    breath = mm.bp(rng.uniform(-1, 1, n), f, f * 4) * 0.4
    return mm.lp(x + breath, 900) * mm.adsr(n, 0.04, 0.1, 0.7, 0.06) * 0.35


def banjo(f, n):
    return mm.hp(pluck(f, n, 0.95, 0.985), 300) * 1.2


def kazoo(f, n):
    x = mm.wave("saw", f, n, vib=0.02, vib_rate=6)
    x = x + 0.5 * np.sign(np.sin(2 * np.pi * 90 * env_t(n))) * mm.wave("saw", f, n) * 0.3
    return mm.bp(x, 500, 3000) * mm.adsr(n, 0.02, 0.1, 0.8, 0.05) * 0.08


def honk():
    n = secs(0.35)
    t = env_t(n)
    x = np.sign(np.sin(2 * np.pi * 330 * t)) + np.sign(np.sin(2 * np.pi * 415 * t))
    return mm.bp(x, 300, 2500) * mm.adsr(n, 0.01, 0.05, 0.9, 0.05) * 0.12


def pot(pitch=1.0):
    return clank(pitch) * 1.2


def whistle(start, end, n):
    """A factory shift whistle: a breathy chord gliding up."""
    t = env_t(n)
    f = start + (end - start) * np.clip(t * 3, 0, 1)
    x = sum(np.sin(2 * np.pi * np.cumsum(f * r) / RATE) for r in (1.0, 1.26, 1.5))
    x += mm.bp(rng.uniform(-1, 1, n), 1000, 4000) * 0.5
    return x * mm.adsr(n, 0.05, 0.2, 0.8, 0.4) * 0.05


def sax(f, n):
    x = mm.wave("saw", f, n, vib=0.012, vib_rate=5.2)
    t = env_t(n)
    x = mm.lp(x, 2400) * (0.6 + 0.4 * np.clip(t * 5, 0, 1))
    return x * mm.adsr(n, 0.04, 0.1, 0.8, 0.08) * 0.07


def twang(f, n):
    """A clean electric guitar with slapback."""
    x = pluck(f, n, 0.8, 0.992)
    x = np.tanh(x * 2.0) * 0.6
    return mm.hp(x, 150)


def music_box(f, n):
    t = env_t(n)
    x = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 4.02 * t) * np.exp(-t * 8)
    return x * np.exp(-t * 4.5) * mm.adsr(n, 0.001, 0.0, 1.0, 0.05) * 0.1


def tuba(f, n):
    x = mm.wave("saw", f, n, vib=0.004) + mm.wave("sine", f, n)
    return mm.lp(x, 700) * mm.adsr(n, 0.03, 0.1, 0.7, 0.06) * 0.22


def cornet(f, n):
    return brass(f, n) * 1.4


def piston_hit():
    n = secs(0.16)
    t = env_t(n)
    hiss = mm.bp(rng.uniform(-1, 1, n), 3000, 9000) * np.exp(-t * 18) * 0.5
    c = clank(0.7) * 0.4
    c[:n] += hiss
    return c


def dirty(f, n):
    """An overdriven blues guitar."""
    x = pluck(f, n, 0.7, 0.995)
    return mm.lp(np.tanh(x * 6.0), 3200) * 0.35


def organ(f, n):
    t = env_t(n)
    x = sum(np.sin(2 * np.pi * f * h * t) * a for h, a in ((1, 1.0), (2, 0.6), (3, 0.4), (4, 0.25), (6, 0.15)))
    x *= 1 + 0.15 * np.sin(2 * np.pi * 6.5 * t)
    return x * mm.adsr(n, 0.01, 0.05, 0.9, 0.06) * 0.045


def anvil():
    n = secs(0.8)
    t = env_t(n)
    x = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((1180, 3), (2767, 5), (4310, 7), (6210, 9)))
    return (x * 0.3 + mm.bp(rng.uniform(-1, 1, n), 3000, 9000) * np.exp(-t * 60)) * 0.3


def rev(n_beats_s, lo=50, hi=180):
    n = secs(n_beats_s)
    t = env_t(n)
    f = lo + (hi - lo) * (t / (n / RATE)) ** 1.5
    ph = np.cumsum(f) / RATE
    x = 2 * (ph % 1.0) - 1 + 0.6 * (2 * ((ph * 2.01) % 1.0) - 1)
    return np.tanh(mm.lp(x, 900) * 2) * mm.adsr(n, 0.05, 0.1, 0.9, 0.1) * 0.12


def supersaw(f, n):
    x = sum(mm.wave("saw", f * d, n) for d in (0.991, 0.997, 1.0, 1.004, 1.009))
    return mm.lp(x, 3500) * mm.adsr(n, 0.01, 0.15, 0.6, 0.1) * 0.03


def synth_bass(f, n):
    x = mm.wave("saw", f, n) + mm.wave("pulse", f * 0.5, n, duty=0.5) * 0.6
    return mm.lp(x, 700) * mm.adsr(n, 0.003, 0.1, 0.6, 0.04) * 0.4


def arp(f, n):
    return mm.lp(mm.wave("saw", f, n) + mm.wave("pulse", f * 2, n, duty=0.25) * 0.4, 3000) * mm.adsr(n, 0.002, 0.08, 0.2, 0.03) * 0.06


def vibes(f, n):
    t = env_t(n)
    x = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 6)
    return x * np.exp(-t * 1.5) * (1 + 0.35 * np.sin(2 * np.pi * 5.5 * t)) * 0.07


def airpad(f, n):
    x = mm.wave("sine", f, n, vib=0.004) + 0.4 * mm.wave("tri", f * 1.002, n) + 0.2 * mm.wave("sine", f * 2.003, n)
    return x * mm.adsr(n, 1.2, 0.5, 0.9, 1.5) * 0.06


def whoosh(seconds=0.6):
    n = secs(seconds)
    t = env_t(n)
    x = rng.uniform(-1, 1, n)
    y = np.zeros(n)
    acc = 0.0
    for k in range(n):
        a = 0.02 + 0.3 * (t[k] / seconds)
        acc += a * (x[k] - acc)
        y[k] = acc
    return y * np.sin(np.pi * t / seconds) * 0.5


def epiano(f, n):
    return rhodes(f, n) * 1.3


def koto(f, n):
    t = env_t(n)
    bend = 1 + 0.02 * np.exp(-t * 25)
    p = max(2, int(RATE / f))
    x = pluck(f, n, 0.9, 0.994)
    return mm.hp(x, 200) * 1.3 * (1 + 0.0 * bend[0])


def shakuhachi(f, n):
    t = env_t(n)
    x = mm.wave("sine", f, n, vib=0.012, vib_rate=4.5) + 0.25 * mm.wave("sine", f * 2, n)
    breath = mm.bp(rng.uniform(-1, 1, n), f, min(f * 4, 11000)) * (0.5 + 0.5 * np.exp(-t * 6))
    return (x + breath * 0.6) * mm.adsr(n, 0.12, 0.1, 0.8, 0.15) * 0.12


def calliope(f, n):
    x = mm.wave("pulse", f, n, vib=0.02, vib_rate=7, duty=0.4) * 0.6 + mm.wave("sine", f * 2, n, vib=0.02, vib_rate=7) * 0.5
    return mm.lp(x, 3000) * mm.adsr(n, 0.02, 0.05, 0.85, 0.05) * 0.09


def pizz(f, n):
    return pluck(f, n, 0.5, 0.98) * 0.9


def bandoneon(f, n):
    return accordion(f, n) * 1.1 + mm.lp(mm.wave("saw", f * 0.5, n), 600) * mm.adsr(n, 0.04, 0.1, 0.8, 0.08) * 0.03


def steps(t, b0, pattern, sounds, step=0.25, vel=1.0):
    """'k...s...' -> one hit per letter (16th notes by default), sounds: letter -> sound function."""
    for k, c in enumerate(pattern):
        if c in sounds:
            snd = sounds[c]
            t.add(b0 + k * step, snd() * vel)


def chord_of(names):
    return [N(x) for x in names]


DR = {"k": lambda: mm.kick(), "s": lambda: mm.snare(), "h": lambda: mm.hat(), "o": lambda: mm.hat(open_=True),
      "c": clap, "r": rim, "g": gated_snare, "t": lambda: tom(110), "l": lambda: tom(75)}


# ================================================================= SCRAPWORKS

def scrap_skiffle(out):
    bpm = 132
    bars = 44
    t = Track(bpm, bars * 4)
    prog = ["G", "G", "C", "G", "D", "C", "G", "D"]
    ch = {"G": ["G3", "B3", "D4"], "C": ["C3", "E3", "G3", "C4"], "D": ["D3", "F#3", "A3", "C4"]}
    root = {"G": "G2", "C": "C2", "D": "D2"}
    for bar in range(bars):
        b0 = bar * 4
        c = prog[bar % 8]
        r = N(root[c])
        for k in range(4):
            t.chord(banjo, b0 + k + 0.5, 0.4, chord_of(ch[c]), 0.55, "pick")
            t.note(jug, b0 + k, 0.45, r + (0 if k % 2 == 0 else 7), 0.9)
        if bar >= 2:
            for k in range(8):
                t.add(b0 + k * 0.5, washboard() * (1.0 if k % 2 else 0.6))
            t.add(b0 + 1, pot(1.0) * 0.4)
            t.add(b0 + 3, pot(1.2) * 0.4)
    a = "B4:.5 D5:.5 G5:1 E5:.5 D5:.5 B4:1 C5:.5 E5:.5 G5:1 E5:1 D5:2 B4:.5 A4:.5 G4:1 A4:1 B4:.5 D5:.5 D5:2 r:2"
    b = "D5:.5 E5:.5 F#5:1 A5:1 G5:1 E5:.5 C5:.5 E5:1 G5:1 D5:1 B4:1 A4:1 G4:3 r:2"
    for s, m, inst in ((16, a, kazoo), (32, b, kazoo), (48, a, harmonica), (64, b, kazoo), (96, a, kazoo), (112, b, harmonica), (128, a, kazoo), (144, b, kazoo)):
        tune(t, inst, s, m, 1.0, "lead")
    t.add(60, honk() * 0.6)
    t.add(124, honk() * 0.6)
    t.write(out, {"pick": lambda x: reverb(x, 0.8, 0.15), "lead": lambda x: reverb(x, 1.0, 0.18)})


def scrap_jug(out):
    bpm = 96
    bars = 36
    t = Track(bpm, bars * 4)
    sw = 0.17
    prog = ["E", "E", "A", "E", "B", "A", "E", "B"]
    ch = {"E": ["E3", "G#3", "B3", "D4"], "A": ["A2", "C#3", "E3", "G3"], "B": ["B2", "D#3", "F#3", "A3"]}
    root = {"E": "E2", "A": "A1", "B": "B1"}
    for bar in range(bars):
        b0 = bar * 4
        c = prog[bar % 8]
        r = N(root[c])
        for k in range(4):
            t.note(jug, b0 + k, 0.6, r + [0, 7, 12, 7][k], 1.0)
            t.chord(lambda f, n: pluck(f, n, 0.5, 0.99), b0 + k + 0.5 + sw, 0.3, chord_of(ch[c]), 0.45, "pick")
            t.add(b0 + k, washboard() * 0.5)
            t.add(b0 + k + 0.5 + sw, washboard() * 0.8)
    a = "B4:1 G#4:.5 B4:.5 C#5:1 B4:1 G#4:.5 E4:.5 F#4:1 E4:2 r:1 E5:.5 D5:.5 B4:1 A4:1 G#4:.5 F#4:.5 E4:3 r:2"
    for s, inst in ((8, harmonica), (40, kazoo), (72, harmonica), (104, kazoo)):
        tune(t, inst, s, a, 1.0, "lead", sw)
    t.buf += noise_bed(len(t.buf), 200, 1200, 0.004)
    t.write(out, {"pick": lambda x: reverb(x, 0.9, 0.18), "lead": lambda x: reverb(x, 1.2, 0.2)})


def scrap_stomp(out):
    bpm = 150
    bars = 48
    t = Track(bpm, bars * 4)
    for bar in range(bars):
        b0 = bar * 4
        steps(t, b0, "k.k.s.k.k.k.s...", {"k": lambda: mm.kick(), "s": lambda: pot(0.8)})
        steps(t, b0, "h.h.h.h.h.h.h.hh", {"h": washboard}, vel=0.8)
        r = N("D2") if bar % 4 < 2 else N("F2")
        for k in range(8):
            t.note(lambda f, n: np.tanh(muted_bass(f, n) * 3) * 0.4, b0 + k * 0.5, 0.3, r + (12 if k == 3 else 0), 1.0)
        if bar % 4 == 3:
            t.add(b0 + 3, honk() * 0.8)
            steps(t, b0 + 2, "tttt", {"t": lambda: pot(1.4)}, vel=0.6)
        if bar >= 8 and bar % 2 == 0:
            t.chord(lambda f, n: banjo(f, n) * 0.8, b0, 0.3, [r + 24, r + 27, r + 31], 0.6, "pick")
            t.chord(lambda f, n: banjo(f, n) * 0.8, b0 + 1.5, 0.3, [r + 24, r + 27, r + 31], 0.6, "pick")
    riff = "D5:.5 D5:.5 F5:.5 D5:.5 G5:.5 F5:.5 D5:1 C5:.5 D5:.5 F5:.5 A5:.5 G5:1 F5:1"
    for s in range(32, 192, 16):
        tune(t, kazoo, s, riff, 1.1, "lead")
    t.write(out, {"pick": lambda x: reverb(x, 0.6, 0.12), "lead": lambda x: reverb(x, 0.8, 0.15)})


# ================================================================= OLD IRON FOUNDRY

def iron_bigband(out):
    bpm = 140
    bars = 40
    t = Track(bpm, bars * 4)
    sw = 0.17
    prog = [["F3", "A3", "C4", "E4"], ["D3", "F3", "A3", "C4"], ["G3", "Bb3", "D4", "F4"], ["C3", "E3", "G3", "Bb3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        r = ch[0] - 12
        for k, m in enumerate([r, r + 4, r + 7, r + 9]):
            t.note(upright, b0 + k, 0.9, m, 0.9)
        t.chord(brass, b0 + 1.5 + sw, 0.4, ch, 0.7, "horns")
        t.chord(brass, b0 + 3.5 + sw, 0.4, ch, 0.6, "horns")
        for k in range(4):
            t.add(b0 + k, tick() * 0.5)
            t.add(b0 + k + 0.5 + sw, tick() * 0.3)
            t.add(b0 + k, brush() * 0.8)
        t.add(b0 + 1, rim() * 0.5)
        t.add(b0 + 3, rim() * 0.5)
    a = "C5:.5 D5:.5 F5:1 A5:1 G5:.5 F5:.5 D5:1 F5:1 E5:2 r:1 C5:.5 D5:.5 F5:1 G5:1 A5:.5 Bb5:.5 A5:1 G5:2 r:2"
    b = "A5:.5 G5:.5 F5:1 D5:1 F5:.5 G5:.5 A5:1 C6:1 Bb5:1 A5:1 G5:2 F5:3 r:3"
    for s, m, inst in ((8, a, sax), (24, b, sax), (40, a, cornet), (56, b, sax), (88, a, sax), (104, b, cornet), (120, a, sax), (136, b, cornet)):
        tune(t, inst, s, m, 1.0, "lead", sw)
    t.add(0, whistle(380, 520, secs(2.0)))
    t.add(78, whistle(380, 520, secs(2.0)) * 0.8)
    t.add(80, clank(0.6) * 1.2)
    t.write(out, {"horns": lambda x: reverb(x, 1.2, 0.2), "lead": lambda x: reverb(x, 1.4, 0.22)})


def iron_ballad(out):
    bpm = 72
    bars = 24
    t = Track(bpm, bars * 4, tail=3.0)
    # 12/8 feel: triplets over C Am F G
    prog = [["C3", "E3", "G3"], ["A2", "C3", "E3"], ["F2", "A2", "C3"], ["G2", "B2", "D3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        for k in range(12):
            m = ch[k % 3] + 12 * (1 if k % 6 >= 3 else 0)
            t.note(twang, b0 + k / 3.0, 0.6, m + 12, 0.55, "gtr")
        t.note(upright, b0, 1.4, ch[0] - 12, 0.9)
        t.note(upright, b0 + 2, 1.4, ch[0] - 5, 0.7)
        t.add(b0 + 1, brush() * 1.1)
        t.add(b0 + 3, brush() * 1.1)
        t.add(b0 + 1, rim() * 0.4)
        t.add(b0 + 3, rim() * 0.4)
    mel = "G5:1.33 E5:.67 G5:1 A5:1 G5:2 E5:2 F5:1.33 E5:.67 D5:1 C5:1 D5:4 E5:1.33 D5:.67 C5:1 A4:1 C5:2 E5:2 D5:1.33 C5:.67 B4:1 D5:1 C5:4"
    tune(t, lambda f, n: twang(f, n) * 1.1, 16, mel, 1.0, "lead")
    tune(t, sax, 48, mel, 0.9, "lead")
    t.write(out, {"gtr": lambda x: reverb(delay(x, 0.11, 0.2, 0.3), 1.5, 0.25), "lead": lambda x: reverb(delay(x, 0.11, 0.25, 0.35), 2.0, 0.3)})


def iron_rockabilly(out):
    bpm = 176
    bars = 64
    t = Track(bpm, bars * 4)
    prog = ["A", "A", "A", "A", "D", "D", "A", "A", "E", "D", "A", "E"]
    roots = {"A": "A1", "D": "D2", "E": "E2"}
    for bar in range(bars):
        b0 = bar * 4
        c = prog[bar % 12]
        r = N(roots[c])
        for k, d in enumerate([0, 4, 7, 9, 10, 9, 7, 4]):
            t.note(slap, b0 + k * 0.5, 0.45, r + d, 1.0)
        for k in range(4):
            t.chord(lambda f, n: twang(f, n) * 0.6, b0 + k + 0.5, 0.25, [r + 24, r + 31, r + 33 if k % 2 else r + 31], 0.5, "gtr")
        steps(t, b0, "k...s...k.k.s...", DR)
        steps(t, b0, "h.h.h.h.h.h.h.h.", DR, vel=0.6)
        if bar % 4 == 3:
            t.add(b0 + 3.5, clank(0.9) * 1.1)
    riff = "A4:.5 C5:.5 C#5:.5 E5:.5 A5:1 G5:.5 E5:.5 G5:.5 E5:.5 C#5:.5 C5:.5 A4:2"
    for s in range(48, 256, 16):
        if (s // 16) % 3 != 2:
            tune(t, lambda f, n: twang(f, n) * 1.2, s, riff, 1.0, "lead")
    t.write(out, {"gtr": lambda x: delay(x, 0.09, 0.2, 0.3), "lead": lambda x: reverb(delay(x, 0.09, 0.25, 0.35), 1.0, 0.2)})


# ================================================================= BRASSWORKS & SONS

def brass_musicbox(out):
    bpm = 120
    bars = 48
    t = Track(bpm, bars * 3, tail=3.0)
    prog = [["D4", "F#4", "A4"], ["G3", "B3", "D4"], ["A3", "C#4", "E4"], ["D4", "F#4", "A4"], ["B3", "D4", "F#4"], ["G3", "B3", "D4"], ["E3", "G3", "B3"], ["A3", "C#4", "E4"]]
    for bar in range(bars):
        b0 = bar * 3
        ch = chord_of(prog[bar % 8])
        t.note(music_box, b0, 1.5, ch[0] - 12, 0.8, "box")
        t.chord(music_box, b0 + 1, 0.8, ch, 0.35, "box")
        t.chord(music_box, b0 + 2, 0.8, ch, 0.35, "box")
    mel = "F#5:2 E5:1 D5:1.5 E5:.5 F#5:1 G5:2 F#5:1 E5:3 A5:2 G5:1 F#5:1.5 E5:.5 D5:1 B4:2 C#5:1 D5:3"
    for s in (12, 36, 72, 96, 120):
        tune(t, music_box, s, mel, 1.0, "box")
    # the winding key, now and then
    for at in (0, 70):
        for k in range(6):
            t.add(at + k * 0.25, tick() * 0.6)
    t.write(out, {"box": lambda x: reverb(x, 2.0, 0.3)})


def brass_bandstand(out):
    bpm = 108
    bars = 40
    t = Track(bpm, bars * 4)
    prog = [["Bb2", "D3", "F3"], ["Eb3", "G3", "Bb3"], ["F2", "A2", "C3", "Eb3"], ["Bb2", "D3", "F3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        t.note(tuba, b0, 0.9, ch[0] - 12, 1.0)
        t.note(tuba, b0 + 2, 0.9, ch[1] - 12, 0.9)
        t.chord(lambda f, n: brass(f, n) * 0.8, b0 + 1, 0.6, [m + 12 for m in ch], 0.5, "band")
        t.chord(lambda f, n: brass(f, n) * 0.8, b0 + 3, 0.6, [m + 12 for m in ch], 0.5, "band")
        t.add(b0, mm.kick() * 0.5)
        t.add(b0 + 2, mm.kick() * 0.4)
        t.add(b0 + 1, mm.snare() * 0.3)
        t.add(b0 + 3, mm.snare() * 0.3)
    a = "F5:1 D5:.5 F5:.5 Bb5:2 A5:1 G5:1 F5:2 Eb5:1 G5:1 F5:1 D5:1 C5:3 r:1 D5:1 F5:1 Bb5:1.5 A5:.5 G5:1 Eb5:1 F5:2 D5:1 C5:1 Bb4:3 r:1"
    for s, inst in ((16, cornet), (48, lambda f, n: flute(f, n) * 1.1), (96, cornet), (128, cornet)):
        tune(t, inst, s, a, 1.0, "lead")
    t.buf += noise_bed(len(t.buf), 300, 2000, 0.005)   # the park
    t.write(out, {"band": lambda x: reverb(x, 1.6, 0.28), "lead": lambda x: reverb(x, 1.8, 0.3)})


def brass_march(out):
    bpm = 126
    bars = 56
    t = Track(bpm, bars * 4)
    prog = ["C", "C", "G", "G", "F", "C", "G", "C"]
    ch = {"C": ["C3", "E3", "G3"], "G": ["G2", "B2", "D3", "F3"], "F": ["F2", "A2", "C3"]}
    for bar in range(bars):
        b0 = bar * 4
        c = chord_of(ch[prog[bar % 8]])
        for k in range(4):
            t.note(tuba, b0 + k, 0.45, c[0] - 12 if k % 2 == 0 else c[2] - 12, 1.0)
            t.chord(lambda f, n: brass(f, n) * 0.7, b0 + k + 0.5, 0.3, [m + 12 for m in c], 0.5, "band")
        steps(t, b0, "k.s.k.s.k.s.ksss", {"k": lambda: mm.kick(), "s": mm.snare}, vel=0.7)
        steps(t, b0, "p...p...p...p...", {"p": piston_hit}, vel=0.9)
        if bar % 8 == 7:
            t.add(b0 + 2, whistle(600, 760, secs(1.2)) * 0.9)
    a = "G5:.75 G5:.25 C6:1 G5:.5 E5:.5 C5:1 D5:.5 E5:.5 F5:.5 D5:.5 G5:2 A5:.75 G5:.25 F5:1 E5:.5 D5:.5 C5:1 D5:.5 G4:.5 B4:.5 D5:.5 C5:2"
    for s in range(32, 224, 32):
        tune(t, cornet, s, a, 1.1, "lead")
    t.write(out, {"band": lambda x: reverb(x, 1.0, 0.18), "lead": lambda x: reverb(x, 1.2, 0.2)})


# ================================================================= HELLFIRE HEAVY

def hell_blues(out):
    bpm = 66
    bars = 24
    t = Track(bpm, bars * 4, tail=3.0)
    sw = 0.17
    prog = ["E", "A", "E", "E", "A", "A", "E", "E", "B", "A", "E", "B"]
    roots = {"E": "E2", "A": "A2", "B": "B2"}
    for bar in range(bars):
        b0 = bar * 4
        r = N(roots[prog[bar % 12]])
        for k in range(4):
            t.note(dirty, b0 + k, 0.45, r, 0.7, "gtr")
            t.note(dirty, b0 + k + 0.5 + sw, 0.35, r + (7 if k % 2 == 0 else 9), 0.6, "gtr")
        t.note(lambda f, n: mm.lp(mm.wave("saw", f, n), 400) * mm.adsr(n, 0.01, 0.1, 0.7, 0.05) * 0.4, b0, 3.8, r - 12, 0.8)
        t.add(b0, mm.kick() * 0.9)
        t.add(b0 + 2.5 + sw, mm.kick() * 0.6)
        t.add(b0 + 1, mm.snare() * 0.8)
        t.add(b0 + 3, mm.snare() * 0.8)
        for k in range(4):
            t.add(b0 + k + 0.5 + sw, tick() * 0.5)
    lick = "B4:.67 D5:.33 E5:1 G5:.5 E5:.5 D5:1 B4:1 A4:.5 G4:.5 E4:2 r:2"
    for s in (16, 32, 56, 72, 88):
        tune(t, lambda f, n: dirty(f, n) * 1.2, s, lick, 1.0, "lead", sw)
    tune(t, organ, 40, "E4:4 G4:4 A4:4 B4:4", 0.6, "org")
    t.write(out, {"gtr": lambda x: reverb(x, 1.2, 0.2), "lead": lambda x: reverb(delay(x, 0.6, 0.25, 0.2), 1.8, 0.28), "org": lambda x: reverb(x, 2.0, 0.3)})


def hell_groove(out):
    bpm = 98
    bars = 40
    t = Track(bpm, bars * 4)
    for bar in range(bars):
        b0 = bar * 4
        steps(t, b0, "k..k..s.k.k...s.", DR)
        steps(t, b0, "a.......a...a...", {"a": anvil}, vel=0.5)
        steps(t, b0, "h.hhh.hhh.hhh.hh", DR, vel=0.5)
        r = N("A1") if bar % 8 < 6 else N("C2")
        for k, (o, d) in enumerate([(0, 0), (0.75, 0), (1.5, 12), (2.5, 10), (3.0, 7), (3.5, 0)]):
            t.note(lambda f, n: np.tanh(synth_bass(f, n) * 2.5) * 0.4, b0 + o, 0.4, r + d, 1.0)
        if bar % 2 == 1:
            t.add(b0 + 2, mm.bp(rng.uniform(-1, 1, secs(0.6)), 2000, 8000) * np.exp(-env_t(secs(0.6)) * 5) * 0.25, "fx")  # a welding hiss
        if bar >= 8:
            t.chord(lambda f, n: dirty(f, n) * 0.7, b0, 0.8, [r + 12, r + 19], 0.6, "gtr")
            t.chord(lambda f, n: dirty(f, n) * 0.7, b0 + 2.5, 0.5, [r + 15, r + 22], 0.5, "gtr")
    t.write(out, {"gtr": lambda x: reverb(x, 1.0, 0.2), "fx": lambda x: reverb(x, 1.5, 0.3)})


def hell_riff(out):
    bpm = 150
    bars = 56
    t = Track(bpm, bars * 4)
    t.add(0, rev(6.0, 40, 160) * 1.2)
    for bar in range(bars):
        b0 = bar * 4
        if bar < 4:
            steps(t, b0, "k...k...k...k.k.", DR, vel=0.6)
            continue
        steps(t, b0, "k.k.s..kk.k.s...", DR)
        steps(t, b0, "o.h.o.h.o.h.o.h.", DR, vel=0.5)
        r = N("E2") if bar % 8 < 4 else (N("G2") if bar % 8 < 6 else N("A2"))
        pat = [0, 0, 12, 0, 10, 0, 7, 5]
        for k in range(8):
            t.chord(lambda f, n: np.tanh(mm.inst_chug(f, n) * 1.5), b0 + k * 0.5, 0.4, [r + pat[k], r + pat[k] + 7], 0.8, "gtr")
        if bar % 4 == 0:
            t.add(b0, anvil() * 0.9)
        if bar % 16 == 15:
            t.add(b0, rev(1.6, 60, 200))
    lead = "E5:1 G5:.5 A5:.5 B5:1 A5:.5 G5:.5 E5:2 D5:1 E5:3"
    for s in range(64, 224, 16):
        if (s // 16) % 2 == 0:
            tune(t, lambda f, n: dirty(f, n) * 1.2, s, lead, 1.0, "lead")
    t.write(out, {"gtr": lambda x: x * 0.9, "lead": lambda x: reverb(delay(x, 0.4, 0.3, 0.2), 1.0, 0.2)})


# ================================================================= VOLTA MOTOR

def volta_sunset(out):
    bpm = 104
    bars = 40
    t = Track(bpm, bars * 4)
    prog = [["F3", "A3", "C4", "E4"], ["E3", "G3", "B3", "D4"], ["D3", "F3", "A3", "C4"], ["C3", "E3", "G3", "B3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        t.chord(lambda f, n: mm.inst_pad(f, n) * 1.4, b0, 4.0, ch, 0.8, "pad")
        for k in range(8):
            t.note(synth_bass, b0 + k * 0.5, 0.4, ch[0] - 12 + (12 if k % 2 else 0), 0.8)
        if bar >= 4:
            steps(t, b0, "k...g...k.k.g...", DR)
            steps(t, b0, "h.h.h.h.h.h.h.h.", DR, vel=0.5)
        for k in range(16):
            t.note(arp, b0 + k * 0.25, 0.2, ch[k % 4] + 12, 0.6, "arp")
    a = "E5:1 G5:.5 A5:.5 C6:1 B5:1 A5:2 G5:1 E5:1 D5:1 E5:.5 G5:.5 A5:2 G5:2 E5:4"
    for s in (32, 64, 96, 128):
        tune(t, lambda f, n: mm.inst_lead(f, n) * 0.6 + supersaw(f, n), s, a, 1.0, "lead")
    t.write(out, {"pad": lambda x: reverb(x, 2.0, 0.3), "arp": lambda x: delay(x, 0.75 * 60 / bpm, 0.3, 0.25),
                  "lead": lambda x: reverb(delay(x, 0.5 * 60 / bpm, 0.3, 0.2), 1.8, 0.3)})


def volta_drive(out):
    bpm = 112
    bars = 48
    t = Track(bpm, bars * 4)
    prog = [["A2", "C3", "E3"], ["F2", "A2", "C3"], ["C3", "E3", "G3"], ["G2", "B2", "D3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[(bar // 2) % 4])
        for k in range(16):
            t.note(synth_bass, b0 + k * 0.25, 0.2, ch[0] - 12 + (12 if k % 4 == 2 else 0), 0.7)
        t.chord(lambda f, n: supersaw(f, n) * 0.6, b0, 4.0, [m + 12 for m in ch], 0.5, "pad")
        if bar >= 4:
            steps(t, b0, "k...g...k...g...", DR)
            steps(t, b0, "..h...h...h...h.", DR, vel=0.6)
    a = "E5:2 D5:1 C5:1 D5:2 A4:2 C5:1 D5:1 E5:1 G5:1 E5:4 F5:2 E5:1 D5:1 C5:2 E5:2 D5:1 C5:1 B4:1 G4:1 A4:4"
    for s in (32, 64, 128, 160):
        tune(t, lambda f, n: mm.inst_lead2(f, n) * 0.6 + supersaw(f, n) * 0.6, s, a, 1.0, "lead")
    t.write(out, {"pad": lambda x: reverb(x, 2.4, 0.35), "lead": lambda x: reverb(delay(x, 0.75 * 60 / bpm, 0.35, 0.3), 2.0, 0.3)})


def volta_fight(out):
    bpm = 150
    bars = 56
    t = Track(bpm, bars * 4)
    prog = [["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["C3", "E3", "G3"], ["A2", "C#3", "E3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[(bar // 2) % 4])
        for k in range(16):
            t.note(arp, b0 + k * 0.25, 0.2, ch[k % 3] + 12 + (12 if (k // 3) % 2 else 0), 0.7, "arp")
            t.note(synth_bass, b0 + k * 0.25, 0.2, ch[0] - 12, 0.6 if k % 2 else 0.9)
        steps(t, b0, "k...g.k.k.k.g...", DR)
        steps(t, b0, "hhhhhhhhhhhhhhhh", DR, vel=0.4)
        if bar % 8 == 7:
            steps(t, b0 + 2, "gggggggg", DR, step=0.25, vel=0.5)
    a = "A5:.5 F5:.5 D5:.5 F5:.5 A5:1 Bb5:1 A5:.5 G5:.5 E5:.5 G5:.5 A5:2"
    for s in range(32, 224, 16):
        tune(t, lambda f, n: supersaw(f, n) * 1.2, s, a, 1.0, "lead")
    t.write(out, {"arp": lambda x: delay(x, 0.75 * 60 / bpm, 0.25, 0.2), "lead": lambda x: reverb(x, 1.2, 0.22)})


# ================================================================= NIMBUS AERIAL

def nimbus_lounge(out):
    bpm = 100
    bars = 36
    t = Track(bpm, bars * 4)
    sw = 0.12
    prog = [["G3", "B3", "D4", "F#4"], ["E3", "G3", "B3", "D4"], ["A3", "C4", "E4", "G4"], ["D3", "F#3", "A3", "C4"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        t.chord(vibes, b0, 2.0, ch, 0.6, "vib")
        t.chord(vibes, b0 + 2.5 + sw, 1.0, ch, 0.4, "vib")
        for k, d in enumerate([0, 7, 12, 7]):
            t.note(upright, b0 + k, 0.9, ch[0] - 12 + d, 0.8)
        for k in range(4):
            t.add(b0 + k, brush() * 0.8)
            t.add(b0 + k + 0.5 + sw, tick() * 0.3)
    a = "D5:1 E5:.5 F#5:.5 A5:2 G5:1 E5:1 D5:2 r:1 B4:.5 D5:.5 E5:1 G5:1 F#5:4"
    for s in (16, 48, 80, 112):
        tune(t, lambda f, n: flute(f, n) * 0.9, s, a, 1.0, "lead", sw)
    t.add(0, whoosh(1.5) * 0.6)
    t.add(72, whoosh(1.5) * 0.6)
    t.write(out, {"vib": lambda x: reverb(x, 1.8, 0.3), "lead": lambda x: reverb(x, 2.0, 0.3)})


def nimbus_clouds(out):
    bpm = 60
    bars = 24
    t = Track(bpm, bars * 4, tail=5.0)
    prog = [["C3", "G3", "D4", "E4"], ["A2", "E3", "B3", "C4"], ["F2", "C3", "G3", "A3"], ["G2", "D3", "A3", "B3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        t.chord(airpad, b0, 4.5, ch + [ch[1] + 12], 0.8, "pad")
        if bar % 2 == 1:
            t.note(glass, b0 + 1, 3.0, ch[3] + 24, 0.5, "air")
            t.note(glass, b0 + 2.5, 2.0, ch[2] + 24, 0.4, "air")
    for at in (8, 40, 72):
        t.add(at, whoosh(3.0) * 0.4, "air")
    t.write(out, {"pad": lambda x: reverb(x, 4.0, 0.5), "air": lambda x: reverb(delay(x, 0.75, 0.4, 0.3), 3.5, 0.5)})


def nimbus_breaks(out):
    bpm = 168
    bars = 64
    t = Track(bpm, bars * 4)
    prog = [["E3", "G3", "B3", "D4"], ["C3", "E3", "G3", "B3"], ["A2", "C3", "E3", "G3"], ["B2", "D#3", "F#3", "A3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[(bar // 2) % 4])
        steps(t, b0, "k.h.s.hkh.k.s.hh", {**DR, "h": lambda: mm.hat()})
        if bar % 2 == 0:
            t.chord(airpad, b0, 8.0, ch, 0.6, "pad")
        for k in range(8):
            t.note(synth_bass, b0 + k * 0.5, 0.35, ch[0] - 12 + (7 if k == 5 else 0), 0.7)
        if bar % 8 == 7:
            t.add(b0 + 2, whoosh(0.7) * 0.9)
    a = "B5:.5 A5:.5 G5:.5 E5:.5 G5:1 A5:.5 B5:.5 D6:1 B5:1 A5:2"
    for s in range(64, 256, 16):
        tune(t, lambda f, n: vibes(f, n) * 1.4 + flute(f, n) * 0.4, s, a, 1.0, "lead")
    t.write(out, {"pad": lambda x: reverb(x, 2.0, 0.3), "lead": lambda x: reverb(delay(x, 0.75 * 60 / bpm, 0.3, 0.25), 1.4, 0.25)})


# ================================================================= KANE DYNAMICS

def kane_hold(out):
    bpm = 92
    bars = 32
    t = Track(bpm, bars * 4)
    prog = [["C3", "E3", "G3", "B3"], ["A2", "C3", "E3", "G3"], ["F2", "A2", "C3", "E3"], ["G2", "B2", "D3", "F3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        uneasy = bar >= 16
        detune = 1.0 + (0.006 * np.sin(bar) if uneasy else 0.0)
        inst = (lambda f, n, d=detune: epiano(f * d, n)) if uneasy else epiano
        t.chord(inst, b0, 1.5, [m + 12 for m in ch], 0.6, "keys")
        t.chord(inst, b0 + 2, 1.5, [m + 12 for m in ch], 0.5, "keys")
        t.note(muted_bass, b0, 1.8, ch[0] - 12, 0.7)
        t.note(muted_bass, b0 + 2, 1.8, ch[2] - 12, 0.6)
        steps(t, b0, "k.......k.......", DR, vel=0.4)
        steps(t, b0, "....r.......r...", DR, vel=0.6)
        if uneasy and bar % 4 == 3:
            t.note(lambda f, n: glass(f, n) * 1.2, b0 + 3, 1.5, ch[3] + 25, 0.7, "air")   # a note just wrong
    a = "E5:1 G5:1 C6:2 B5:1 G5:1 A5:2 F5:1 A5:1 C6:1 B5:1 G5:4"
    for s in (16, 48, 80, 112):
        tune(t, lambda f, n: soft_sine(f, n) * 0.8, s, a, 1.0, "lead")
    t.write(out, {"keys": lambda x: reverb(x, 1.2, 0.2), "lead": lambda x: reverb(x, 1.4, 0.2), "air": lambda x: reverb(x, 3.0, 0.5)})


def kane_fight(out):
    bpm = 120
    bars = 48
    t = Track(bpm, bars * 4, tail=3.0)
    prog = [["D2", "F2", "A2"], ["D2", "F2", "A2"], ["Bb1", "D2", "F2"], ["C2", "E2", "G2"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[(bar // 2) % 4])
        build = min(1.0, bar / 24.0)
        if bar % 2 == 0:
            t.chord(strings, b0, 8.0, [m + 12 for m in ch] + [ch[0] + 24], 0.6 + 0.4 * build, "orch")
            t.chord(lambda f, n: brass(f, n) * 0.8, b0, 3.0, [m + 12 for m in ch], 0.3 + 0.6 * build, "orch")
        for k in range(16):
            t.note(synth_bass, b0 + k * 0.25, 0.2, ch[0], 0.5 + 0.3 * (k % 4 == 0))
            t.add(b0 + k * 0.25, tick() * (0.8 if k % 4 == 0 else 0.3))
        if bar >= 8:
            steps(t, b0, "k.......k.k.....", DR)
            t.add(b0 + 1, tom(70) * 0.7)
            t.add(b0 + 3, tom(70) * 0.7)
        if bar >= 16:
            steps(t, b0, "....g.......g...", DR, vel=0.8)
        if bar % 8 == 0 and bar >= 8:
            t.add(b0, boom() * 0.8)
    motif = "D5:1.5 E5:.5 F5:2 E5:1 C5:1 D5:4"
    for s in range(64, 192, 16):
        tune(t, lambda f, n: glass(f, n) * 1.4 + brass(f, n) * 0.5, s, motif, 1.0, "orch")
    t.write(out, {"orch": lambda x: reverb(x, 2.6, 0.35, 3000)})


# ================================================================= TENRYU MECHA WORKS

def tenryu_citypop(out):
    bpm = 114
    bars = 48
    t = Track(bpm, bars * 4)
    prog = [["F3", "A3", "C4", "E4"], ["E3", "G3", "B3", "D4"], ["D3", "F3", "A3", "C4"], ["G3", "B3", "D4", "F4"]]
    roots = ["F2", "E2", "D2", "G2"]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 4])
        r = N(roots[bar % 4])
        t.chord(epiano, b0, 1.0, ch, 0.6, "keys")
        t.chord(epiano, b0 + 1.5, 0.5, ch, 0.5, "keys")
        t.chord(epiano, b0 + 2.75, 0.8, ch, 0.5, "keys")
        for k, (o, d) in enumerate([(0, 0), (0.75, 12), (1.5, 0), (2.0, 7), (2.75, 12), (3.5, 10)]):
            t.note(slap, b0 + o, 0.3, r + d, 0.9)
        if bar >= 2:
            steps(t, b0, "k...s..kk...s...", DR)
            steps(t, b0, "h.h.h.h.h.h.h.ho", DR, vel=0.5)
        if bar % 4 == 3:
            t.chord(lambda f, n: brass(f, n) * 0.9, b0 + 3.5, 0.5, [m + 12 for m in ch], 0.6, "keys")
    a = "A5:.5 G5:.5 E5:1 C5:.5 D5:.5 E5:1 G5:1.5 A5:.5 E5:2 r:1 D5:.5 E5:.5 F5:1 E5:.5 D5:.5 C5:1 D5:1 E5:3"
    for s in (16, 48, 96, 128, 160):
        tune(t, lambda f, n: mm.inst_lead2(f, n) * 0.5 + epiano(f, n) * 0.6, s, a, 1.0, "lead")
    t.write(out, {"keys": lambda x: reverb(x, 1.4, 0.22), "lead": lambda x: reverb(delay(x, 0.5 * 60 / bpm, 0.3, 0.2), 1.8, 0.28)})


def tenryu_koto(out):
    bpm = 70
    bars = 24
    t = Track(bpm, bars * 4, tail=4.0)
    # in-scale pentatonic on D: D Eb G A Bb
    scale = [N(x) for x in ("D4", "Eb4", "G4", "A4", "Bb4", "D5", "Eb5", "G5")]
    for bar in range(bars):
        b0 = bar * 4
        pat = [0, 2, 3, 5, 3, 2] if bar % 2 == 0 else [1, 3, 4, 6, 4, 2]
        for k, idx in enumerate(pat):
            t.note(koto, b0 + k * 0.66, 1.2, scale[idx], 0.6 - k * 0.04, "koto")
        t.note(lambda f, n: koto(f, n) * 0.9, b0, 3.0, N("D3"), 0.6, "koto")
    mel = "A5:2 Bb5:1 A5:1 G5:3 r:1 D5:2 Eb5:1 G5:1 A5:4 Bb5:2 A5:1 G5:1 Eb5:2 D5:2 D5:6 r:2"
    for s in (16, 56):
        tune(t, shakuhachi, s, mel, 1.0, "lead")
    t.buf += noise_bed(len(t.buf), 2000, 7000, 0.003)   # wind in the garden
    t.write(out, {"koto": lambda x: reverb(x, 2.2, 0.3), "lead": lambda x: reverb(x, 3.0, 0.4)})


def tenryu_anthem(out):
    bpm = 168
    bars = 64
    t = Track(bpm, bars * 4)
    prog = ["A", "F", "G", "E"]
    roots = {"A": "A1", "F": "F1", "G": "G1", "E": "E1"}
    a = "E5:1 E5:.5 D5:.5 E5:1 A5:1 G5:1.5 F5:.5 E5:2 D5:1 E5:.5 F5:.5 G5:1 F5:1 E5:4"
    b = "C6:1 B5:.5 A5:.5 B5:1 C6:1 D6:2 C6:1 B5:1 A5:1 G5:.5 A5:.5 B5:1 G#5:1 A5:4"
    for bar in range(bars):
        b0 = bar * 4
        up = 2 if bar >= 48 else 0   # the key change for the last chorus
        r = N(roots[prog[(bar // 2) % 4]]) + up
        for k in range(8):
            t.chord(lambda f, n: np.tanh(mm.inst_chug(f, n) * 1.4), b0 + k * 0.5, 0.42, [r + 12, r + 19], 0.75, "gtr")
            t.note(synth_bass, b0 + k * 0.5, 0.4, r, 0.8)
        steps(t, b0, "k...s...k.k.s...", DR)
        steps(t, b0, "o.h.o.h.o.h.o.h.", DR, vel=0.5)
        if bar % 4 == 3:
            t.chord(lambda f, n: brass(f, n) * 1.2, b0 + 3, 0.5, [r + 24, r + 28, r + 31], 0.8, "brass")
            t.chord(lambda f, n: brass(f, n) * 1.2, b0 + 3.5, 0.5, [r + 26, r + 29, r + 33], 0.8, "brass")
        if bar == 47:
            steps(t, b0, "ssssssssssssssss", DR, vel=0.6)
    lead = lambda f, n: supersaw(f, n) * 0.9 + brass(f, n) * 0.5
    for s, m in ((32, a), (64, b), (96, a), (128, b)):
        tune(t, lead, s, m, 1.0, "lead")
    for s, m in ((192, a), (224, b)):
        tune(t, lambda f, n: lead(f * 2 ** (2 / 12), n), s, m, 1.0, "lead")
    t.write(out, {"gtr": lambda x: x * 0.85, "brass": lambda x: reverb(x, 1.0, 0.2), "lead": lambda x: reverb(x, 1.2, 0.22)})


# ================================================================= MENAGERIE MECHANICA

def men_calliope(out):
    bpm = 150
    bars = 64
    t = Track(bpm, bars * 3)
    prog = [["C3", "E3", "G3"], ["G2", "B2", "D3", "F3"], ["G2", "B2", "D3", "F3"], ["C3", "E3", "G3"], ["F2", "A2", "C3"], ["C3", "E3", "G3"], ["G2", "B2", "D3"], ["C3", "E3", "G3"]]
    for bar in range(bars):
        b0 = bar * 3
        ch = chord_of(prog[bar % 8])
        t.note(tuba, b0, 0.9, ch[0] - 12, 0.9)
        t.chord(calliope, b0 + 1, 0.6, [m + 12 for m in ch], 0.4, "cal")
        t.chord(calliope, b0 + 2, 0.6, [m + 12 for m in ch], 0.4, "cal")
        t.add(b0, mm.kick() * 0.3)
    a = "E5:1 G5:1 C6:1 B5:2 G5:1 A5:1 G5:1 F5:1 D5:3 F5:1 A5:1 D6:1 C6:2 A5:1 G5:1 E5:1 D5:1 C5:3"
    for s in (24, 48, 96, 120, 168):
        tune(t, calliope, s, a, 1.0, "lead")
    t.add(90, clank(1.3) * 0.6)
    t.write(out, {"cal": lambda x: reverb(x, 1.0, 0.18), "lead": lambda x: reverb(x, 1.2, 0.2)})


def men_tango(out):
    bpm = 116
    bars = 40
    t = Track(bpm, bars * 4)
    prog = [["D3", "F3", "A3"], ["D3", "F3", "A3"], ["A2", "C#3", "E3", "G3"], ["D3", "F3", "A3"], ["G2", "Bb2", "D3"], ["D3", "F3", "A3"], ["E3", "G3", "Bb3", "C#4"], ["A2", "C#3", "E3"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = chord_of(prog[bar % 8])
        # habanera: 1, the "and" of 2... (dotted 8th, 16th, 8th, 8th)
        for o, ln, v in ((0, 0.7, 1.0), (0.75, 0.25, 0.7), (1.0, 0.5, 0.8), (2.0, 0.5, 0.9)):
            t.note(muted_bass, b0 + o, ln, ch[0] - 12, v)
            t.chord(pizz, b0 + o, ln, [m + 12 for m in ch], 0.5 * v, "str")
        t.chord(pizz, b0 + 2.75, 0.25, [m + 12 for m in ch], 0.4, "str")
        t.chord(pizz, b0 + 3.0, 0.5, [m + 12 for m in ch], 0.5, "str")
        t.add(b0 + 3.5, rim() * 0.5)
    a = "A5:1.5 G5:.5 F5:.5 E5:.5 D5:1 E5:1 F5:.5 E5:.5 C#5:2 D5:1.5 E5:.5 F5:.5 G5:.5 A5:1 Bb5:1 A5:.5 G5:.5 A5:2"
    for s in (16, 48, 96, 128):
        tune(t, bandoneon, s, a, 1.0, "lead")
    tune(t, lambda f, n: strings(f, n) * 1.4, 64, a, 1.0, "lead")
    t.write(out, {"str": lambda x: reverb(x, 1.0, 0.15), "lead": lambda x: reverb(x, 1.6, 0.25)})


def men_galop(out):
    bpm = 184
    bars = 112
    t = Track(bpm, bars * 2)   # 2/4
    prog = ["C", "C", "G", "G", "C", "C", "G", "C", "F", "F", "C", "C", "G", "G", "C", "C"]
    ch = {"C": ["C3", "E3", "G3"], "G": ["G2", "B2", "D3", "F3"], "F": ["F2", "A2", "C3"]}
    for bar in range(bars):
        b0 = bar * 2
        c = chord_of(ch[prog[bar % 16]])
        t.note(tuba, b0, 0.45, c[0] - 12, 1.0)
        t.chord(calliope, b0 + 0.5, 0.4, [m + 12 for m in c], 0.45, "cal")
        t.note(tuba, b0 + 1, 0.45, c[2] - 24, 0.9)
        t.chord(calliope, b0 + 1.5, 0.4, [m + 12 for m in c], 0.45, "cal")
        t.add(b0, mm.kick() * 0.6)
        t.add(b0 + 1, mm.kick() * 0.5)
        steps(t, b0, "s.s.s.s.", {"s": mm.snare}, vel=0.35)
        if bar % 16 == 15:
            steps(t, b0, "ssssssss", {"s": mm.snare}, vel=0.6)
    a = "G5:.25 A5:.25 G5:.25 F#5:.25 G5:.5 E5:.5 C5:.5 E5:.5 G5:1 A5:.25 B5:.25 C6:.5 B5:.5 A5:.5 G5:.5 F5:.5 D5:.5 G5:1 r:1"
    for s in range(16, 224, 16):
        if (s // 16) % 4 != 3:
            tune(t, calliope, s, a, 1.0, "lead")
    t.write(out, {"cal": lambda x: reverb(x, 0.8, 0.15), "lead": lambda x: reverb(x, 1.0, 0.18)})


SONGS = {
    "scrap_skiffle": scrap_skiffle, "scrap_jug": scrap_jug, "scrap_stomp": scrap_stomp,
    "iron_bigband": iron_bigband, "iron_ballad": iron_ballad, "iron_rockabilly": iron_rockabilly,
    "brass_musicbox": brass_musicbox, "brass_bandstand": brass_bandstand, "brass_march": brass_march,
    "hell_blues": hell_blues, "hell_groove": hell_groove, "hell_riff": hell_riff,
    "volta_sunset": volta_sunset, "volta_drive": volta_drive, "volta_fight": volta_fight,
    "nimbus_lounge": nimbus_lounge, "nimbus_clouds": nimbus_clouds, "nimbus_breaks": nimbus_breaks,
    "kane_hold": kane_hold, "kane_fight": kane_fight,
    "tenryu_citypop": tenryu_citypop, "tenryu_koto": tenryu_koto, "tenryu_anthem": tenryu_anthem,
    "men_calliope": men_calliope, "men_tango": men_tango, "men_galop": men_galop,
}


if __name__ == "__main__":
    out_dir = os.path.join(mm.ROOT, "music")
    only = sys.argv[1:]
    for name, fn in SONGS.items():
        if not only or name in only:
            fn(os.path.join(out_dir, name + ".ogg"))
