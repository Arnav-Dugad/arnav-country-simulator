#!/usr/bin/env python3
"""The game's original orchestral score and cinematic sound cues, synthesized
from scratch (no samples, no third-party audio).

    python tools/make_score.py          # writes assets/audio/*.ogg and cue *.wav

Sound design
  * Instruments are layered "ensembles": every string note is 7 slightly
    detuned voices with their own vibrato, panned across the stereo field;
    brass swells brighten as they grow; a soft formant choir; a felt piano;
    low "boom" percussion that is felt more than heard.
  * Everything passes through one long, dark concert-hall reverb (a synthetic
    stereo impulse response, convolved with FFT), which glues it together.
  * Calm by design: slow attacks, no harsh highs (gentle low-pass on every
    bus), modest loudness (about -20 dBFS RMS), soft-knee limiting.
  * Loops are seamless: each track renders past its end and the tail (notes and
    reverb) is folded back onto the start.

Pieces (D minor, 72 BPM, all original)
  menu      "Anthem": piano and strings, then a building ostinato, brass and
            choir climax, and back down so the loop breathes. Home screen.
  calm      In-game: strings, cello, piano motif, distant choir.
  tense     Same length and chords as calm (they play in sync and crossfade):
            low ostinato, brass swells, soft booms.
  fanfare   Triumph cue (election won, games open).
  election  Anticipation cue (counting the votes).
  event, success, warning: soft cues.
"""
import os
import subprocess
import wave

import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 44100
BPM = 72.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
rng = np.random.default_rng(11)


def hz(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


# ------------------------------------------------------------------ signal ---
def lowpass(x, cutoff, order=2):
    sos = butter(order, cutoff, btype="low", fs=SR, output="sos")
    return sosfilt(sos, x, axis=0)


def highpass(x, cutoff, order=2):
    sos = butter(order, cutoff, btype="high", fs=SR, output="sos")
    return sosfilt(sos, x, axis=0)


def bandpass(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x, axis=0)


_TABLES = {}


def saw_table(harmonics):
    """One band-limited sawtooth cycle (2048 samples) with `harmonics` partials."""
    if harmonics not in _TABLES:
        ph = np.arange(2048) / 2048.0
        t = np.zeros(2048)
        for k in range(1, harmonics + 1):
            t += np.sin(2 * np.pi * k * ph) / k
        _TABLES[harmonics] = t / np.max(np.abs(t))
    return _TABLES[harmonics]


def osc(freq, n, harmonics_cap=40, vib_rate=5.0, vib_depth=0.0, phase0=0.0, drift=0.0):
    """Band-limited saw at `freq` with vibrato (cents) and slow random drift."""
    t = np.arange(n) / SR
    cents = vib_depth * np.sin(2 * np.pi * vib_rate * t + rng.uniform(0, 6.28)) * np.clip(t / 0.6, 0, 1)
    if drift:
        cents += drift * np.sin(2 * np.pi * rng.uniform(0.05, 0.2) * t + rng.uniform(0, 6.28))
    f = freq * 2.0 ** (cents / 1200.0)
    phase = (phase0 + np.cumsum(f) / SR) % 1.0
    harm = int(max(1, min(harmonics_cap, (SR * 0.45) // freq)))
    table = saw_table(harm)
    idx = phase * 2048.0
    i0 = idx.astype(np.int64) % 2048
    frac = idx - np.floor(idx)
    return table[i0] * (1 - frac) + table[(i0 + 1) % 2048] * frac


def env(n, attack, release, curve=1.6):
    """Smooth attack and release envelope (seconds), raised-cosine shaped."""
    e = np.ones(n)
    a = min(int(attack * SR), n)
    r = min(int(release * SR), n - a)
    if a > 0:
        e[:a] = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))) ** curve
    if r > 0:
        e[n - r:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, r))) ** curve
    return e


def pan(mono, p):
    """Equal-power pan, p in -1..1 -> (n, 2)."""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], axis=1)


# ------------------------------------------------------------- instruments ---
def strings(note, dur, vel=0.6, attack=1.0, release=1.4, voices=7, bright=0.35, spread=0.7):
    """Ensemble strings: detuned voices, each with vibrato, spread in stereo."""
    n = int((dur + release) * SR)
    out = np.zeros((n, 2))
    f = hz(note)
    for v in range(voices):
        det = rng.uniform(-9, 9)
        s = osc(f * 2 ** (det / 1200), n, harmonics_cap=24, vib_rate=rng.uniform(4.6, 5.6),
                vib_depth=rng.uniform(6, 12), phase0=rng.uniform(), drift=3)
        out += pan(s, rng.uniform(-spread, spread))
    cutoff = 700 + 2600 * bright * vel + f * 1.5
    out = lowpass(out, min(cutoff, 9000), order=2)
    out *= env(n, attack, release)[:, None] * vel / voices
    return out


def spiccato(note, vel=0.6, length=0.18):
    """Short, bowed ostinato note."""
    n = int((length + 0.12) * SR)
    out = np.zeros((n, 2))
    f = hz(note)
    for v in range(4):
        s = osc(f * 2 ** (rng.uniform(-7, 7) / 1200), n, harmonics_cap=20, phase0=rng.uniform())
        out += pan(s, rng.uniform(-0.5, 0.5))
    e = env(n, 0.012, 0.1, curve=1.0) * np.exp(-np.arange(n) / SR / (length * 0.9))
    out = lowpass(out, 1800 + 1200 * vel) * e[:, None] * vel / 4
    return out


def brass(note, dur, vel=0.6, attack=0.6, release=1.0):
    """Low horns/trombones: brightness grows with the swell."""
    n = int((dur + release) * SR)
    f = hz(note)
    e = env(n, attack, release, curve=1.3)
    out = np.zeros((n, 2))
    for v in range(3):
        base = osc(f * 2 ** (rng.uniform(-5, 5) / 1200), n, harmonics_cap=16, vib_depth=3, phase0=rng.uniform())
        out += pan(base, rng.uniform(-0.35, 0.35))
    # brightness follows the envelope: blend a dark and a brighter filtered copy
    dark = lowpass(out, 500 + f)
    brightc = lowpass(out, 1400 + 2 * f)
    w = (e * vel)[:, None]
    out = dark * (1 - w) + brightc * w
    return out * e[:, None] * vel / 3


def choir(note, dur, vel=0.5, attack=1.5, release=2.0, vowel="ah"):
    """Soft choir: saw voices through three formant band-passes."""
    n = int((dur + release) * SR)
    f = hz(note)
    src = np.zeros(n)
    for v in range(6):
        src += osc(f * 2 ** (rng.uniform(-12, 12) / 1200), n, harmonics_cap=30, vib_rate=rng.uniform(4.5, 5.5),
                   vib_depth=rng.uniform(8, 14), phase0=rng.uniform(), drift=4)
    forms = {"ah": [(700, 1.0), (1220, 0.6), (2600, 0.25)], "oo": [(320, 1.0), (800, 0.5), (2500, 0.15)]}[vowel]
    voc = np.zeros(n)
    for fc, g in forms:
        voc += bandpass(src, fc * 0.85, fc * 1.15) * g
    voc = voc * env(n, attack, release)
    out = pan(voc, -0.25) * 0.5 + pan(np.roll(voc, 331), 0.25) * 0.5
    return out * vel / 6 * 2.2


def piano(note, vel=0.5, dur=3.5):
    """Felt piano: slightly inharmonic partials, soft hammer, warm decay."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(note)
    s = np.zeros(n)
    B = 0.0004
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > SR * 0.45:
            break
        decay = 2.2 / (1 + 0.6 * k) * (440.0 / f) ** 0.25
        s += np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * (0.9 ** k) / k ** 0.6 * np.exp(-t / decay)
    s *= np.clip(t / 0.006, 0, 1)
    s = lowpass(s, 2200 + 1800 * vel)
    return pan(s, (note - 64) / 40.0) * vel * 0.35


def harp(note, vel=0.5, dur=2.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(note)
    s = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.3)) * np.exp(-t / 0.9)
    s *= np.clip(t / 0.002, 0, 1)
    return pan(lowpass(s, 4000), (note - 70) / 30.0) * vel * 0.4


def boom(vel=0.6, dur=2.2):
    """Deep, felt hit: a pitch-falling sine with a breath of filtered noise."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 34 + 52 * np.exp(-t / 0.08)
    ph = np.cumsum(f) / SR
    s = np.sin(2 * np.pi * ph) * np.exp(-t / 0.55)
    nz = lowpass(rng.uniform(-1, 1, n), 380) * np.exp(-t / 0.12) * 0.5
    s = (s + nz) * np.clip(t / 0.004, 0, 1)
    return pan(s, 0.0) * vel * 0.9


def timpani_roll(note, dur, vel=0.5):
    n = int(dur * SR)
    out = np.zeros((n, 2))
    step = int(0.07 * SR)
    for k, i in enumerate(range(0, n - step, step)):
        g = (k * step / n) ** 1.5
        seg = n - i
        t = np.arange(seg) / SR
        s = np.sin(2 * np.pi * hz(note) * t) * np.exp(-t / 0.35) * np.clip(t / 0.003, 0, 1)
        out[i:] += pan(s, rng.uniform(-0.2, 0.2)) * g * 0.25
    return lowpass(out, 1200) * vel


def riser(dur, vel=0.4):
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    nz = rng.uniform(-1, 1, (n, 2))
    out = np.zeros((n, 2))
    # sweep a band-pass upward in chunks
    chunks = 24
    for c in range(chunks):
        a, b = c * n // chunks, (c + 1) * n // chunks
        fc = 200 * (10 ** (c / chunks))          # 200 Hz -> 2 kHz: an air swell, never a hiss
        out[a:b] = bandpass(nz[a:b], fc * 0.75, fc * 1.25)
    return lowpass(out, 2400) * (t ** 2.2)[:, None] * vel


# ----------------------------------------------------------------- mixing ---
def add(buf, part, at):
    i = int(at * SR)
    end = min(len(buf), i + len(part))
    if end > i:
        buf[i:end] += part[:end - i]


def hall_ir(seconds=4.2, predelay=0.03):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, (n, 2))
    decay = np.exp(-t / (seconds / 6.9))[:, None]
    ir = ir * decay
    ir = lowpass(ir, 5200)
    # darker tail: progressively stronger low-pass
    tail = lowpass(ir, 2400)
    blend = np.clip(t / 1.2, 0, 1)[:, None]
    ir = ir * (1 - blend) + tail * blend
    pre = np.zeros((int(predelay * SR), 2))
    ir = np.vstack([pre, ir])
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


IR = hall_ir()


def reverb(dry, wet=0.32):
    w = np.stack([fftconvolve(dry[:, c], IR[:, c])[:len(dry)] for c in range(2)], axis=1)
    return dry * (1 - wet) + w * wet * 0.9


def master(x, target_rms_db=-20.0, ceiling=0.89):
    x = highpass(x, 28)
    x = lowpass(x, 11000, order=1)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x *= 10 ** (target_rms_db / 20) / rms
    # soft-knee limiter
    k = 0.7
    over = np.abs(x) > k
    x[over] = np.sign(x[over]) * (k + (1 - k) * np.tanh((np.abs(x[over]) - k) / (1 - k)))
    peak = np.max(np.abs(x))
    if peak > ceiling:
        x *= ceiling / peak
    return x


def fold_loop(buf, length):
    """Render was longer than the loop: fold the overhang onto the start."""
    n = int(length * SR)
    out = buf[:n].copy()
    over = buf[n:]
    out[:len(over)] += over[:n]
    return out


def finish_loop(buf, length, wet, rms):
    """Seamless loop: reverb the long render (tail included), fold the overhang
    onto the start, then master three copies end to end and keep the middle one,
    so filters see the loop as continuous (no click at the seam)."""
    n = int(length * SR)
    looped = fold_loop(reverb(buf, wet), length)
    tiled = np.vstack([looped, looped, looped])
    return master(tiled, rms)[n:2 * n]


def write_wav(name, x):
    path = os.path.join(OUT, name + ".wav")
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(data.shape[1] if data.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path


def write_ogg(name, x, quality=5):
    tmp = write_wav("_tmp_" + name, x)
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), out],
                   check=True)
    os.remove(tmp)
    print("%-14s %5.1fs  %4d KB" % (name + ".ogg", len(x) / SR, os.path.getsize(out) // 1024))


# --------------------------------------------------------------- harmony ---
# D minor: i - VI - III - VII - i - VI - iv - V (each chord 3 bars = 10 s)
D, F, A, Bb, C, E, G = 50, 53, 57, 58, 60, 52, 55
CHORDS = [
    ("Dm", [38, 50, 53, 57]),   # D  F  A
    ("Bb", [34, 46, 53, 58]),   # Bb F  Bb
    ("F", [41, 48, 53, 57]),    # F  C  F  A
    ("C", [36, 48, 52, 55]),    # C  E  G
    ("Dm", [38, 50, 53, 57]),
    ("Bb", [34, 46, 50, 58]),
    ("Gm", [43, 50, 55, 58]),   # G  D  G  Bb
    ("A", [33, 45, 52, 57]),    # A  E  A (C# in melody)
]
CHORD_BARS = 3
LOOP = len(CHORDS) * CHORD_BARS * BAR          # 80 s

# Main theme (original): (beat offset in the chord, MIDI note, beats)
THEME = [
    [(0, 69, 3), (3, 67, 1), (4, 65, 4), (8, 64, 2), (10, 65, 2)],
    [(0, 65, 3), (3, 67, 1), (4, 70, 4), (8, 69, 4)],
    [(0, 69, 2), (2, 72, 2), (4, 74, 4), (8, 72, 2), (10, 69, 2)],
    [(0, 67, 6), (6, 64, 2), (8, 67, 4)],
    [(0, 69, 3), (3, 67, 1), (4, 65, 4), (8, 62, 4)],
    [(0, 65, 3), (3, 67, 1), (4, 70, 4), (8, 74, 4)],
    [(0, 74, 2), (2, 72, 2), (4, 70, 4), (8, 67, 4)],
    [(0, 69, 6), (6, 73, 2), (8, 76, 4)],
]


def chord_time(k):
    return k * CHORD_BARS * BAR


# ------------------------------------------------------------------ pieces ---
def calm():
    buf = np.zeros((int((LOOP + 8) * SR), 2))
    dur = CHORD_BARS * BAR
    for k, (_, notes) in enumerate(CHORDS):
        t0 = chord_time(k)
        bass, *upper = notes
        add(buf, strings(bass, dur + 0.6, vel=0.42, attack=1.6, release=2.2, voices=5, bright=0.15), t0)
        for nt in upper:
            add(buf, strings(nt, dur + 0.6, vel=0.30, attack=2.0, release=2.4, bright=0.25), t0)
        # piano motif: the theme, half the notes, gently
        for (b, nt, l) in THEME[k][::2]:
            add(buf, piano(nt, vel=0.42), t0 + b * BEAT)
        if k >= 4:   # second half: distant choir on the top note, high shimmer
            add(buf, choir(upper[-1] + 12, dur, vel=0.18, vowel="oo"), t0)
            add(buf, strings(upper[-1] + 24, dur, vel=0.08, attack=2.5, release=2.5, voices=5, bright=0.1), t0)
    return finish_loop(buf, LOOP, 0.38, -21.0)


def tense():
    buf = np.zeros((int((LOOP + 8) * SR), 2))
    dur = CHORD_BARS * BAR
    pattern = [0, 0, 12, 0, 7, 0, 12, 7]  # 8ths, on the chord root
    for k, (_, notes) in enumerate(CHORDS):
        t0 = chord_time(k)
        root = notes[0]
        lo = root + 12 if root < 40 else root
        for i in range(CHORD_BARS * 8):
            vel = 0.36 + 0.14 * (i % 8 == 0) + 0.12 * (i / (CHORD_BARS * 8))
            add(buf, spiccato(lo + pattern[i % 8], vel=vel), t0 + i * BEAT / 2)
        add(buf, brass(root + 12, dur, vel=0.42, attack=dur * 0.7, release=1.6), t0)
        add(buf, brass(root + 19, dur, vel=0.30, attack=dur * 0.75, release=1.6), t0)
        add(buf, strings(root - 12 if root >= 40 else root, dur + 0.5, vel=0.32, attack=1.0, release=1.8, voices=4, bright=0.1), t0)
        if k % 2 == 0:
            add(buf, boom(0.55), t0)
        add(buf, boom(0.32), t0 + 2 * BAR)
        if k in (3, 7):
            add(buf, riser(BAR * 1.5, 0.07), t0 + dur - BAR * 1.5)
    return finish_loop(buf, LOOP, 0.30, -21.5)


def menu():
    """Four passes through the progression: intro, theme, build, climax.
    The last two chords of the climax fall back so the loop restarts softly."""
    total = LOOP * 2   # 160 s
    buf = np.zeros((int((total + 8) * SR), 2))
    dur = CHORD_BARS * BAR
    for pass_ in range(2):
        for k, (_, notes) in enumerate(CHORDS):
            t0 = pass_ * LOOP + chord_time(k)
            section = pass_ * 2 + (k // 4)       # 0 intro, 1 theme, 2 build, 3 climax
            bass, *upper = notes
            calm_end = pass_ == 1 and k >= 6     # wind down into the loop point
            amp = [0.5, 0.75, 0.9, 1.0][section] * (0.55 if calm_end else 1.0)
            add(buf, strings(bass, dur + 0.6, vel=0.45 * amp, attack=1.4, release=2.2, voices=5, bright=0.2), t0)
            for nt in upper:
                add(buf, strings(nt, dur + 0.6, vel=0.32 * amp, attack=1.8, release=2.4, bright=0.2 + 0.15 * section), t0)
            theme = THEME[k]
            if section == 0:
                for (b, nt, l) in theme:
                    add(buf, piano(nt, vel=0.45), t0 + b * BEAT)
            else:
                for (b, nt, l) in theme:
                    v = [0, 0.42, 0.5, 0.58][section] * (0.6 if calm_end else 1.0)
                    add(buf, strings(nt + 12, l * BEAT + 0.2, vel=v, attack=0.35, release=1.2, bright=0.45), t0 + b * BEAT)
                    if section == 3 and not calm_end:
                        add(buf, brass(nt, l * BEAT + 0.2, vel=0.42, attack=0.25, release=1.0), t0 + b * BEAT)
            if section >= 2 and not calm_end:
                root = notes[0] + 12 if notes[0] < 40 else notes[0]
                for i in range(CHORD_BARS * 8):
                    add(buf, spiccato(root + [0, 0, 12, 0, 7, 0, 12, 7][i % 8], vel=0.32 + 0.1 * (section == 3)),
                        t0 + i * BEAT / 2)
                add(buf, boom(0.5 if section == 3 else 0.38), t0)
                add(buf, brass(notes[0] + 12, dur, vel=0.35, attack=dur * 0.6, release=1.4), t0)
            if section == 3 and not calm_end:
                add(buf, choir(upper[-1] + 12, dur, vel=0.32, vowel="ah"), t0)
                add(buf, timpani_roll(38, BAR, 0.4), t0 + dur - BAR)
    return finish_loop(buf, total, 0.36, -20.0)


# -------------------------------------------------------------------- cues ---
def cue(parts, length, wet=0.35, rms=-20.0, tail=4.5):
    buf = np.zeros((int((length + tail) * SR), 2))
    for p, at in parts:
        add(buf, p, at)
    x = reverb(buf, wet=wet)
    # fade the reverb tail out naturally
    n = len(x)
    x *= np.concatenate([np.ones(int(length * SR)), np.linspace(1, 0, n - int(length * SR)) ** 2])[:, None]
    return master(x, rms)


def fanfare():
    """Triumph in D major: horns call, strings swell, timpani, a bright resolve."""
    parts = []
    call = [(62, 0.0, 0.35), (62, 0.4, 0.2), (69, 0.62, 0.9), (66, 1.55, 0.3), (69, 1.88, 0.3), (74, 2.2, 1.9)]
    for nt, t, l in call:
        parts.append((brass(nt, l, vel=0.62, attack=0.08, release=0.6), t))
        parts.append((brass(nt - 12, l, vel=0.4, attack=0.1, release=0.6), t))
    for nt in (50, 57, 62, 66, 69):          # D major chord swelling under the call
        parts.append((strings(nt, 3.6, vel=0.38, attack=1.2, release=1.6, bright=0.5), 0.3))
    parts.append((timpani_roll(38, 2.0, 0.5), 0.2))
    parts.append((boom(0.5), 2.2))
    parts.append((choir(74, 1.8, vel=0.3), 2.2))
    for k, nt in enumerate((74, 78, 81, 86)):
        parts.append((harp(nt, 0.35), 2.25 + k * 0.07))
    return cue(parts, 4.6, wet=0.34, rms=-17.5)


def election():
    """Anticipation: a low pulse and strings rising, unresolved."""
    parts = []
    for k in range(4):
        parts.append((boom(0.35 + 0.08 * k, 1.2), k * 0.62))
    for nt in (38, 45, 50, 53):
        parts.append((strings(nt, 2.6, vel=0.36, attack=2.0, release=1.2, bright=0.4), 0.0))
    parts.append((strings(64, 1.6, vel=0.3, attack=1.4, release=1.0, bright=0.5), 1.0))
    parts.append((riser(2.4, 0.05), 0.2))
    return cue(parts, 2.8, wet=0.38, rms=-21.0, tail=3.0)


def event_cue():
    """A gentle 'something for you': two harp notes over a soft string breath."""
    parts = [(harp(74, 0.5), 0.0), (harp(81, 0.45), 0.12),
             (strings(62, 0.9, vel=0.18, attack=0.35, release=0.8, bright=0.3), 0.0),
             (strings(69, 0.9, vel=0.14, attack=0.35, release=0.8, bright=0.3), 0.0)]
    return cue(parts, 1.3, wet=0.4, rms=-25.0, tail=2.5)


def success_cue():
    parts = [(harp(nt, 0.42), k * 0.075) for k, nt in enumerate((62, 66, 69, 74))]
    parts.append((strings(74, 0.8, vel=0.12, attack=0.2, release=0.9, bright=0.4), 0.22))
    return cue(parts, 1.2, wet=0.38, rms=-25.0, tail=2.5)


def warning_cue():
    """Concern, not alarm: a low cello and muted horn, falling a step."""
    parts = [(strings(45, 0.9, vel=0.32, attack=0.12, release=0.8, voices=4, bright=0.2), 0.0),
             (brass(50, 0.6, vel=0.28, attack=0.1, release=0.6), 0.0),
             (strings(43, 0.9, vel=0.28, attack=0.12, release=0.9, voices=4, bright=0.15), 0.45)]
    return cue(parts, 1.4, wet=0.35, rms=-25.0, tail=2.5)


def ui_sounds():
    """Very quiet, soft UI sounds (wood and felt, no clicks in the treble)."""
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    tap = np.sin(2 * np.pi * 820 * t) * np.exp(-t / 0.012) * 0.6 + lowpass(rng.uniform(-1, 1, n), 1600) * np.exp(-t / 0.004) * 0.3
    write_wav("tap", pan(lowpass(tap, 2600), 0) * 0.16)
    n = int(0.03 * SR)
    t = np.arange(n) / SR
    tick = np.sin(2 * np.pi * 1500 * t) * np.exp(-t / 0.004)
    write_wav("tick", pan(tick, 0) * 0.07)
    def short(x, seconds, gain_db):
        n = int(seconds * SR)
        x = x[:n] * np.linspace(1, 0, n)[:, None] ** 2      # fade out: no click at the cut
        return x * 10 ** (gain_db / 20)
    write_wav("select", short(cue([(harp(79, 0.4), 0.0), (harp(86, 0.3), 0.05)], 0.4, wet=0.25), 0.9, -12))
    write_wav("toggle_on", short(cue([(harp(74, 0.35), 0.0), (harp(81, 0.3), 0.05)], 0.3, wet=0.2), 0.7, -14))
    write_wav("toggle_off", short(cue([(harp(81, 0.3), 0.0), (harp(74, 0.3), 0.05)], 0.3, wet=0.2), 0.7, -15))
    for name, rise in (("sheet_up", True), ("sheet_down", False)):
        n = int(0.24 * SR)
        x = np.linspace(0, 1, n)
        shape = np.sin(np.pi * (x ** (0.6 if rise else 1.6)))
        w = lowpass(rng.uniform(-1, 1, (n, 2)), 1400 if rise else 1000) * shape[:, None]
        write_wav(name, w * 0.05)


if __name__ == "__main__":
    import sys
    only = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--only=")]
    jobs = {
        "music_menu": lambda: write_ogg("music_menu", menu()),
        "music_calm": lambda: write_ogg("music_calm", calm()),
        "music_tense": lambda: write_ogg("music_tense", tense()),
        "fanfare": lambda: write_wav("fanfare", fanfare()),
        "election": lambda: write_wav("election", election()),
        "event": lambda: write_wav("event", event_cue()),
        "success": lambda: write_wav("success", success_cue()),
        "warning": lambda: write_wav("warning", warning_cue()),
        "ui": ui_sounds,
    }
    for k, f in jobs.items():
        if not only or k in only:
            f()
            print("done", k)
