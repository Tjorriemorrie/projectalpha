"""Generates the player's placeholder footsteps on a metal deck: walking, sprinting and crouching.

Run from the repository root: python art-source/audio/footsteps.py
Writes 16-bit mono 44.1 kHz WAVs into game/assets/audio/ (shared, the player isn't content). Sprinting is the loudest
and crouching the softest, matching how far each carries as noise for enemies.
"""

import synth

OUTPUT = synth.GAME / "assets" / "audio"


def step(weight: float, ring: float, seed: int) -> list[float]:
    """A boot on deck plating: a low thud whose weight sets its depth, a scuff, and a faint metallic ring."""
    thud = synth.envelope(synth.sweep(0.18, 120.0 - 30.0 * weight, 50.0, (1.0, 0.4)), 0.002, 18.0)
    scuff = synth.envelope(synth.noise(0.08, seed=seed, smoothing=0.45), 0.002, 40.0)
    plate = synth.envelope(synth.sweep(0.25, 780.0, 760.0, (1.0, 0.0, 0.3)), 0.001, 22.0)
    return synth.mix((thud, 1.0, 0.0), (scuff, 0.5, 0.0), (plate, ring, 0.0))


def main() -> None:
    synth.write(OUTPUT / "footstep_walk.wav", step(0.5, 0.12, seed=31), peak=0.45)
    synth.write(OUTPUT / "footstep_sprint.wav", step(1.0, 0.2, seed=32), peak=0.7)
    synth.write(OUTPUT / "footstep_crouch.wav", step(0.2, 0.05, seed=33), peak=0.22)


if __name__ == "__main__":
    main()
