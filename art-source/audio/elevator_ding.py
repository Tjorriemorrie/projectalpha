"""Generates the placeholder elevator ding: a soft bell tone with a few harmonics and an exponential decay.

Run from the repository root: python art-source/audio/elevator_ding.py
Writes game/content/base/sections/elevator/elevator_ding.wav (16-bit mono, 44.1 kHz).
"""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
DURATION = 1.6
FUNDAMENTAL = 880.0
# (frequency multiple, relative loudness, decay per second): bell-like partials that fade at different rates.
PARTIALS = [(1.0, 1.0, 3.0), (2.0, 0.35, 5.0), (3.0, 0.15, 8.0), (4.2, 0.08, 12.0)]
ATTACK = 0.005
PEAK = 0.6
OUTPUT = (Path(__file__).resolve().parents[2] / "game" / "content" / "base" / "sections" / "elevator"
          / "elevator_ding.wav")


def sample(t: float) -> float:
    attack = min(t / ATTACK, 1.0)
    tone = sum(level * math.exp(-decay * t) * math.sin(2.0 * math.pi * FUNDAMENTAL * multiple * t)
               for multiple, level, decay in PARTIALS)
    return attack * tone


def main() -> None:
    samples = [sample(i / SAMPLE_RATE) for i in range(int(SAMPLE_RATE * DURATION))]
    scale = PEAK / max(abs(s) for s in samples)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(b"".join(struct.pack("<h", round(s * scale * 32767)) for s in samples))
    print(f"🔔 Wrote elevator ding: path={OUTPUT}, duration={DURATION} s, samples={len(samples)}")


if __name__ == "__main__":
    main()
