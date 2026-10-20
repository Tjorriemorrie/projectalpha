"""Small helpers shared by the placeholder sound scripts: tones, sweeps, noise, envelopes and 16-bit WAV output.

Standard library only. Sounds are lists of floats from -1 to 1 at SAMPLE_RATE.
"""

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
GAME = Path(__file__).resolve().parents[2] / "game"


def silence(duration: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * duration)


def sweep(duration: float, start_hz: float, end_hz: float, harmonics: tuple[float, ...] = (1.0,),
          curve: float = 1.0) -> list[float]:
    """A tone gliding from start_hz to end_hz. harmonics are the loudness of each multiple of the frequency;
    curve bends the glide (above 1 drops fast at first, like a laser)."""
    samples = []
    phase = 0.0
    count = int(SAMPLE_RATE * duration)
    for i in range(count):
        progress = (i / count) ** (1.0 / curve)
        frequency = start_hz + (end_hz - start_hz) * progress
        phase += 2.0 * math.pi * frequency / SAMPLE_RATE
        samples.append(sum(level * math.sin(phase * (n + 1)) for n, level in enumerate(harmonics)))
    return samples


def noise(duration: float, seed: int, smoothing: float = 0.0) -> list[float]:
    """White noise; smoothing from 0 to just under 1 low-passes it into a duller rush."""
    rng = random.Random(seed)
    samples = []
    previous = 0.0
    for _ in range(int(SAMPLE_RATE * duration)):
        previous = previous * smoothing + rng.uniform(-1.0, 1.0) * (1.0 - smoothing)
        samples.append(previous)
    return samples


def envelope(samples: list[float], attack: float, decay_per_second: float) -> list[float]:
    """A quick linear attack, then an exponential decay."""
    out = []
    for i, value in enumerate(samples):
        t = i / SAMPLE_RATE
        out.append(value * min(t / attack, 1.0) * math.exp(-decay_per_second * t) if attack > 0.0
                   else value * math.exp(-decay_per_second * t))
    return out


def fade(samples: list[float], fade_in: float, fade_out: float) -> list[float]:
    count = len(samples)
    fade_in_count = max(int(SAMPLE_RATE * fade_in), 1)
    fade_out_count = max(int(SAMPLE_RATE * fade_out), 1)
    return [value * min(i / fade_in_count, 1.0) * min((count - i) / fade_out_count, 1.0)
            for i, value in enumerate(samples)]


def mix(*layers: tuple[list[float], float, float]) -> list[float]:
    """Mixes (samples, loudness, start in seconds) layers into one sound as long as the longest."""
    length = max(int(start * SAMPLE_RATE) + len(samples) for samples, _, start in layers)
    out = [0.0] * length
    for samples, loudness, start in layers:
        offset = int(start * SAMPLE_RATE)
        for i, value in enumerate(samples):
            out[offset + i] += value * loudness
    return out


def write(path: Path, samples: list[float], peak: float = 0.7) -> None:
    """Normalises to peak and writes a 16-bit mono WAV."""
    scale = peak / max(max(abs(s) for s in samples), 1e-9)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(b"".join(struct.pack("<h", round(s * scale * 32767)) for s in samples))
    print(f"🔊 Wrote sound: path={path.relative_to(GAME.parent)}, duration={len(samples) / SAMPLE_RATE:.2f} s")
