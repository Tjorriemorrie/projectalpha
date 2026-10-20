"""Generates the laser pistol's placeholder sounds: shot, charged shot, charge hum (a seamless loop), the reload's
clip out and clip in, and the dry click of a saturated clip.

Run from the repository root: python art-source/audio/laser_pistol.py
Writes 16-bit mono 44.1 kHz WAVs into game/content/base/weapons/laser_pistol/.
"""

import synth

OUTPUT = synth.GAME / "content" / "base" / "weapons" / "laser_pistol"
# The hum loops, so it lasts a whole number of cycles of every frequency in it.
HUM_HZ = 110.0
HUM_DURATION = 1.0


def shot() -> list[float]:
    """A bright, cold zap: a fast falling sweep over a short hiss."""
    zap = synth.envelope(synth.sweep(0.22, 2600.0, 380.0, (1.0, 0.35, 0.15), curve=2.5), 0.002, 16.0)
    hiss = synth.envelope(synth.noise(0.12, seed=1, smoothing=0.3), 0.001, 40.0)
    return synth.mix((zap, 1.0, 0.0), (hiss, 0.35, 0.0))


def charged_shot() -> list[float]:
    """A heavier blast: a deeper, longer sweep with a low thump and a rush of noise."""
    zap = synth.envelope(synth.sweep(0.45, 1800.0, 140.0, (1.0, 0.5, 0.25, 0.1), curve=2.0), 0.002, 7.0)
    thump = synth.envelope(synth.sweep(0.3, 120.0, 45.0), 0.003, 12.0)
    rush = synth.envelope(synth.noise(0.4, seed=2, smoothing=0.6), 0.002, 10.0)
    return synth.mix((zap, 1.0, 0.0), (thump, 0.8, 0.0), (rush, 0.4, 0.0))


def charge_hum() -> list[float]:
    """A steady electric hum with a slow wobble. Godot raises its pitch as the charge grows."""
    tone = synth.sweep(HUM_DURATION, HUM_HZ, HUM_HZ, (1.0, 0.5, 0.3, 0.2, 0.12))
    wobble = synth.sweep(HUM_DURATION, 4.0, 4.0)
    return [value * (0.8 + 0.2 * w) for value, w in zip(tone, wobble)]


def clip_out() -> list[float]:
    """The hot clip unlatching: a metal clack, then a hiss of venting heat."""
    clack = synth.envelope(synth.sweep(0.08, 900.0, 500.0, (1.0, 0.6, 0.4)), 0.001, 60.0)
    hiss = synth.fade(synth.noise(0.7, seed=3, smoothing=0.1), 0.05, 0.4)
    return synth.mix((clack, 1.0, 0.0), (hiss, 0.25, 0.05))


def clip_in() -> list[float]:
    """The fresh clip seating with a click, then the emitter powering back up."""
    click = synth.envelope(synth.sweep(0.05, 1400.0, 1000.0, (1.0, 0.5)), 0.001, 90.0)
    whine = synth.fade(synth.sweep(0.5, 300.0, 1500.0, (1.0, 0.3), curve=0.6), 0.05, 0.15)
    return synth.mix((click, 1.0, 0.0), (whine, 0.3, 0.08))


def dry_click() -> list[float]:
    """A dead trigger: a small click and a short, failing buzz."""
    click = synth.envelope(synth.sweep(0.03, 1800.0, 1200.0), 0.0005, 120.0)
    buzz = synth.envelope(synth.sweep(0.12, 160.0, 120.0, (1.0, 0.8, 0.6, 0.4)), 0.002, 25.0)
    return synth.mix((click, 1.0, 0.0), (buzz, 0.3, 0.01))


def main() -> None:
    synth.write(OUTPUT / "shot.wav", shot())
    synth.write(OUTPUT / "charged_shot.wav", charged_shot(), peak=0.8)
    synth.write(OUTPUT / "charge_hum.wav", charge_hum(), peak=0.35)
    synth.write(OUTPUT / "clip_out.wav", clip_out(), peak=0.6)
    synth.write(OUTPUT / "clip_in.wav", clip_in(), peak=0.6)
    synth.write(OUTPUT / "dry_click.wav", dry_click(), peak=0.5)


if __name__ == "__main__":
    main()
