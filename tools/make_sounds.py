#!/usr/bin/env python3
"""Synthesises the game's sound effects into assets/sfx/*.wav (16-bit mono, 44.1 kHz).

The Roblox version's sounds are Creator Store assets that can't be used outside Roblox, so these are stand-ins made
from scratch, shaped to do the same jobs: one bright ping that the game pitches up a pentatonic scale for each correct
hit, a shimmer under it, a pick-up chime when a machine is cleared, a fail blip, and so on. Replace any file with a
recorded sound of the same name and the game will use it.

Run from the repository root:  python3 tools/make_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
TAU = 2 * math.pi


def blank(seconds):
    return [0.0] * int(RATE * seconds)


def add_tone(buf, start, freq, amp, decay, length=None, harmonics=((1.0, 1.0),), attack=0.002, glide=1.0):
    """A decaying tone: each harmonic is (multiple of freq, relative level). `glide` multiplies the pitch by the end."""
    n0 = int(start * RATE)
    count = len(buf) - n0 if length is None else min(int(length * RATE), len(buf) - n0)
    phases = [0.0] * len(harmonics)
    for i in range(max(count, 0)):
        t = i / RATE
        env = math.exp(-t / decay) * min(1.0, t / attack)
        if length is not None:
            env *= min(1.0, (count - i) / (0.004 * RATE))  # no click at the cut
        f = freq * (glide ** (i / max(count, 1)))
        s = 0.0
        for k, (mult, level) in enumerate(harmonics):
            phases[k] += TAU * f * mult / RATE
            s += level * math.sin(phases[k])
        buf[n0 + i] += amp * env * s


def add_noise(buf, start, amp, decay, length, cutoff=6000.0, cutoff_end=None, rng=None, hump=False):
    """Filtered noise (one-pole low-pass whose cutoff can sweep). `hump` swells in and out instead of decaying."""
    rng = rng or random.Random(1)
    n0 = int(start * RATE)
    count = min(int(length * RATE), len(buf) - n0)
    y = 0.0
    for i in range(count):
        k = i / max(count - 1, 1)
        fc = cutoff if cutoff_end is None else cutoff * (cutoff_end / cutoff) ** k
        a = 1.0 - math.exp(-TAU * fc / RATE)
        y += a * (rng.uniform(-1, 1) - y)
        env = math.sin(math.pi * k) ** 2 if hump else math.exp(-(i / RATE) / decay) * min(1.0, (count - i) / (0.004 * RATE))
        buf[n0 + i] += amp * env * y


def save(name, buf, peak=0.85):
    top = max(abs(s) for s in buf) or 1.0
    scale = peak / top
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in buf))


BELL = ((1.0, 1.0), (2.0, 0.42), (3.0, 0.18), (4.16, 0.1))


def ding():
    # The correct-hit ping. The game plays it at 2^(n/12) for n = 0, 2, 4, 7, 9, 12... so it must be one clean note.
    buf = blank(0.7)
    add_tone(buf, 0, 784.0, 1.0, 0.16, harmonics=BELL)
    add_tone(buf, 0, 784.0 * 5.4, 0.12, 0.03)
    add_noise(buf, 0, 0.25, 0.004, 0.02, cutoff=9000)
    save("ding", buf)


def sparkle():
    # A gem shimmer: a scatter of tiny high notes.
    rng = random.Random(7)
    buf = blank(0.9)
    notes = [2093.0, 2349.3, 2637.0, 3136.0, 3520.0, 4186.0, 4698.6]
    for i in range(16):
        add_tone(buf, 0.035 * i + rng.uniform(0, 0.02), rng.choice(notes), 0.6 * (1 - i / 20), 0.07)
    save("sparkle", buf, 0.7)


def complete():
    # All six lit: a "picked up gold" chime.
    buf = blank(0.77)
    for i, f in enumerate([987.8, 1318.5, 1975.5]):
        add_tone(buf, 0.07 * i, f, 0.9, 0.2, harmonics=BELL)
    add_tone(buf, 0.14, 3951.0, 0.2, 0.25)
    save("complete", buf)


def coin():
    buf = blank(0.45)
    square = ((1.0, 1.0), (3.0, 0.33), (5.0, 0.2))
    add_tone(buf, 0, 987.8, 0.7, 0.3, length=0.07, harmonics=square)
    add_tone(buf, 0.07, 1318.5, 0.7, 0.13, harmonics=square)
    save("coin", buf, 0.6)


def error():
    # A mistake: a short, low, buzzy two-step down.
    buf = blank(0.35)
    buzz = ((1.0, 1.0), (2.0, 0.5), (3.0, 0.45), (4.0, 0.25), (5.0, 0.25), (7.0, 0.12))
    add_tone(buf, 0, 196.0, 0.9, 0.3, length=0.13, harmonics=buzz)
    add_tone(buf, 0.13, 146.8, 0.9, 0.12, harmonics=buzz)
    save("error", buf)


def tick():
    # The cursor moving on. Played very quietly.
    buf = blank(0.04)
    add_tone(buf, 0, 1150.0, 1.0, 0.006, attack=0.0005)
    add_noise(buf, 0, 0.4, 0.002, 0.01, cutoff=7000)
    save("tick", buf, 0.8)


def whoosh():
    buf = blank(0.6)
    add_noise(buf, 0, 1.0, 1.0, 0.6, cutoff=500, cutoff_end=5000, hump=True, rng=random.Random(3))
    save("whoosh", buf, 0.7)


def powerup():
    # A multiplier fruit lit: a quick rising run.
    buf = blank(0.5)
    soft = ((1.0, 1.0), (3.0, 0.11), (5.0, 0.04))
    for i, f in enumerate([523.3, 659.3, 784.0, 1046.5]):
        add_tone(buf, 0.06 * i, f, 0.8, 0.09 if i < 3 else 0.2, harmonics=soft)
    save("powerup", buf, 0.75)


def clank():
    # A cage cracking: struck metal.
    buf = blank(0.3)
    for f, level, decay in [(520.0, 1.0, 0.07), (1310.0, 0.7, 0.05), (2140.0, 0.5, 0.04), (3370.0, 0.35, 0.03)]:
        add_tone(buf, 0, f, level, decay, attack=0.0005)
    add_noise(buf, 0, 0.5, 0.01, 0.05, cutoff=8000)
    save("clank", buf, 0.8)


def boom():
    # The bomb.
    buf = blank(0.7)
    add_tone(buf, 0, 130.0, 1.0, 0.2, glide=0.3, attack=0.001)
    add_noise(buf, 0, 0.9, 0.12, 0.5, cutoff=2500, cutoff_end=200, rng=random.Random(5))
    save("boom", buf, 0.9)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for make in (ding, sparkle, complete, coin, error, tick, whoosh, powerup, clank, boom):
        make()
        print("wrote", make.__name__ + ".wav")
