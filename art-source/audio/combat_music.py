"""Generates the placeholder combat music: a tense, seamless 16-second loop at 120 beats per minute.

Run from the repository root: python art-source/audio/combat_music.py
Writes a 16-bit mono 44.1 kHz WAV: game/assets/audio/combat_music.wav. A pulsing bass riff in eighth notes, a kick on
every beat, ticking hats, and a dissonant pad that swells and falls. The pad's tones are whole numbers of cycles
over the loop (multiples of 1/16 Hz), and every note dies away within its beat, so the loop has no seam.
"""

import math

import synth

OUTPUT = synth.GAME / "assets" / "audio" / "combat_music.wav"
BEATS_PER_MINUTE = 120.0
BARS = 8
BEAT = 60.0 / BEATS_PER_MINUTE
LOOP = BARS * 4 * BEAT
# The bass riff, one root note (Hz) per bar: A, A, C, B flat, A, A, G, B flat.
RIFF = (55.0, 55.0, 65.375, 58.25, 55.0, 55.0, 49.0, 58.25)
# The pad: A and B flat a semitone apart, an octave up, beating against each other.
PAD = (220.0, 233.125, 330.0)


def bass_note(hz: float, accent: float) -> list[float]:
    tone = synth.sweep(BEAT / 2.0, hz, hz, (1.0, 0.6, 0.4, 0.25, 0.15))
    # Faded out at its end, so the last note of the loop doesn't click into the first.
    return synth.fade(synth.envelope(tone, 0.004, 6.0 + 4.0 * (1.0 - accent)), 0.0, 0.02)


def kick() -> list[float]:
    return synth.envelope(synth.sweep(0.25, 130.0, 42.0, (1.0, 0.3)), 0.002, 16.0)


def hat(seed: int) -> list[float]:
    return synth.envelope(synth.noise(0.05, seed=seed), 0.0005, 90.0)


def pad() -> list[float]:
    """Swells over each four bars and falls back, so it breathes with the riff."""
    count = int(synth.SAMPLE_RATE * LOOP)
    out = []
    for i in range(count):
        t = i / synth.SAMPLE_RATE
        swell = 0.5 - 0.5 * math.cos(2.0 * math.pi * t / (LOOP / 2.0))
        out.append(swell * sum(math.sin(2.0 * math.pi * hz * t) for hz in PAD) / len(PAD))
    return out


def main() -> None:
    layers = [(pad(), 0.25, 0.0)]
    for bar, root in enumerate(RIFF):
        for eighth in range(8):
            start = (bar * 4 + eighth / 2.0) * BEAT
            # The riff jumps up an octave on the last eighth of each bar.
            hz = root * 2.0 if eighth == 7 else root
            layers.append((bass_note(hz, 1.0 if eighth % 2 == 0 else 0.5), 0.55, start))
        for beat in range(4):
            layers.append((kick(), 0.8, (bar * 4 + beat) * BEAT))
        for sixteenth in range(16):
            layers.append((hat(100 + bar * 16 + sixteenth), 0.12 if sixteenth % 2 else 0.2,
                           (bar * 4 + sixteenth / 4.0) * BEAT))
    music = synth.mix(*layers)[:int(synth.SAMPLE_RATE * LOOP)]
    synth.write(OUTPUT, music, peak=0.6)


if __name__ == "__main__":
    main()
