#!/usr/bin/env python3
"""Synthesises the game's sound effects into assets/sfx/*.wav (16-bit mono, 44.1 kHz).

The Roblox version's sounds are Creator Store assets that can't be used outside Roblox, so these are made from
scratch to do the same jobs: one note that the game pitches up a pentatonic scale for each correct hit, a shimmer under
it, a chime when a machine is cleared, a low bonk for a mistake, and so on.

They are meant to be SOFT: mallet and kalimba-like tones (a sine with a little second harmonic and a quick low thump
for body), slow attacks so nothing clicks, no buzzy harmonics, and everything passed through a low-pass filter. The
first set had hard attacks and bright partials and was found too sharp.

Replace any file with a recorded sound of the same name and the game will use it.

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
SOFTEN = 4200.0  # every sound is low-passed here (Hz)


def blank(seconds):
    return [0.0] * int(RATE * seconds)


def add_tone(buf, start, freq, amp, decay, length=None, harmonics=((1.0, 1.0),), attack=0.006, glide=1.0):
    """A decaying tone: each harmonic is (multiple of freq, relative level). The attack is a smooth half-cosine.
    `glide` multiplies the pitch by the end."""
    n0 = int(start * RATE)
    count = len(buf) - n0 if length is None else min(int(length * RATE), len(buf) - n0)
    phases = [0.0] * len(harmonics)
    for i in range(max(count, 0)):
        t = i / RATE
        rise = 0.5 - 0.5 * math.cos(math.pi * min(1.0, t / attack))
        env = math.exp(-t / decay) * rise
        if length is not None:
            env *= min(1.0, (count - i) / (0.012 * RATE))  # ease out at the cut
        f = freq * (glide ** (i / max(count, 1)))
        s = 0.0
        for k, (mult, level) in enumerate(harmonics):
            phases[k] += TAU * f * mult / RATE
            s += level * math.sin(phases[k])
        buf[n0 + i] += amp * env * s


def add_noise(buf, start, amp, decay, length, cutoff=3000.0, cutoff_end=None, rng=None, hump=False):
    """Filtered noise (two one-pole low-passes in a row; the cutoff can sweep). `hump` swells in and out."""
    rng = rng or random.Random(1)
    n0 = int(start * RATE)
    count = min(int(length * RATE), len(buf) - n0)
    y1 = y2 = 0.0
    for i in range(count):
        k = i / max(count - 1, 1)
        fc = cutoff if cutoff_end is None else cutoff * (cutoff_end / cutoff) ** k
        a = 1.0 - math.exp(-TAU * fc / RATE)
        y1 += a * (rng.uniform(-1, 1) - y1)
        y2 += a * (y1 - y2)
        if hump:
            env = math.sin(math.pi * k) ** 2
        else:
            env = math.exp(-(i / RATE) / decay) * min(1.0, i / (0.004 * RATE)) * min(1.0, (count - i) / (0.01 * RATE))
        buf[n0 + i] += amp * env * y2


def soften(buf, cutoff=SOFTEN):
    """A gentle low-pass over the whole sound, and a fade over its last few milliseconds."""
    a = 1.0 - math.exp(-TAU * cutoff / RATE)
    y = 0.0
    out = []
    for s in buf:
        y += a * (s - y)
        out.append(y)
    tail = int(0.02 * RATE)
    for i in range(tail):
        out[-1 - i] *= i / tail
    return out


def save(name, buf, peak=0.7, cutoff=SOFTEN):
    buf = soften(buf, cutoff)
    top = max(abs(s) for s in buf) or 1.0
    scale = peak / top
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in buf))


# A mallet on wood: mostly the note itself, a little of its octave, a trace above.
MALLET = ((1.0, 1.0), (2.0, 0.16), (3.0, 0.04))


def mallet(buf, start, freq, amp, decay):
    add_tone(buf, start, freq, amp, decay, harmonics=MALLET)
    add_tone(buf, start, freq * 0.5, amp * 0.22, 0.045, attack=0.004)  # the thump of the strike


def ding():
    # The correct-hit note. The game plays it at 2^(n/12) for n = 0, 2, 4, 7, 9, 12... so it is one clean note (D5).
    buf = blank(0.75)
    mallet(buf, 0, 587.33, 1.0, 0.2)
    save("ding", buf)


def sparkle():
    # A soft shimmer: a slow scatter of small high notes, each fading in.
    rng = random.Random(7)
    buf = blank(0.9)
    notes = [1174.7, 1318.5, 1480.0, 1760.0, 1975.5, 2349.3]
    for i in range(10):
        add_tone(buf, 0.05 * i + rng.uniform(0, 0.02), rng.choice(notes), 0.5 * (1 - i / 14), 0.1, attack=0.012)
    save("sparkle", buf, 0.5, 3600.0)


def complete():
    # All six lit: a warm rising chord (D major), each note ringing into the next.
    buf = blank(0.9)
    for i, f in enumerate([587.33, 739.99, 880.0, 1174.66]):
        mallet(buf, 0.06 * i, f, 0.8, 0.32)
    add_tone(buf, 0.18, 2349.3, 0.08, 0.3, attack=0.03)
    save("complete", buf)


def coin():
    # A round two-note "bloop".
    buf = blank(0.45)
    add_tone(buf, 0, 987.8, 0.7, 0.3, length=0.075, harmonics=MALLET)
    add_tone(buf, 0.07, 1318.5, 0.7, 0.14, harmonics=MALLET)
    save("coin", buf, 0.55)


def error():
    # A mistake: two low, round bonks stepping down. No buzz.
    buf = blank(0.4)
    low = ((1.0, 1.0), (2.0, 0.22), (3.0, 0.05))
    add_tone(buf, 0, 174.6, 0.9, 0.1, harmonics=low, glide=0.8, length=0.14, attack=0.005)
    add_tone(buf, 0.12, 130.8, 0.9, 0.12, harmonics=low, glide=0.78, attack=0.005)
    save("error", buf, 0.75, 2400.0)


def tick():
    # The cursor moving on: a small wooden "tok". Played very quietly.
    buf = blank(0.06)
    add_tone(buf, 0, 720.0, 1.0, 0.009, attack=0.0015)
    save("tick", buf, 0.6, 3000.0)


def whoosh():
    buf = blank(0.6)
    add_noise(buf, 0, 1.0, 1.0, 0.6, cutoff=300, cutoff_end=2400, hump=True, rng=random.Random(3))
    save("whoosh", buf, 0.6, 3000.0)


def powerup():
    # A multiplier fruit lit: a quick rising run of soft notes.
    buf = blank(0.6)
    for i, f in enumerate([523.3, 659.3, 784.0, 1046.5]):
        mallet(buf, 0.06 * i, f, 0.8, 0.1 if i < 3 else 0.24)
    save("powerup", buf, 0.65)


def clank():
    # A cage cracking: a dull knock of metal, not a ring.
    buf = blank(0.3)
    for f, level, decay in [(410.0, 1.0, 0.06), (1010.0, 0.45, 0.04), (1650.0, 0.2, 0.03)]:
        add_tone(buf, 0, f, level, decay, attack=0.002)
    add_noise(buf, 0, 0.3, 0.012, 0.05, cutoff=2500)
    save("clank", buf, 0.65, 3200.0)


def boom():
    # The bomb: a deep thud with a short rumble.
    buf = blank(0.7)
    add_tone(buf, 0, 120.0, 1.0, 0.2, glide=0.3, attack=0.004)
    add_noise(buf, 0, 0.7, 0.12, 0.5, cutoff=1200, cutoff_end=150, rng=random.Random(5))
    save("boom", buf, 0.8, 1800.0)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for make in (ding, sparkle, complete, coin, error, tick, whoosh, powerup, clank, boom):
        make()
        print("wrote", make.__name__ + ".wav")
