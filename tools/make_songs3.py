"""Port Ferrum's third record (1.84): four more songs for the menus and the garage, so the playlists
don't wear thin. Same tools as make_songs2.py (Track, tune, instruments), each its own shape:

    Smoke Break      a lazy jazz trio in Bb (Rhodes, upright, brushes), 88 bpm
    Chrome Morning   bright funk-pop (clavinet plucks, slap bass, tight drums), 104 bpm
    Harbour Lights   slow ambient piano over strings and glass, 64 bpm
    Scrap Market     a market-day polka (accordion, nylon, harmonica), 128 bpm

    python3 tools/make_songs3.py              (needs numpy, scipy, soundfile)
    python3 tools/make_songs3.py smoke_break  (only the named songs)
All synthesized from scratch, 100% original.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_music as mm  # noqa: E402
from make_songs2 import (Track, N, tune, rhodes, muted_bass, brush, rim, pluck, strings, glass, soft_sine,  # noqa: E402
                         accordion, harmonica, flute, sub, reverb, delay, secs, noise_bed, tick)

RATE = mm.RATE
rng = np.random.default_rng(3011)


def piano(f, n):
    """A soft upright piano: a few partials, a hammer click, a long decay."""
    t = np.arange(n) / RATE
    x = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * f * 2.001 * t) * np.exp(-t * 2.0)
         + 0.2 * np.sin(2 * np.pi * f * 3.003 * t) * np.exp(-t * 4.0))
    x *= np.exp(-t * (1.6 + f / 900.0))
    click = rng.uniform(-1, 1, min(n, 200)) * np.exp(-np.arange(min(n, 200)) / 30.0) * 0.08
    x[: len(click)] += click
    return x * 0.18 * mm.adsr(n, 0.002, 0.05, 1.0, 0.08)


def clav(f, n):
    """Clavinet-ish funk pluck: bright, short, a little nasal."""
    x = pluck(f, n, 0.85, 0.990)
    return mm.bp(x, 300, 5000) * 1.3


def slap(f, n):
    """Slap bass: a sub body and a bright pop on top."""
    t = np.arange(n) / RATE
    body = np.sin(2 * np.pi * f * t) * np.exp(-t * 5.0)
    pop = mm.hp(pluck(f * 2, n, 0.9, 0.985), 600) * 0.6
    return (body * 0.5 + pop) * mm.adsr(n, 0.002, 0.08, 0.7, 0.04) * 0.6


def upright(f, n):
    """Upright bass: round, thumpy, with the finger's thud."""
    t = np.arange(n) / RATE
    x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t)
    return x * np.exp(-t * 3.2) * mm.adsr(n, 0.004, 0.1, 0.8, 0.05) * 0.45


def clap():
    n = secs(0.18)
    x = rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / (RATE * 0.04))
    return mm.bp(x, 900, 4000) * 0.9


# ---------------------------------------------------------------- 1. Smoke Break (jazz trio)

def smoke_break(out):
    bpm = 88
    bars = 40
    t = Track(bpm, bars * 4)
    sw = 0.17
    # Bb: Cm7 F7 Bbmaj7 Gm7 | Ebmaj7 Ab7 Dm7 G7
    chords = [["C3", "Eb3", "G3", "Bb3", "D4"], ["F2", "A3", "C4", "Eb4", "G4"], ["Bb2", "D3", "F3", "A3", "C4"], ["G2", "Bb3", "D4", "F4"],
              ["Eb3", "G3", "Bb3", "D4"], ["Ab2", "C3", "Eb3", "Gb3", "Bb3"], ["D3", "F3", "A3", "C4"], ["G2", "B3", "D4", "F4"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = [N(x) for x in chords[bar % 8]]
        # Rhodes comping: on the "and" of 2 and on 4, short
        t.chord(rhodes, b0 + 1.5 + sw, 0.9, ch[1:], 0.75, "keys", strum=0.02)
        t.chord(rhodes, b0 + 3.0, 0.7, ch[1:], 0.55, "keys", strum=0.02)
        # walking bass
        r = ch[0] - 12 if ch[0] > 50 else ch[0]
        walk = [r, r + 4, r + 7, r + 10] if bar % 2 == 0 else [r + 12, r + 10, r + 7, r + 5]
        for k, m in enumerate(walk):
            t.note(upright, b0 + k, 0.95, m, 0.9 if k == 0 else 0.7)
        # brushes: swirl on every beat, ride ticks with the swing
        for k in range(4):
            t.add(b0 + k, brush() * (1.3 if k % 2 else 0.9))
            t.add(b0 + k + 0.5 + sw, tick() * 0.35)
    a = "r:1 F5:.5 G5:.5 Bb5:1 A5:.5 G5:.5 F5:2 r:1 D5:.5 Eb5:.5 F5:1 D5:1 C5:2 r:2"
    b = "G5:1.5 F5:.5 Eb5:1 D5:1 C5:1.5 Bb4:.5 A4:1 C5:1 Bb4:3 r:1 r:4"
    c = "D5:.5 F5:.5 A5:1 G5:.5 F5:.5 D5:1 C5:.5 D5:.5 Eb5:1 F5:2 G5:1 F5:1 D5:4 r:4"
    tune(t, rhodes, 16, a, 1.2, "lead", sw)
    tune(t, rhodes, 32, b, 1.2, "lead", sw)
    tune(t, lambda f, n: flute(f, n) * 0.8, 48, c, 1.0, "lead", sw)
    tune(t, rhodes, 64, a, 1.1, "lead", sw)
    tune(t, rhodes, 80, b, 1.1, "lead", sw)
    tune(t, lambda f, n: flute(f, n) * 0.8, 112, c, 0.9, "lead", sw)
    tune(t, rhodes, 128, a, 1.0, "lead", sw)
    tune(t, rhodes, 144, b, 1.0, "lead", sw)
    # a smoky room: low hum and the odd glass
    t.buf += noise_bed(len(t.buf), 120, 600, 0.006)
    t.write(out, {"keys": lambda x: reverb(mm.lp(x, 4000), 1.4, 0.25),
                  "lead": lambda x: reverb(delay(x, 0.75 * 60 / bpm, 0.25, 0.2), 1.8, 0.3)})


# ---------------------------------------------------------------- 2. Chrome Morning (funk-pop)

def chrome_morning(out):
    bpm = 104
    bars = 48
    t = Track(bpm, bars * 4)
    # E minor funk: Em9 A9 | Cmaj7 B7
    prog = [("E2", ["G3", "B3", "D4", "F#4"]), ("A2", ["G3", "B3", "C#4", "E4"]), ("E2", ["G3", "B3", "D4", "F#4"]), ("A2", ["G3", "B3", "C#4", "E4"]),
            ("C2", ["G3", "B3", "E4"]), ("B1", ["A3", "D#4", "F#4"]), ("E2", ["G3", "B3", "D4", "F#4"]), ("B1", ["A3", "D#4", "F#4"])]
    for bar in range(bars):
        b0 = bar * 4
        root, ch = prog[bar % 8]
        r = N(root)
        ch = [N(x) for x in ch]
        # clav: sixteenth stabs on a fixed funky pattern
        for k in [0, 0.75, 1.5, 2.25, 2.5, 3.25]:
            t.chord(clav, b0 + k, 0.2, ch, 0.65, "clav")
        # slap bass line
        for k, (o, ln, d) in enumerate([(0, 0.5, 0), (0.75, 0.25, 12), (1.5, 0.5, 0), (2.0, 0.25, 7), (2.5, 0.5, 10), (3.5, 0.25, 12)]):
            t.note(slap, b0 + o, ln, r + d, 0.9)
        if bar >= 1:
            for beat in range(4):
                if beat in (0, 2):
                    t.add(b0 + beat, mm.kick() * 0.9)
                else:
                    t.add(b0 + beat, mm.snare() * 0.7)
                    t.add(b0 + beat, clap() * 0.4)
            t.add(b0 + 2.75, mm.kick() * 0.5)
            for k in range(16):
                t.add(b0 + k * 0.25, mm.hat(open_=k % 8 == 6) * (0.45 if k % 2 == 0 else 0.25))
        if bar % 8 == 7:
            for k in range(4):
                t.add(b0 + 3 + k * 0.25, mm.snare() * (0.4 + k * 0.12))
    lead = lambda f, n: (mm.wave("square", f, n, duty=0.3) * 0.5 + mm.wave("saw", f * 1.005, n) * 0.3) * mm.adsr(n, 0.01, 0.1, 0.6, 0.06) * 0.07
    a = "B4:.5 D5:.5 E5:1 G5:.5 E5:.5 D5:1 B4:.5 A4:.5 B4:2 r:1 E5:.5 G5:.5 A5:1 G5:.5 E5:.5 F#5:2 r:2"
    b = "G5:.75 F#5:.25 E5:.5 D5:.5 E5:1 B4:1 C5:.5 D5:.5 E5:.5 G5:.5 F#5:2 D#5:1 E5:3 r:4"
    tune(t, lead, 16, a, 1.0, "lead")
    tune(t, lead, 32, b, 1.0, "lead")
    tune(t, lambda f, n: lead(f, n) * 0.8 + lead(f * 2, n) * 0.25, 48, a, 1.0, "lead")
    tune(t, lead, 64, b, 1.0, "lead")
    tune(t, lambda f, n: lead(f, n) * 0.8 + lead(f * 2, n) * 0.25, 112, a, 1.0, "lead")
    tune(t, lead, 128, b, 1.0, "lead")
    tune(t, lead, 160, a, 1.0, "lead")
    t.write(out, {"clav": lambda x: delay(x, 0.75 * 60 / bpm, 0.2, 0.15),
                  "lead": lambda x: reverb(delay(x, 0.5 * 60 / bpm, 0.3, 0.2), 1.6, 0.25)})


# ---------------------------------------------------------------- 3. Harbour Lights (ambient piano)

def harbour_lights(out):
    bpm = 64
    bars = 32
    t = Track(bpm, bars * 4, tail=4.0)
    # D major, floating: Dmaj9 Bm11 Gmaj7 A6sus
    chords = [["D3", "A3", "E4", "F#4"], ["B2", "F#3", "A3", "E4"], ["G2", "D3", "F#3", "B3"], ["A2", "E3", "F#3", "D4"]]
    for bar in range(bars):
        b0 = bar * 4
        ch = [N(x) for x in chords[bar % 4]]
        t.chord(lambda f, n: strings(f, n) * 0.9, b0, 4.2, ch, 0.8, "pad")
        t.note(sub, b0, 4.0, ch[0] - 12, 0.5)
        # broken piano chords, unhurried
        for k, m in enumerate([ch[0], ch[1], ch[2], ch[3], ch[2], ch[1]]):
            t.note(piano, b0 + k * 0.66, 1.6, m + 12, 0.7 - k * 0.05, "keys")
        if bar % 2 == 1:
            t.note(glass, b0 + 2.5, 2.0, ch[3] + 24, 0.4, "air")
    mel = "F#5:2 E5:1 D5:1 E5:3 r:1 A5:2 G5:1 F#5:1 E5:4 D5:2 B4:1 D5:1 E5:2 F#5:2 A4:6 r:2"
    tune(t, piano, 16, mel, 1.1, "keys")
    tune(t, piano, 48, mel, 1.0, "keys")
    tune(t, piano, 96, mel, 0.9, "keys")
    # the harbour at night: slow waves and a far horn now and then
    n = len(t.buf)
    waves = noise_bed(n, 200, 1200, 0.02) * (0.6 + 0.4 * np.sin(np.arange(n) / RATE * 2 * np.pi / 7.0))
    t.buf += waves
    for at in (12, 44):
        t.note(lambda f, k: mm.lp(mm.wave("saw", f, k), 400) * mm.adsr(k, 0.4, 0.3, 0.7, 1.2) * 0.05, at, 4, N("A1"), 1.0, "air")
    t.write(out, {"pad": lambda x: reverb(x, 3.0, 0.4), "keys": lambda x: reverb(delay(x, 0.75 * 60 / bpm, 0.3, 0.2), 2.6, 0.35),
                  "air": lambda x: reverb(x, 3.5, 0.5)})


# ---------------------------------------------------------------- 4. Scrap Market (polka)

def scrap_market(out):
    bpm = 128
    bars = 96
    t = Track(bpm, bars * 2)   # 2/4 bars written as 4 beats per two bars
    # G major: G D7 G C | G D7 G D7 G
    prog = ["G", "G", "D", "D", "G", "G", "C", "C", "G", "G", "D", "D", "G", "D", "G", "G"]
    roots = {"G": "G2", "D": "D2", "C": "C2"}
    fifths = {"G": "D2", "D": "A1", "C": "G1"}
    chords = {"G": ["G3", "B3", "D4"], "D": ["F#3", "A3", "C4", "D4"], "C": ["G3", "C4", "E4"]}
    for bar in range(bars):
        b0 = bar * 2
        c = prog[bar % 16]
        # oom-pah: bass on 1, chord on the "and"
        t.note(muted_bass, b0, 0.45, N(roots[c]) if bar % 2 == 0 else N(fifths[c]), 1.0)
        t.chord(lambda f, n: accordion(f, n) * 0.8, b0 + 0.5, 0.4, [N(x) for x in chords[c]], 0.6, "acc")
        t.note(muted_bass, b0 + 1, 0.45, N(fifths[c]) if bar % 2 == 0 else N(roots[c]), 0.8)
        t.chord(lambda f, n: accordion(f, n) * 0.8, b0 + 1.5, 0.4, [N(x) for x in chords[c]], 0.6, "acc")
        t.chord(lambda f, n: pluck(f, n, 0.4, 0.993), b0 + 0.5, 0.3, [N(x) + 12 for x in chords[c]], 0.35, "acc")
        if bar >= 2:
            t.add(b0, mm.kick() * 0.6)
            t.add(b0 + 1, mm.kick() * 0.5)
            t.add(b0 + 0.5, mm.snare() * 0.35)
            t.add(b0 + 1.5, mm.snare() * 0.35)
            t.add(b0 + 1.5, rim() * 0.5)
    a = "D5:.5 B4:.5 G4:.5 B4:.5 D5:1 G5:1 F#5:.5 E5:.5 D5:.5 C5:.5 B4:1 A4:1 A4:.5 C5:.5 E5:.5 G5:.5 F#5:1 D5:1 E5:.5 F#5:.5 G5:.5 A5:.5 G5:2"
    b = "B5:.5 A5:.5 G5:1 E5:.5 D5:.5 B4:1 C5:.5 E5:.5 D5:.5 C5:.5 B4:1 G4:1 A4:.5 B4:.5 C5:.5 D5:.5 E5:1 F#5:1 G5:2 r:2"
    tune(t, accordion, 8, a, 1.0, "lead")
    tune(t, lambda f, n: harmonica(f, n) * 0.9, 24, b, 1.0, "lead")
    tune(t, accordion, 40, a, 1.0, "lead")
    tune(t, lambda f, n: flute(f, n) * 0.9 + accordion(f, n) * 0.4, 56, b, 1.0, "lead")
    tune(t, accordion, 104, a, 1.0, "lead")
    tune(t, lambda f, n: harmonica(f, n) * 0.9, 120, b, 1.0, "lead")
    tune(t, accordion, 152, a, 1.0, "lead")
    tune(t, lambda f, n: flute(f, n) * 0.9 + accordion(f, n) * 0.4, 168, b, 1.0, "lead")
    # the market: chatter and the odd clank of scrap
    t.buf += noise_bed(len(t.buf), 300, 2500, 0.008)
    t.write(out, {"acc": lambda x: reverb(x, 1.0, 0.15), "lead": lambda x: reverb(x, 1.4, 0.22)})


SONGS = {
    "smoke_break": smoke_break,
    "chrome_morning": chrome_morning,
    "harbour_lights": harbour_lights,
    "scrap_market": scrap_market,
}


if __name__ == "__main__":
    out_dir = os.path.join(mm.ROOT, "music")
    only = sys.argv[1:]
    for name, fn in SONGS.items():
        if not only or name in only:
            fn(os.path.join(out_dir, name + ".ogg"))
