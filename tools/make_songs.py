"""Composes the extra songs from short "recipes" (key, mode, chords, tempo, drum/bass style, instruments).

    python3 tools/make_songs.py      (needs numpy, scipy, soundfile; reuses the synths in make_music.py)

Melodies are generated from motifs that follow the chords, with a fixed random seed per song,
so every run gives the same music. Change a seed to get a new tune; change the recipe to restyle it.
All 100% original, synthesized from scratch.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_music as mm  # noqa: E402

MODES = {
    "major":    [0, 2, 4, 5, 7, 9, 11],
    "minor":    [0, 2, 3, 5, 7, 8, 10],
    "dorian":   [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
}

# 2-bar rhythms for motifs: (beat, length)
RHYTHMS = [
    [(0, 1), (1, 0.5), (1.5, 0.5), (2, 1.5), (3.5, 0.5), (4, 0.5), (4.5, 0.5), (5, 1), (6, 2)],
    [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1), (4, 1.5), (5.5, 0.5), (6, 1), (7, 1)],
    [(0, 1.5), (1.5, 0.5), (2, 1), (3, 1), (4, 0.75), (4.75, 0.75), (5.5, 0.5), (6, 2)],
    [(0, 0.5), (0.75, 0.25), (1, 0.5), (1.5, 0.5), (2, 0.5), (2.5, 1.5), (4, 0.5), (4.5, 0.5), (5, 0.5), (5.5, 0.5), (6, 2)],
    [(0, 2), (2, 1), (3, 1), (4, 3), (7, 1)],
    [(0, 0.25), (0.25, 0.25), (0.5, 0.5), (1, 0.25), (1.25, 0.25), (1.5, 0.5), (2, 1), (3, 0.5), (3.5, 0.5),
     (4, 0.25), (4.25, 0.25), (4.5, 0.5), (5, 0.5), (5.5, 0.5), (6, 1), (7, 1)],
]


def inst_saw_lead(f, n):
    x = mm.wave("saw", f, n, vib=0.01) + 0.5 * mm.wave("saw", f * 1.005, n)
    return mm.lp(x, 3500) * mm.adsr(n, 0.01, 0.1, 0.7, 0.05) * 0.14


def inst_pulse12(f, n):
    return mm.wave("pulse", f, n, vib=0.008, duty=0.125) * mm.adsr(n, 0.005, 0.08, 0.6, 0.04) * 0.2


def inst_epiano(f, n):
    x = mm.wave("tri", f, n) + 0.3 * mm.wave("sine", f * 2, n)
    return x * mm.adsr(n, 0.005, 0.4, 0.3, 0.1) * 0.12


def inst_bell(f, n):
    t = np.arange(n) / mm.RATE
    x = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)
    return x * np.exp(-t * 2.5) * 0.18


def inst_choir(f, n):
    x = sum(mm.wave("saw", f * d, n) for d in (0.995, 1.0, 1.006))
    x = mm.bp(x, 400, 1800)
    return x * mm.adsr(n, 0.3, 0.2, 0.8, 0.3) * 0.08


def inst_sub(f, n):
    return mm.wave("sine", f, n) * mm.adsr(n, 0.005, 0.1, 0.8, 0.05) * 0.6


LEADS = {"pulse": mm.inst_lead, "tri": mm.inst_lead2, "saw": inst_saw_lead, "pulse12": inst_pulse12,
         "epiano": inst_epiano, "bell": inst_bell, "choir": inst_choir}


class Composer:
    def __init__(self, r):
        self.r = r
        self.rng = np.random.default_rng(r["seed"])
        self.scale = MODES[r["mode"]]
        self.root = r["key"]          # midi note of the tonic (bass octave)
        self.song = mm.Song(bpm=r["bpm"], bars=r.get("bars", 16))

    def note_of(self, degree, octave=0):
        d = int(degree)
        o, i = divmod(d, 7)
        return self.root + 12 * (o + octave) + self.scale[i]

    def chord(self, degree, octave=1):
        return [self.note_of(degree + k, octave) for k in (0, 2, 4)]

    def make_motif(self, rhythm):
        steps = []
        cur = int(self.rng.choice([0, 2, 4]))
        for k, (b, ln) in enumerate(rhythm):
            if b % 1 == 0 and b % 2 == 0:
                cur = int(min([0, 2, 4, 7], key=lambda c: abs(c - cur) + self.rng.uniform(0, 1.5)))
            else:
                cur += int(self.rng.choice([-2, -1, -1, 1, 1, 2]))
            cur = max(-2, min(9, cur))
            steps.append((b, ln, cur))
        return steps

    def play_motif(self, inst, motif, start_bar, prog, octave, transpose_steps=0):
        for b, ln, st in motif:
            bar = start_bar + int(b // 4)
            deg = prog[bar % len(prog)]
            m = self.note_of(deg + st + transpose_steps, octave)
            self.song.note(inst, start_bar * 4 + b, ln * 0.95, m)

    def drums(self, style, bar):
        s = self.song
        b0 = bar * 4
        fill = bar % 8 == 7
        if style == "rock":
            for beat in (0, 2.5):
                s.add(b0 + beat, mm.kick())
            for beat in (1, 3):
                s.add(b0 + beat, mm.snare())
            for k in range(8):
                s.add(b0 + k * 0.5, mm.hat())
        elif style == "four":
            for beat in range(4):
                s.add(b0 + beat, mm.kick())
            for beat in (1, 3):
                s.add(b0 + beat, mm.snare() * 0.8)
            for k in range(8):
                s.add(b0 + k * 0.5 + 0.5 * (k % 2 == 0) * 0, mm.hat(open_=(k % 2 == 1)) * 0.8)
        elif style == "break":
            for beat in (0, 1.5, 2.75):
                s.add(b0 + beat, mm.kick())
            for beat in (1, 3, 3.75):
                s.add(b0 + beat, mm.snare() * (0.6 if beat == 3.75 else 1.0))
            for k in range(16):
                s.add(b0 + k * 0.25, mm.hat() * (1.0 if k % 2 == 0 else 0.5))
        elif style == "half":
            s.add(b0, mm.kick())
            s.add(b0 + 2, mm.snare())
            for k in range(4):
                s.add(b0 + k, mm.hat() * 0.7)
        elif style == "soft":
            if bar % 2 == 0:
                s.add(b0, mm.kick() * 0.6)
            s.add(b0 + 2, mm.hat(open_=True) * 0.5)
            fill = False
        elif style == "gallop":
            for beat in range(4):
                s.add(b0 + beat, mm.kick())
                s.add(b0 + beat + 0.5, mm.kick() * 0.6)
                s.add(b0 + beat + 0.75, mm.kick() * 0.6)
            for beat in (1, 3):
                s.add(b0 + beat, mm.snare())
            for k in range(8):
                s.add(b0 + k * 0.5, mm.hat(open_=True) * 0.5)
        if fill and style not in ("soft",):
            for k in range(4):
                s.add(b0 + 3 + k * 0.25, mm.snare() * 0.6)

    def bass(self, style, bar, deg):
        s = self.song
        b0 = bar * 4
        r = self.note_of(deg, 0)
        fifth = self.note_of(deg + 4, 0)
        if style == "eighths":
            for k in range(8):
                s.note(mm.inst_bass, b0 + k * 0.5, 0.45, r - 12 + (12 if k in (3, 7) else 0))
        elif style == "octave":
            for k in range(8):
                s.note(mm.inst_bass, b0 + k * 0.5, 0.4, r - 12 + (12 if k % 2 else 0))
        elif style == "walk":
            notes = [r, self.note_of(deg + 2, 0), fifth, self.note_of(deg + 5, 0)]
            for k in range(4):
                s.note(mm.inst_bass, b0 + k, 0.9, notes[k] - 12)
        elif style == "funk":
            for off, ln, n in [(0, 0.75, r), (1, 0.5, r), (1.5, 0.5, r + 12), (2.5, 0.5, r), (3, 0.5, fifth), (3.5, 0.5, r + 10)]:
                s.note(mm.inst_bass, b0 + off, ln, n - 12)
        elif style == "long":
            s.note(inst_sub, b0, 3.9, r - 12)
        elif style == "chug":
            for k in range(16):
                if k not in (6, 14):
                    s.note(mm.inst_bass, b0 + k * 0.25, 0.22, r - 12)

    def compose(self, out):
        r = self.r
        prog = r["prog"]
        bars = r.get("bars", 16)
        lead = LEADS[r["lead"]]
        m1 = self.make_motif(RHYTHMS[r["rhythms"][0]])
        m2 = self.make_motif(RHYTHMS[r["rhythms"][1]])
        for bar in range(bars):
            deg = prog[bar % len(prog)]
            self.drums(r["drums"], bar)
            self.bass(r["bass"], bar, deg)
            ch = self.chord(deg, 1)
            layers = r.get("layers", [])
            if "stabs" in layers:
                for off in (0.5, 1.5, 2.5, 3.5):
                    self.song.chord(mm.inst_stab, bar * 4 + off, 0.3, ch)
            if "pad" in layers:
                self.song.chord(mm.inst_pad, bar * 4, 4, ch)
            if "choir" in layers:
                self.song.chord(inst_choir, bar * 4, 4, [n + 12 for n in ch])
            if "arp" in layers and bar >= r.get("arp_from", 0):
                for k in range(8):
                    self.song.note(mm.inst_arp, bar * 4 + k * 0.5, 0.4, ch[k % 3] + 12)
            if "arp16" in layers and bar >= r.get("arp_from", 0):
                for k in range(16):
                    self.song.note(mm.inst_arp, bar * 4 + k * 0.25, 0.22, ch[[0, 1, 2, 1][k % 4]] + 24)
            if "chug" in layers:
                for k in range(8):
                    if k not in (3, 6):
                        self.song.note(mm.inst_chug, bar * 4 + k * 0.5, 0.4, self.note_of(deg, 0))
            if "epiano" in layers:
                for off in (0, 1.5, 2.5):
                    self.song.chord(inst_epiano, bar * 4 + off, 0.9, ch)
            if "bells" in layers and bar % 2 == 0:
                for k, n in enumerate(ch + [ch[0] + 12]):
                    self.song.note(inst_bell, bar * 4 + k * 0.5, 2.0, n + 12)
        # melody: A A' B A'' over 16 bars (2-bar motifs)
        oct_ = r.get("lead_octave", 2)
        plan = [(0, m1, 0), (2, m1, 0), (4, m1, 0), (6, m1, -1),
                (8, m2, 0), (10, m2, 0), (12, m1, 0), (14, m1, 2)]
        for start, motif, tr in plan:
            if start < bars:
                self.play_motif(lead, motif, start, prog, oct_, tr)
                if start >= 12 and r.get("double", False):
                    self.play_motif(mm.inst_lead2, motif, start, prog, oct_ + 1, tr)
        self.song.render(out)


SONGS = {
    # menus / garage / story
    "garage": {"seed": 11, "key": 41, "mode": "dorian", "bpm": 96, "prog": [0, 0, 3, 3, 0, 0, 4, 3],
               "drums": "rock", "bass": "funk", "lead": "pulse", "layers": ["epiano"], "rhythms": [0, 3]},
    "story": {"seed": 23, "key": 38, "mode": "minor", "bpm": 72, "prog": [0, 5, 2, 6, 0, 5, 3, 4],
              "drums": "soft", "bass": "long", "lead": "bell", "layers": ["pad", "arp"], "arp_from": 4,
              "rhythms": [4, 2], "lead_octave": 2},
    "anthem": {"seed": 5, "key": 48, "mode": "major", "bpm": 120, "prog": [0, 4, 5, 3, 0, 4, 3, 4],
               "drums": "rock", "bass": "octave", "lead": "saw", "layers": ["pad", "arp"], "rhythms": [2, 0],
               "double": True},
    "lounge": {"seed": 101, "key": 45, "mode": "dorian", "bpm": 88, "prog": [0, 3, 0, 3, 5, 4, 0, 4],
               "drums": "half", "bass": "walk", "lead": "epiano", "layers": ["pad", "bells"], "rhythms": [2, 4]},
    "workshop": {"seed": 113, "key": 43, "mode": "mixolydian", "bpm": 112, "prog": [0, 6, 3, 0, 0, 6, 3, 4],
                 "drums": "rock", "bass": "funk", "lead": "pulse12", "layers": ["stabs", "arp"], "arp_from": 8,
                 "rhythms": [3, 0]},
    "chiptune_cafe": {"seed": 131, "key": 47, "mode": "major", "bpm": 104, "prog": [0, 5, 3, 4, 0, 5, 1, 4],
                      "drums": "half", "bass": "walk", "lead": "tri", "layers": ["bells", "arp"], "arp_from": 8,
                      "rhythms": [3, 2]},
    "sunset_drive": {"seed": 149, "key": 42, "mode": "mixolydian", "bpm": 92, "prog": [0, 6, 3, 0, 5, 6, 3, 4],
                     "drums": "rock", "bass": "funk", "lead": "epiano", "layers": ["pad"], "rhythms": [4, 0]},
    # fights
    "fight_chrome": {"seed": 157, "key": 41, "mode": "harmonic", "bpm": 140, "prog": [0, 0, 5, 4, 0, 5, 3, 4],
                     "drums": "break", "bass": "octave", "lead": "saw", "layers": ["stabs", "arp16"], "arp_from": 4,
                     "rhythms": [1, 0]},
    "fight_scrapyard": {"seed": 163, "key": 44, "mode": "dorian", "bpm": 118, "prog": [0, 0, 3, 3, 6, 6, 4, 4],
                        "drums": "rock", "bass": "funk", "lead": "pulse12", "layers": ["chug"], "rhythms": [3, 5]},
    "fight_thunder": {"seed": 179, "key": 39, "mode": "phrygian", "bpm": 172, "prog": [0, 1, 0, 6, 0, 1, 5, 6],
                      "drums": "gallop", "bass": "eighths", "lead": "pulse", "layers": ["choir", "arp16"], "arp_from": 8,
                      "rhythms": [5, 1], "double": True},
    "fight_pump": {"seed": 31, "key": 45, "mode": "dorian", "bpm": 132, "prog": [0, 0, 6, 6, 5, 5, 6, 4],
                   "drums": "four", "bass": "octave", "lead": "saw", "layers": ["stabs"], "rhythms": [1, 3]},
    "fight_rush": {"seed": 47, "key": 40, "mode": "minor", "bpm": 165, "prog": [0, 5, 3, 4, 0, 5, 6, 4],
                   "drums": "break", "bass": "eighths", "lead": "pulse12", "layers": ["arp16"], "rhythms": [5, 1]},
    "fight_heavy": {"seed": 59, "key": 37, "mode": "phrygian", "bpm": 100, "prog": [0, 0, 1, 0, 0, 0, 1, 6],
                    "drums": "half", "bass": "chug", "lead": "saw", "layers": ["chug"], "rhythms": [2, 4]},
    "fight_neon": {"seed": 67, "key": 43, "mode": "minor", "bpm": 128, "prog": [0, 5, 2, 6, 0, 5, 3, 4],
                   "drums": "four", "bass": "eighths", "lead": "pulse", "layers": ["pad", "arp"], "rhythms": [0, 5],
                   "double": True},
    # walk-ins: the announcer's show before a fight (one per tier of venue)
    "walkin_scrap": {"seed": 191, "key": 40, "mode": "dorian", "bpm": 92, "bars": 8, "prog": [0, 0, 6, 6, 3, 3, 4, 4],
                     "drums": "half", "bass": "chug", "lead": "pulse12", "layers": ["chug", "stabs"], "rhythms": [2, 3]},
    "walkin_arena": {"seed": 197, "key": 45, "mode": "mixolydian", "bpm": 112, "bars": 8, "prog": [0, 6, 3, 4, 0, 6, 3, 4],
                     "drums": "four", "bass": "octave", "lead": "saw", "layers": ["pad", "stabs"], "rhythms": [4, 1],
                     "double": True},
    "walkin_grand": {"seed": 211, "key": 38, "mode": "harmonic", "bpm": 80, "bars": 8, "prog": [0, 5, 3, 4, 0, 5, 1, 4],
                     "drums": "half", "bass": "long", "lead": "choir", "layers": ["choir", "bells", "pad"], "rhythms": [4, 2]},
    "boss": {"seed": 83, "key": 38, "mode": "harmonic", "bpm": 150, "prog": [0, 0, 5, 4, 0, 0, 1, 4],
             "drums": "gallop", "bass": "chug", "lead": "saw", "layers": ["choir", "chug"], "rhythms": [1, 5],
             "double": True},
}


if __name__ == "__main__":
    out_dir = os.path.join(mm.ROOT, "music")
    only = sys.argv[1:]   # optional: names of songs to (re)build
    for name, recipe in SONGS.items():
        if not only or name in only:
            Composer(recipe).compose(os.path.join(out_dir, name + ".ogg"))
