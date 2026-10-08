"""Generates the game's beep-boop robot sound effects into sfx/*.wav.

Run from the project root:  python3 tools/make_sounds.py
Needs numpy. Every sound is synthesized, so tweak the numbers and re-run.
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sfx")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def osc(freq, dur, kind="square"):
    """freq can be a number or (start, end) for a sweep."""
    t = t_axis(dur)
    if isinstance(freq, tuple):
        f = np.linspace(freq[0], freq[1], len(t))
    else:
        f = np.full(len(t), float(freq))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if kind == "sine":
        return np.sin(phase)
    if kind == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1.0) - 1) - 1
    return np.sign(np.sin(phase)) * 0.7  # square


def noise(dur):
    return rng.uniform(-1, 1, int(RATE * dur))


def lowpass(x, amount=0.15):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += amount * (v - acc)
        y[i] = acc
    return y


def env(x, attack=0.005, decay=None):
    """Quick attack, then exponential decay (decay = time constant in s) or flat."""
    n = len(x)
    e = np.ones(n)
    a = max(1, int(RATE * attack))
    e[:a] = np.linspace(0, 1, a)
    if decay:
        e[a:] = np.exp(-np.arange(n - a) / (RATE * decay))
    rel = min(n, int(RATE * 0.01))
    e[-rel:] *= np.linspace(1, 0, rel)
    return x * e


def ring(freqs, dur, decay):
    """Metallic clang: inharmonic sines."""
    t = t_axis(dur)
    x = sum(np.sin(2 * np.pi * f * t) / (k + 1) for k, f in enumerate(freqs))
    return env(x, 0.001, decay)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts, gap=0.0):
    g = np.zeros(int(RATE * gap))
    out = []
    for p in parts:
        out += [p, g]
    return np.concatenate(out)


def vibrato(freq, dur, depth, rate, kind="saw"):
    t = t_axis(dur)
    base = np.linspace(freq[0], freq[1], len(t)) if isinstance(freq, tuple) else np.full(len(t), float(freq))
    f = base * (1 + depth * np.sin(2 * np.pi * rate * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if kind == "sine":
        return np.sin(phase)
    return 2 * ((phase / (2 * np.pi)) % 1.0) - 1


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=float)
    peak = np.max(np.abs(x)) or 1.0
    data = (x / peak * gain * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


# ---------------------------------------------------------------- UI
save("click", env(osc(880, 0.05), decay=0.03), 0.5)
save("buy", seq(env(osc(660, 0.07), decay=0.05), env(osc(990, 0.07), decay=0.05),
                mix(env(osc(1320, 0.25), decay=0.1), ring([2637, 3951], 0.25, 0.08) * 0.4), gap=0.02), 0.6)
save("equip", seq(env(lowpass(noise(0.03), 0.5), decay=0.01), env(lowpass(noise(0.03), 0.5), decay=0.01),
                  env(lowpass(noise(0.03), 0.5), decay=0.01),
                  env(osc((300, 1200), 0.18, "saw"), decay=0.12) * 0.6, gap=0.03), 0.6)
save("error", seq(env(osc(140, 0.12)), env(osc(110, 0.18)), gap=0.04), 0.5)

# ---------------------------------------------------------------- fight
save("swing", mix(env(osc((260, 900), 0.13, "saw"), decay=0.06) * 0.5,
                  env(lowpass(noise(0.13), 0.25), 0.03, 0.05)), 0.45)
save("uppercut", mix(env(osc((200, 1600), 0.22, "square"), decay=0.12) * 0.6,
                     env(lowpass(noise(0.2), 0.3), decay=0.08) * 0.5), 0.5)
save("hit", mix(env(osc((140, 50), 0.18, "sine"), decay=0.06),
                env(lowpass(noise(0.08), 0.35), decay=0.02) * 0.8,
                ring([523, 1270, 2350], 0.3, 0.07) * 0.5), 0.8)
save("hit_big", mix(env(osc((110, 35), 0.3, "sine"), decay=0.1),
                    env(lowpass(noise(0.12), 0.3), decay=0.04),
                    ring([311, 744, 1630, 2910], 0.5, 0.15) * 0.6,
                    np.concatenate([np.zeros(int(RATE * 0.06)), env(osc((900, 300), 0.15, "square"), decay=0.06) * 0.3])), 0.9)
save("block", mix(ring([1800, 2610, 4130], 0.3, 0.06), env(noise(0.01), decay=0.003)), 0.55)
save("jump", env(vibrato((180, 620), 0.3, 0.08, 30, "sine"), decay=0.18), 0.5)
save("land", mix(env(osc((90, 40), 0.12, "sine"), decay=0.04), env(lowpass(noise(0.06), 0.2), decay=0.02) * 0.6), 0.6)
save("step", seq(env(osc(220, 0.025), decay=0.015), env(osc(330, 0.025), decay=0.015), gap=0.01), 0.35)
save("ko", seq(env(vibrato((800, 50), 1.1, 0.05, 9, "saw"), 0.01) * np.linspace(1, 0.3, int(RATE * 1.1)),
               mix(env(osc((70, 30), 0.25, "sine"), decay=0.08), env(lowpass(noise(0.15), 0.2), decay=0.04))), 0.75)

# ---------------------------------------------------------------- announcer beeps
save("round", env(osc(660, 0.18), decay=0.12), 0.5)
save("fight", seq(env(osc(880, 0.08)), env(osc(880, 0.08)), env(osc((440, 330), 0.35), decay=0.25), gap=0.05), 0.55)
save("victory", seq(*[env(osc(f, 0.11), decay=0.08) for f in (523, 659, 784)],
                    env(vibrato(1047, 0.6, 0.015, 12, "saw"), decay=0.4), gap=0.02), 0.5)
save("defeat", seq(env(vibrato(392, 0.3, 0.01, 6), decay=0.3), env(vibrato(370, 0.3, 0.01, 6), decay=0.3),
                   env(vibrato((349, 300), 0.9, 0.03, 6), decay=0.6), gap=0.06), 0.5)

# ---------------------------------------------------------------- parts, garage, story
# part ripped off: crunch + metal clang + a silly spring "boing-oing"
save("break", seq(mix(env(lowpass(noise(0.18), 0.6), decay=0.06), ring([420, 990, 1730, 2600], 0.4, 0.12) * 0.8,
                      env(osc((160, 40), 0.25, "saw"), decay=0.08) * 0.5),
                  env(vibrato((500, 260), 0.4, 0.12, 22, "sine"), decay=0.2) * 0.5), 0.8)
save("repair", seq(*[env(lowpass(noise(0.025), 0.6), decay=0.008) for _ in range(5)],
                   mix(env(osc(1320, 0.3, "sine"), decay=0.15), ring([2640, 3960], 0.3, 0.1) * 0.4), gap=0.04), 0.55)
save("sell", seq(env(osc(1320, 0.06), decay=0.04), env(osc(880, 0.06), decay=0.04),
                 env(osc(660, 0.12), decay=0.08), gap=0.02), 0.5)
save("target", seq(env(osc(1500, 0.04), decay=0.03), env(osc(2000, 0.06), decay=0.04), gap=0.02), 0.4)
save("untarget", env(osc((1500, 700), 0.08), decay=0.05), 0.35)
# dialogue blips: the pilot (YOU) and anyone without a voice of their own. Built like Gus's voice
# (saw + square, as loud, so phone speakers carry it) but clean, no growl, and a brighter tone.
save("talk", env(mix(lowpass(osc((420, 380), 0.055, "saw"), 0.7),
                     osc((420, 380), 0.055, "square") * 0.25), decay=0.04), 0.7)
# ECHO: a two-tone digital chirp, built as loud as Gus's voice (saw + square) so phone speakers carry it
save("talk_robot", seq(env(mix(lowpass(osc(620, 0.032, "saw"), 0.8), osc(620, 0.032, "square") * 0.35), decay=0.022),
                       env(mix(lowpass(osc(465, 0.032, "saw"), 0.8), osc(465, 0.032, "square") * 0.35), decay=0.022), gap=0.0), 0.7)
save("time", env(osc(220, 0.6), decay=0.5), 0.5)
save("spark", mix(env(lowpass(noise(0.05), 0.8), decay=0.01), env(osc((3000, 1200), 0.05, "square"), decay=0.02) * 0.4), 0.3)

# character voices (Sfx.VOICE_OF picks one per speaker, plus a pitch)
growl = np.repeat(rng.uniform(0.4, 1.0, 8), int(RATE * 0.06) // 8 + 1)[: int(RATE * 0.06)]
# Gus: gravelly but pitched where phone speakers can play it (120 and 200 Hz growls were lost on phones)
save("voice_gravel", env(mix(lowpass(osc((330, 290), 0.06, "saw"), 0.8) * growl,
                             osc((330, 290), 0.06, "square") * 0.3 * growl,
                             lowpass(noise(0.06), 0.4) * 0.25), decay=0.04), 0.7)
save("voice_high", env(mix(osc((540, 500), 0.04, "tri"), osc((540, 500), 0.04) * 0.25), decay=0.025), 0.28)
save("voice_smooth", env(mix(osc((300, 285), 0.055, "sine"), osc((600, 570), 0.055, "sine") * 0.25), decay=0.04), 0.35)
save("voice_nasal", env(lowpass(osc((360, 340), 0.045, "saw"), 0.5), decay=0.03), 0.3)
save("voice_boom", env(mix(lowpass(osc((300, 265), 0.07, "saw"), 0.8), osc((150, 132), 0.07) * 0.3), decay=0.05), 0.6)

print("sounds written to", os.path.abspath(OUT))
