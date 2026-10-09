"""(1.92) Each maker's sound set: a footstep and a hit landed, into sfx/step_<maker>.wav and
sfx/strike_<maker>.wav. Run from the project root:  python3 tools/make_maker_sounds.py
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "sfx")
rng = np.random.default_rng(92)


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




def bandnoise(dur, amount):
    return lowpass(noise(dur), amount)


def pad(x, before):
    return np.concatenate([np.zeros(int(RATE * before)), x])


# Scrapworks: tin cans and a rattle on every step
save("step_scrapworks", mix(ring([1450, 2210, 3370], 0.12, 0.03) * 0.6,
     seq(*[env(bandnoise(0.012, 0.6), decay=0.004) for _ in range(4)], gap=0.018) * 0.7), 0.45)
save("strike_scrapworks", mix(ring([980, 1730, 2650, 3890], 0.25, 0.05),
     seq(*[env(bandnoise(0.015, 0.5), decay=0.005) for _ in range(5)], gap=0.022) * 0.6), 0.55)

# Old Iron Foundry: deep clangs and a hiss of hydraulics
save("step_oldiron", mix(env(osc((70, 38), 0.22, "sine"), decay=0.08),
     ring([196, 311, 467], 0.35, 0.09) * 0.45,
     pad(env(bandnoise(0.18, 0.5), 0.02, 0.06) * 0.18, 0.06)), 0.7)
save("strike_oldiron", mix(env(osc((90, 30), 0.3, "sine"), decay=0.1),
     ring([147, 233, 349, 523], 0.6, 0.18) * 0.7,
     pad(env(bandnoise(0.25, 0.6), 0.03, 0.08) * 0.25, 0.1)), 0.8)

# Brassworks & Sons: a chuff of steam each step, a valve whistle on a hit
save("step_brassworks", mix(env(bandnoise(0.16, 0.18), 0.004, 0.05),
     env(osc(150, 0.05, "sine"), decay=0.02) * 0.4), 0.5)
save("strike_brassworks", mix(env(bandnoise(0.3, 0.25), 0.003, 0.08),
     pad(env(vibrato(1850, 0.28, 0.01, 9, "sine"), 0.02, 0.12) * 0.35, 0.03),
     ring([620, 930, 1395], 0.25, 0.06) * 0.4), 0.6)

# Hellfire Heavy: engine revs, flame roar, grinding metal
save("step_hellfire", mix(env(lowpass(osc((55, 95), 0.2, "saw"), 0.25), 0.01, 0.08),
     env(bandnoise(0.12, 0.12), decay=0.04) * 0.5), 0.55)
save("strike_hellfire", mix(env(lowpass(osc((70, 140), 0.32, "saw"), 0.3), 0.005, 0.1),
     env(bandnoise(0.4, 0.08), 0.02, 0.14) * 0.9,
     env(lowpass(noise(0.2), 0.7) * osc(37, 0.2, "square"), decay=0.07) * 0.3), 0.7)

# Volta Motor: electric buzz and zap
save("step_volta", mix(env(osc((1200, 700), 0.06, "square"), decay=0.02) * 0.5,
     env(osc(120, 0.06, "saw") * (rng.uniform(0, 1, int(RATE * 0.06)) > 0.6), decay=0.02) * 0.6), 0.4)
save("strike_volta", mix(env(osc((2400, 300), 0.18, "square"), decay=0.05) * 0.6,
     env(osc(100, 0.22, "saw") * (rng.uniform(0, 1, int(RATE * 0.22)) > 0.5), decay=0.07),
     ring([1760, 2640], 0.15, 0.04) * 0.3), 0.6)

# Nimbus Aerial: fan whoosh, a soft landing hiss
save("step_nimbus", env(lowpass(noise(0.18), 0.08) * np.sin(np.linspace(0, np.pi, int(RATE * 0.18))), 0.03, None), 0.35)
save("strike_nimbus", mix(env(lowpass(noise(0.3), 0.12) * np.sin(np.linspace(0, np.pi, int(RATE * 0.3))), 0.01, None),
     env(osc((900, 1500), 0.12, "sine"), decay=0.05) * 0.3), 0.5)

# Kane Dynamics: clean synth tones, a low hum
save("step_kane", mix(env(osc(110, 0.12, "sine"), 0.01, 0.06) * 0.7, env(osc(220, 0.08, "tri"), decay=0.03) * 0.25), 0.4)
save("strike_kane", mix(env(osc(880, 0.2, "sine"), 0.002, 0.08) * 0.6, env(osc(1318, 0.18, "sine"), 0.002, 0.06) * 0.4,
     env(osc(55, 0.25, "sine"), 0.01, 0.1)), 0.55)

# Tenryu Mecha Works: servo whirrs, a sharp metal shing
save("step_tenryu", mix(env(osc((420, 760), 0.08, "square"), decay=0.04) * 0.35,
     env(bandnoise(0.03, 0.4), decay=0.01) * 0.5), 0.4)
save("strike_tenryu", mix(ring([2900, 4350, 6100], 0.4, 0.11),
     env(osc((500, 1100), 0.1, "square"), decay=0.04) * 0.3), 0.55)

# Menagerie Mechanica: machine growls, a crest rattle
save("step_menagerie", mix(env(vibrato(85, 0.16, 0.12, 24, "saw"), 0.01, 0.06) * 0.5,
     env(bandnoise(0.05, 0.3), decay=0.015) * 0.4), 0.45)
save("strike_menagerie", mix(env(lowpass(vibrato((140, 70), 0.32, 0.18, 30, "saw"), 0.3), 0.01, 0.12),
     seq(*[env(bandnoise(0.012, 0.5), decay=0.004) for _ in range(6)], gap=0.014) * 0.5), 0.6)
