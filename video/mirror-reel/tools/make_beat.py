"""Builds the reel's soundtrack from synthesized parts: assets/sfx/beat.wav.

120 BPM, one beat every 0.5 s, so every cut in index.html can land on a kick.
  0.0 – 1.5   intro: filtered arpeggio opening up + riser into the drop
  1.5 – 13.0  drop: kick, clap, hats, plucked arpeggio, lead hook, bass, chords
  13.0 – 13.5 drums out, arpeggio + riser
  13.5        impact + bright chord stab on the lockup, rings out to 15.0

Written for phone and laptop speakers: most of the musical content (arpeggio,
lead, chords, bass harmonics) sits between 200 Hz and 5 kHz, with the sub only
underneath. Deterministic: noise comes from a seeded generator.
Run: python3 tools/make_beat.py
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
DUR = 15.0
BEAT = 0.5
SIX = BEAT / 4            # 16th note
DROP = 1.5
DRUMS_END = 13.0
IMPACT = 13.5

N = int(SR * DUR)
t_all = np.arange(N) / SR
rng = np.random.default_rng(7)
L = np.zeros(N)
R = np.zeros(N)


def add(sig, start, gain=1.0, pan=0.0):
    i = int(round(start * SR))
    if i >= N or i < 0:
        return
    sig = sig[: N - i]
    L[i : i + len(sig)] += sig * gain * (1 - max(pan, 0))
    R[i : i + len(sig)] += sig * gain * (1 + min(pan, 0))


def lp(x, fc):
    """One-pole low-pass; fc is a scalar or a per-sample array."""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * np.minimum(fc, SR * 0.45) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def lp2(x, fc):
    return lp(lp(x, fc), fc)


def hp(x, fc):
    return x - lp(x, fc)


def saw(f, t, harmonics=14):
    out = np.zeros_like(t)
    for k in range(1, harmonics + 1):
        out += np.sin(2 * np.pi * f * k * t) / k
    return out * 0.6


def square(f, t, harmonics=9):
    out = np.zeros_like(t)
    for k in range(1, 2 * harmonics, 2):
        out += np.sin(2 * np.pi * f * k * t) / k
    return out * 0.8


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


# ---------- harmony: Am – F – C – G, one chord per bar (2 s) ----------
CHORDS = [  # MIDI notes
    [57, 60, 64],   # A3 C4 E4
    [53, 57, 60],   # F3 A3 C4
    [55, 60, 64],   # G3 C4 E4 (C/G)
    [55, 59, 62],   # G3 B3 D4
]
BASS = [45, 41, 48, 43]   # A2 F2 C3 G2


def bar_of(t):
    return int(np.floor((t - DROP) / (BEAT * 4))) % 4 if t >= DROP else 0


# ---------- drums ----------
def kick(length=0.38, punch=1.0):
    t = np.arange(int(SR * length)) / SR
    f = 52 + 150 * np.exp(-t * 30)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)
    knock = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 45) * 0.5      # audible on small speakers
    click = hp(rng.standard_normal(len(t)), 2500) * np.exp(-t * 300) * 0.5
    return np.tanh((body + knock + click) * 1.5 * punch)


def clap():
    t = np.arange(int(SR * 0.32)) / SR
    band = hp(lp2(rng.standard_normal(len(t)), 3200), 800)
    env = np.zeros_like(t)
    for off in (0.0, 0.010, 0.021):
        m = t >= off
        env[m] += np.exp(-(t[m] - off) * (70 if off < 0.02 else 13))
    body = np.sin(2 * np.pi * 220 * t) * np.exp(-t * 40) * 0.25
    return band * env * 1.1 + body


def hat(open_=False):
    length = 0.2 if open_ else 0.06
    t = np.arange(int(SR * length)) / SR
    return hp(hp(rng.standard_normal(len(t)), 6500), 6500) * np.exp(-t * (16 if open_ else 80)) * 0.6


def riser(length, f0=400, f1=9000):
    t = np.arange(int(SR * length)) / SR
    k = t / length
    swept = lp(rng.standard_normal(len(t)), f0 + (f1 - f0) * k ** 2)
    tone = saw(220 + 660 * k ** 2, t, 6) * 0.15
    return (hp(swept, 300) * 0.7 + tone) * (k ** 1.5)


def impact():
    t = np.arange(int(SR * 1.5)) / SR
    f = 42 + 120 * np.exp(-t * 16)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.8)
    crash = hp(rng.standard_normal(len(t)), 3000) * np.exp(-t * 2.6) * 0.45
    return np.tanh((boom * 1.2 + crash) * 1.2)


# ---------- tonal parts ----------
def pluck(note, length=0.24, bright=1.0):
    t = np.arange(int(SR * length)) / SR
    f = hz(note)
    raw = saw(f, t, 16) + 0.5 * saw(f * 1.006, t, 16)
    cutoff = 600 + 5200 * bright * np.exp(-t * 18)
    return lp2(raw, cutoff) * np.exp(-t * 11) * 0.9


def lead(note, length):
    t = np.arange(int(SR * length)) / SR
    f = hz(note)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.15)
    raw = square(f * vib, t) * 0.6 + saw(f * 2 * vib, t, 8) * 0.25
    env = np.minimum(1, t / 0.01) * np.exp(-t * 2.2) * np.minimum(1, (length - t) / 0.03)
    return lp(raw, 3800) * env * 0.7


def chord_stab(notes, length, cutoff=3200):
    t = np.arange(int(SR * length)) / SR
    sig = np.zeros_like(t)
    for n in notes:
        for det in (0.997, 1.003):
            sig += saw(hz(n + 12) * det, t, 10) * 0.25
    env = np.minimum(1, t / 0.005) * np.exp(-t * 3.0)
    return lp(sig, cutoff) * env


def bass_note(note, length):
    t = np.arange(int(SR * length)) / SR
    f = hz(note)
    sub = np.sin(2 * np.pi * f / 2 * t) * 0.4
    grit = lp2(saw(f, t, 18), 1400) * 0.7          # harmonics phones can play
    env = np.minimum(1, t / 0.008) * np.minimum(1, (length - t) / 0.02)
    return np.tanh((sub + grit) * 1.4) * env


def delay(sig, time=0.375, fb=0.35, mix=0.3):
    d = int(SR * time)
    out = sig.copy()
    tap = sig.copy()
    for _ in range(4):
        tap = np.concatenate([np.zeros(d), tap[:-d] if d < len(tap) else np.zeros(0)])[: len(sig)] * fb
        out += tap * mix / fb
    return out


# Arpeggio pattern over each chord (indexes into chord tones, +12 = up an octave).
ARP = [0, 1, 2, 12, 2, 1, 12, 13, 0, 1, 2, 12, 14, 12, 2, 1]
# Lead hook: (16th step, semitone offset from the chord root, length in 16ths), repeated per bar.
HOOK = [
    [(0, 19, 2), (3, 16, 1), (4, 15, 2), (6, 12, 2), (10, 12, 1), (11, 15, 1), (12, 16, 4)],   # Am
    [(0, 19, 2), (3, 16, 1), (4, 15, 2), (6, 12, 4), (12, 14, 4)],                            # F
    [(0, 16, 2), (3, 14, 1), (4, 12, 2), (6, 9, 2), (10, 12, 1), (11, 14, 1), (12, 16, 4)],    # C
    [(0, 14, 2), (2, 16, 2), (4, 19, 4), (10, 17, 2), (12, 16, 4)],                            # G
]


def arp_bar(bar_start, chord, gain, bright=1.0):
    arp_l = np.zeros(int(SR * 2.0) + SR)
    for s, idx in enumerate(ARP):
        octave = 12 * (idx // 12) + 12
        note = chord[idx % 12] + octave
        p = pluck(note, 0.22, bright)
        i = int(s * SIX * SR)
        arp_l[i : i + len(p)] += p
    return arp_l * gain


# ---------- arrangement ----------
# Intro: arpeggio on Am opening up, riser into the drop.
intro = np.zeros(int(SR * 1.5))
for s in range(12):
    idx = ARP[s + 4]
    note = CHORDS[0][idx % 12] + 12 * (idx // 12) + 12
    p = pluck(note, 0.22, 0.25 + 0.75 * s / 11)
    i = int(s * SIX * SR)
    n = min(len(p), len(intro) - i)
    intro[i : i + n] += p[:n]
intro = delay(intro)
add(intro * np.linspace(0.35, 1.0, len(intro)), 0.0, 0.45, pan=0.15)
add(intro * np.linspace(0.35, 1.0, len(intro)), 0.012, 0.45, pan=-0.15)
add(riser(DROP), 0.0, 0.5)

# Drop: one pass per bar.
bar_start = DROP
bar_index = 0
while bar_start < DRUMS_END - 1e-6:
    b = bar_index % 4
    chord = CHORDS[b]
    # Arpeggio, slightly delayed copy on the other side for width.
    arp = delay(arp_bar(bar_start, chord, 0.58))
    add(arp, bar_start, 1.0, pan=0.2)
    add(arp, bar_start + 0.011, 0.8, pan=-0.2)
    # Chord stabs on the off-beats of beats 2 and 4.
    for st in (0.75, 1.75):
        add(chord_stab(chord, 0.35), bar_start + st, 0.32)
    # Lead hook from the second bar on.
    if bar_index >= 1:
        root = chord[0]
        for step, off, ln in HOOK[b]:
            add(lead(root + off, ln * SIX), bar_start + step * SIX, 0.55)
    # Bass: 8th-note pulse on the root, off-beat octave jumps.
    for e in range(8):
        n = BASS[b] + (12 if e % 2 == 1 else 0)
        add(bass_note(n, SIX * 1.8), bar_start + e * BEAT / 2, 0.42)
    # Drums.
    for k in range(4):
        t = bar_start + k * BEAT
        if t >= DRUMS_END - 1e-6:
            break
        add(kick(), t, 0.8)
        if k % 2 == 1:
            add(clap(), t, 0.6)
        add(hat(open_=(k == 3)), t + BEAT / 2, 0.55, pan=0.3)
        add(hat(), t + SIX, 0.26, pan=-0.3)
        add(hat(), t + 3 * SIX, 0.26, pan=-0.3)
    bar_start += 2.0
    bar_index += 1

# Breakdown: drums out, arpeggio + riser.
brk = delay(arp_bar(DRUMS_END, CHORDS[3], 0.4))[: int(SR * (IMPACT - DRUMS_END))]
add(brk, DRUMS_END, 1.0)
add(riser(IMPACT - DRUMS_END, 800, 11000), DRUMS_END, 0.55)

# Impact: boom + bright Am stab ringing out.
add(impact(), IMPACT, 0.9)
add(kick(0.6, 1.2), IMPACT, 0.85)
add(delay(chord_stab(CHORDS[0] + [69], 1.4, 5000), 0.25, 0.4, 0.4), IMPACT, 0.55)
tail = delay(arp_bar(IMPACT, CHORDS[0], 0.25, 0.6))[: int(SR * (DUR - IMPACT))]
add(tail * np.linspace(1, 0, len(tail)), IMPACT + 0.25, 1.0)

# ---------- master: gentle glue, peak about -1 dBFS ----------
mix = np.stack([L, R], axis=1)
mix = np.tanh(mix * 1.15)
mix /= np.max(np.abs(mix)) / 0.89
mix *= np.minimum(1, (DUR - t_all) / 0.5)[:, None]

out = Path(__file__).resolve().parent.parent / "assets" / "sfx" / "beat.wav"
with wave.open(str(out), "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
print(f"wrote {out}")
