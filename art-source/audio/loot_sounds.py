"""Generates the looting placeholder sounds: prying a container open (a scraping, creaking loop while held, and the
clunk when it gives), opening and closing the inventory, picking an item up and putting it down in the grid, the
dull bump when it doesn't fit, and an item clattering onto the floor.

Run from the repository root: python art-source/audio/loot_sounds.py
Writes 16-bit mono 44.1 kHz WAVs into game/assets/audio/loot/. pry.wav loops seamlessly and is imported looping.
"""

import math

import synth

LOOT = synth.GAME / "assets" / "audio" / "loot"
# The pry loop lasts a whole number of cycles of every frequency in it.
LOOP_DURATION = 1.0


def knock(duration: float, hz: float, decay: float, seed: int, grit: float = 0.3) -> list[float]:
    """A short hollow knock: a low tone dying away fast, with a tick of noise at the start."""
    tone = synth.envelope(synth.sweep(duration, hz * 1.4, hz, (1.0, 0.35, 0.15), curve=3.0), 0.001, decay)
    tick = synth.envelope(synth.noise(duration, seed=seed, smoothing=0.3), 0.0005, decay * 4.0)
    return [t + n * grit for t, n in zip(tone, tick)]


def clink(duration: float, partials: tuple[float, ...], decay: float) -> list[float]:
    """Small metal parts touching: a few high inharmonic partials ringing briefly."""
    count = int(synth.SAMPLE_RATE * duration)
    return [sum(math.sin(2.0 * math.pi * hz * i / synth.SAMPLE_RATE) * math.exp(-decay * (1.0 + n * 0.5) * i
                                                                               / synth.SAMPLE_RATE) / (n + 1)
                for n, hz in enumerate(partials)) for i in range(count)]


def pry() -> list[float]:
    """A crowbar working a seam: a grinding scrape that swells and eases four times a second, and a metal creak
    groaning under it."""
    scrape = synth.noise(LOOP_DURATION, seed=31, smoothing=0.55)
    creak = synth.sweep(LOOP_DURATION, 140.0, 140.0, (1.0, 0.6, 0.45, 0.3, 0.2))
    pulse = synth.sweep(LOOP_DURATION, 4.0, 4.0)
    wobble = synth.sweep(LOOP_DURATION, 7.0, 7.0)
    return [s * (0.55 + 0.45 * max(p, 0.0)) + c * 0.3 * (0.6 + 0.4 * w)
            for s, c, p, w in zip(scrape, creak, pulse, wobble)]


def pry_open() -> list[float]:
    """The seal gives: a sharp crack, a metallic clunk and a short rattle."""
    crack = synth.envelope(synth.noise(0.08, seed=32), 0.0005, 45.0)
    clunk = knock(0.35, 95.0, 14.0, seed=33)
    rattle = clink(0.25, (1900.0, 2650.0, 3400.0), 18.0)
    return synth.mix((crack, 0.8, 0.0), (clunk, 1.0, 0.01), (rattle, 0.25, 0.05))


def inventory_open() -> list[float]:
    """A pack flap thrown open: a rising rustle of fabric and a buckle's click."""
    rustle = synth.fade(synth.noise(0.22, seed=34, smoothing=0.75), 0.06, 0.1)
    buckle = clink(0.08, (2400.0, 3300.0), 40.0)
    return synth.mix((rustle, 1.0, 0.0), (buckle, 0.35, 0.16))


def inventory_close() -> list[float]:
    """The flap closed: a shorter, duller rustle that settles."""
    rustle = synth.fade(synth.noise(0.16, seed=35, smoothing=0.85), 0.01, 0.12)
    thump = knock(0.12, 120.0, 30.0, seed=36, grit=0.1)
    return synth.mix((rustle, 1.0, 0.0), (thump, 0.4, 0.08))


def item_pick() -> list[float]:
    """Lifting a part: a quick scuff and a light clink."""
    scuff = synth.fade(synth.noise(0.06, seed=37, smoothing=0.6), 0.005, 0.04)
    return synth.mix((scuff, 0.6, 0.0), (clink(0.12, (1500.0, 2200.0), 30.0), 0.5, 0.015))


def item_place() -> list[float]:
    """Setting a part down: a soft, solid clack."""
    return synth.mix((knock(0.14, 210.0, 32.0, seed=38, grit=0.5), 1.0, 0.0),
                     (clink(0.08, (1100.0, 1700.0), 45.0), 0.2, 0.0))


def item_bump() -> list[float]:
    """It doesn't fit: a dull, low bump."""
    return knock(0.2, 70.0, 22.0, seed=39, grit=0.15)


def item_drop() -> list[float]:
    """A part hitting the deck: a knock and a scatter of metallic bounces."""
    hit = knock(0.3, 160.0, 16.0, seed=40, grit=0.6)
    layers = [(hit, 1.0, 0.0)]
    for n, (start, loudness) in enumerate(((0.09, 0.5), (0.16, 0.3), (0.21, 0.18))):
        layers.append((clink(0.1, (1300.0 + n * 170.0, 2100.0 + n * 240.0), 35.0), loudness, start))
        layers.append((knock(0.08, 200.0, 40.0, seed=41 + n, grit=0.5), loudness * 0.6, start))
    return synth.mix(*layers)


def main() -> None:
    synth.write(LOOT / "pry.wav", pry(), peak=0.5)
    synth.write(LOOT / "pry_open.wav", pry_open(), peak=0.8)
    synth.write(LOOT / "inventory_open.wav", inventory_open(), peak=0.5)
    synth.write(LOOT / "inventory_close.wav", inventory_close(), peak=0.45)
    synth.write(LOOT / "item_pick.wav", item_pick(), peak=0.5)
    synth.write(LOOT / "item_place.wav", item_place(), peak=0.55)
    synth.write(LOOT / "item_bump.wav", item_bump(), peak=0.6)
    synth.write(LOOT / "item_drop.wav", item_drop(), peak=0.7)


if __name__ == "__main__":
    main()
