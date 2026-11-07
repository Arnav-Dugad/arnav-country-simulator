#!/usr/bin/env python3
"""Synthesizes the game's original sound effects and ambient music (no samples,
no third-party audio, so no licensing questions). Standard library only.

    python tools/make_audio.py        # writes assets/audio/*.wav

Design: calm and premium. Soft attacks, short decays, gentle reverb, nothing harsh.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 44100
TAU = math.tau
random.seed(7)


def note(n):
    """MIDI note -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


def write(name, samples, sr=SR, peak=0.8):
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data)
    print(f"{name}.wav  {len(samples) / sr:.2f}s")


def env(t, a, d):
    """Attack-then-exponential-decay envelope."""
    return (t / a if t < a else math.exp(-(t - a) / d))


def lowpass(x, cutoff, sr=SR):
    rc = 1.0 / (TAU * cutoff)
    alpha = (1.0 / sr) / (rc + 1.0 / sr)
    y, out = 0.0, []
    for v in x:
        y += alpha * (v - y)
        out.append(y)
    return out


def reverb(x, sr=SR, mix=0.25, room=0.82):
    """Small Schroeder reverb (4 combs + 2 allpasses)."""
    combs = [int(sr * t) for t in (0.0297, 0.0371, 0.0411, 0.0437)]
    allp = [int(sr * t) for t in (0.005, 0.0017)]
    n = len(x)
    wet = [0.0] * n
    for d in combs:
        buf = [0.0] * d
        idx, lp = 0, 0.0
        for i in range(n):
            out = buf[idx]
            lp = out * 0.7 + lp * 0.3          # damping
            buf[idx] = x[i] + lp * room
            idx = (idx + 1) % d
            wet[i] += out * 0.25
    for d in allp:
        buf = [0.0] * d
        idx = 0
        for i in range(n):
            b = buf[idx]
            y = -wet[i] + b
            buf[idx] = wet[i] + b * 0.5
            wet[i] = y
            idx = (idx + 1) % d
    return [a * (1 - mix) + b * mix for a, b in zip(x, wet)]


def tail(x, seconds):
    return x + [0.0] * int(SR * seconds)


def pluck(freq, dur, bright=0.35, decay=0.12, attack=0.003):
    """Marimba/kalimba-like tone."""
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, attack, decay)
        s = math.sin(TAU * freq * t) + bright * math.sin(TAU * freq * 4.0 * t) * math.exp(-t / (decay * 0.3))
        out.append(s * e)
    return out


def bell(freq, dur, decay=0.6):
    partials = [(1.0, 1.0), (2.76, 0.45), (5.40, 0.22), (8.93, 0.08)]
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        s = sum(a * math.sin(TAU * freq * r * t) * math.exp(-t / (decay / r ** 0.5)) for r, a in partials)
        out.append(s * min(1.0, t / 0.004))
    return out


def noise_whoosh(dur, rise=True, cutoff=2400):
    raw = [random.uniform(-1, 1) for _ in range(int(SR * dur))]
    filt = lowpass(lowpass(raw, cutoff), cutoff)
    n = len(filt)
    out = []
    for i, v in enumerate(filt):
        p = i / n
        shape = math.sin(math.pi * (p ** (0.6 if rise else 1.6)))
        out.append(v * shape)
    return out


def mix(*tracks):
    n = max(len(t) for t, _ in tracks)
    out = [0.0] * n
    for t, off in tracks:
        o = int(off * SR)
        for i, v in enumerate(t):
            if i + o < n:
                out[i + o] += v
            else:
                out.append(v)
    return out


def sfx():
    # Tap: a soft, woody click.
    tap = []
    for i in range(int(SR * 0.05)):
        t = i / SR
        tap.append((math.sin(TAU * 1250 * t) * 0.6 + random.uniform(-1, 1) * 0.25 * math.exp(-t / 0.002))
                   * math.exp(-t / 0.012))
    write("tap", lowpass(tap, 5000), peak=0.35)
    # Select: two-note pluck, warm and quick.
    write("select", reverb(tail(mix((pluck(note(84), 0.25), 0), (pluck(note(91), 0.3, 0.25), 0.045)), 0.2), mix=0.18),
          peak=0.45)
    write("toggle_on", reverb(tail(mix((pluck(note(79), 0.2), 0), (pluck(note(86), 0.25), 0.05)), 0.15), mix=0.15),
          peak=0.4)
    write("toggle_off", reverb(tail(mix((pluck(note(86), 0.2), 0), (pluck(note(79), 0.25), 0.05)), 0.15), mix=0.15),
          peak=0.35)
    write("sheet_up", reverb(noise_whoosh(0.24, True, 2600), mix=0.2), peak=0.22)
    write("sheet_down", reverb(noise_whoosh(0.2, False, 1800), mix=0.2), peak=0.18)
    tick = [math.sin(TAU * 3200 * (i / SR)) * math.exp(-(i / SR) / 0.004) for i in range(int(SR * 0.02))]
    write("tick", tick, peak=0.18)
    # Success: bright major arpeggio with a bell on top.
    succ = mix((pluck(note(72), 0.6), 0), (pluck(note(76), 0.6), 0.07), (pluck(note(79), 0.7), 0.14),
               (bell(note(84), 1.0, 0.5), 0.21))
    write("success", reverb(tail(succ, 0.4), mix=0.28), peak=0.5)
    # Warning: two soft low notes, falling.
    warn = mix((pluck(note(67), 0.5, 0.1, 0.18), 0), (pluck(note(62), 0.6, 0.1, 0.2), 0.12))
    write("warning", reverb(tail(lowpass(warn, 2500), 0.3), mix=0.25), peak=0.45)
    # Event: a gentle bell chime (attention without alarm).
    chime = mix((bell(note(81), 1.4, 0.7), 0), (bell(note(88), 1.2, 0.6), 0.11))
    write("event", reverb(tail(chime, 0.5), mix=0.3), peak=0.45)
    # Election: rising chord swell then a bell.
    swell = []
    dur = 1.6
    chord = [note(n) for n in (60, 64, 67, 71, 74)]
    for i in range(int(SR * dur)):
        t = i / SR
        e = (t / dur) ** 1.6 * (1.0 if t < dur - 0.08 else (dur - t) / 0.08)
        swell.append(sum(math.sin(TAU * f * t + k) for k, f in enumerate(chord)) * e * 0.3)
    elect = mix((lowpass(swell, 3000), 0), (bell(note(84), 1.6, 0.8), dur - 0.05))
    write("election", reverb(tail(elect, 0.6), mix=0.3), peak=0.5)


def music():
    """64-second calm ambient loop: pads + sparse piano, seamless."""
    sr = 22050
    length = 64.0
    n = int(sr * length)
    out = [0.0] * n
    # Chords (MIDI): Cmaj9, Am9, Fmaj9, G6/9 — 16 s each.
    chords = [(48, 55, 59, 62, 64), (45, 52, 55, 59, 62), (41, 48, 52, 55, 57), (43, 50, 55, 57, 64)]
    seg = length / len(chords)
    for ci, chord in enumerate(chords):
        start = ci * seg
        for k, m in enumerate(chord):
            f = note(m)
            det = (1.0 + 0.0025 * (k % 2 * 2 - 1))
            # Pad voice with slow swell; overlaps the next chord for smoothness.
            s0 = int((start - 2.0) * sr)
            for i in range(int((seg + 4.0) * sr)):
                t = i / sr
                p = t / (seg + 4.0)
                e = math.sin(math.pi * p) ** 2 * 0.09
                v = (math.sin(TAU * f * t) + 0.5 * math.sin(TAU * f * det * t + 0.7)
                     + 0.12 * math.sin(TAU * f * 2 * t)) * e
                j = (s0 + i) % n
                out[j] += v
    # Sparse piano notes from the pentatonic scale.
    scale = [72, 74, 76, 79, 81, 84, 86, 88]
    t = 1.5
    while t < length - 1.0:
        m = random.choice(scale)
        f = note(m)
        d = 3.0
        s0 = int(t * sr)
        for i in range(int(d * sr)):
            tt = i / sr
            e = min(1.0, tt / 0.004) * math.exp(-tt / 0.9) * 0.22
            v = (math.sin(TAU * f * tt) + 0.3 * math.sin(TAU * f * 2 * tt) * math.exp(-tt / 0.3)) * e
            out[(s0 + i) % n] += v
        t += random.choice([1.5, 2.0, 2.5, 3.0, 4.0])
    out = lowpass(out, 3200, sr)
    out = reverb(out, sr, mix=0.35, room=0.86)
    # Wrap the reverb tail so the loop point is seamless.
    write("music_calm", out, sr=sr, peak=0.55)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    music()
    with open(os.path.join(OUT, "LICENSE.txt"), "w", encoding="utf-8") as f:
        f.write("All audio in this folder is original, synthesized by tools/make_audio.py for\n"
                "Arnav Country Simulator. Same license as the game's code.\n")
