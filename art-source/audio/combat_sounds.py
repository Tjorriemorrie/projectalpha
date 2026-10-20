"""Generates the placeholder sounds for being hit and for the debug watchers' red lasers.

Run from the repository root: python art-source/audio/combat_sounds.py
Writes 16-bit mono 44.1 kHz WAVs: game/assets/audio/player_hit.wav (shared, the player isn't content) and
game/scenes/test/watcher_shot.wav (the test level's debug watchers).
"""

import synth


def player_hit() -> list[float]:
    """A body blow: a low thud, a sizzle of burnt suit and a sharp crack on top."""
    thud = synth.envelope(synth.sweep(0.25, 90.0, 40.0, (1.0, 0.4)), 0.002, 14.0)
    sizzle = synth.envelope(synth.noise(0.35, seed=4, smoothing=0.2), 0.002, 9.0)
    crack = synth.envelope(synth.noise(0.04, seed=5), 0.0005, 80.0)
    return synth.mix((thud, 1.0, 0.0), (sizzle, 0.35, 0.0), (crack, 0.6, 0.0))


def watcher_shot() -> list[float]:
    """A harsher, lower zap than the player's pistol, so enemy fire sounds different."""
    zap = synth.envelope(synth.sweep(0.25, 1300.0, 220.0, (1.0, 0.0, 0.33, 0.0, 0.2), curve=2.0), 0.002, 12.0)
    hiss = synth.envelope(synth.noise(0.15, seed=6, smoothing=0.4), 0.001, 30.0)
    return synth.mix((zap, 1.0, 0.0), (hiss, 0.3, 0.0))


def main() -> None:
    synth.write(synth.GAME / "assets" / "audio" / "player_hit.wav", player_hit(), peak=0.8)
    synth.write(synth.GAME / "scenes" / "test" / "watcher_shot.wav", watcher_shot())


if __name__ == "__main__":
    main()
