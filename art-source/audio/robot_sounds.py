"""Generates the robots' placeholder sounds: the drone's hum and the turret's servo whir (seamless loops), the voice
chirps (investigating, alarm, lost), the lock-on tone, the red laser shot, the vent hiss, a hit on a robot, and the
dying whine and crash of a destroyed one.

Run from the repository root: python art-source/audio/robot_sounds.py
Writes 16-bit mono 44.1 kHz WAVs: drone_hum.wav into game/content/base/enemies/drone/, turret_servo.wav into
game/content/base/enemies/turret/, and the sounds both robots share into game/assets/audio/robots/.
"""

import math

import synth

ENEMIES = synth.GAME / "content" / "base" / "enemies"
SHARED = synth.GAME / "assets" / "audio" / "robots"
# The loops last a whole number of cycles of every frequency in them.
LOOP_DURATION = 1.0
# The lock-on tone lasts as long as an idle robot takes to lock on; Godot plays it faster for a quicker lock.
LOCK_ON_DURATION = 0.8


def beep(duration: float, start_hz: float, end_hz: float) -> list[float]:
    """A short, square-ish electronic tone with soft edges, for the voice chirps."""
    tone = synth.sweep(duration, start_hz, end_hz, (1.0, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14))
    return synth.fade(tone, 0.005, 0.02)


def clang(duration: float, partials: tuple[float, ...], decay: float) -> list[float]:
    """Struck metal: a few inharmonic partials, each dying away a little faster than the one below it."""
    count = int(synth.SAMPLE_RATE * duration)
    out = []
    for i in range(count):
        t = i / synth.SAMPLE_RATE
        out.append(sum(math.sin(2.0 * math.pi * hz * t) * math.exp(-decay * (1.0 + n * 0.6) * t) / (n + 1)
                       for n, hz in enumerate(partials)))
    return out


def drone_hum() -> list[float]:
    """A low electric hum under a buzzing rotor whose blades pass 30 times a second, and a breath of air."""
    hum = synth.sweep(LOOP_DURATION, 90.0, 90.0, (1.0, 0.45, 0.2))
    rotor = synth.sweep(LOOP_DURATION, 240.0, 240.0, (1.0, 0.5, 0.3, 0.2))
    blades = synth.sweep(LOOP_DURATION, 30.0, 30.0)
    air = synth.noise(LOOP_DURATION, seed=11, smoothing=0.85)
    return [h + r * 0.35 * (0.6 + 0.4 * b) + a * 0.5 for h, r, b, a in zip(hum, rotor, blades, air)]


def turret_servo() -> list[float]:
    """A geared motor whirring: a nasal tone with a fast gear ripple and a grind of noise."""
    motor = synth.sweep(LOOP_DURATION, 180.0, 180.0, (1.0, 0.7, 0.5, 0.35, 0.25, 0.15))
    ripple = synth.sweep(LOOP_DURATION, 45.0, 45.0)
    grind = synth.noise(LOOP_DURATION, seed=12, smoothing=0.5)
    return [m * (0.7 + 0.3 * r) + g * 0.25 for m, r, g in zip(motor, ripple, grind)]


def chirp_investigate() -> list[float]:
    """A questioning two-note chirp that rises at the end: 'huh?'"""
    return synth.mix((beep(0.1, 620.0, 700.0), 1.0, 0.0), (beep(0.16, 760.0, 1250.0), 1.0, 0.13))


def chirp_alarm() -> list[float]:
    """An urgent alarm: three quick high-low warbles."""
    layers = []
    for i in range(3):
        layers.append((beep(0.07, 1550.0, 1550.0), 1.0, i * 0.16))
        layers.append((beep(0.07, 1150.0, 1150.0), 1.0, i * 0.16 + 0.08))
    return synth.mix(*layers)


def chirp_lost() -> list[float]:
    """A falling, wobbling tone, as if the robot is disappointed."""
    fall = beep(0.55, 1250.0, 320.0)
    wobble = synth.sweep(0.55, 9.0, 9.0)
    return [f * (0.75 + 0.25 * w) for f, w in zip(fall, wobble)]


def lock_on() -> list[float]:
    """A rising tone that pulses faster as it climbs, ending on a high peak when the lock completes."""
    rise = synth.sweep(LOCK_ON_DURATION, 380.0, 1700.0, (1.0, 0.0, 0.25), curve=0.7)
    count = len(rise)
    pulsed = []
    phase = 0.0
    for i, value in enumerate(rise):
        rate = 8.0 + 22.0 * (i / count)
        phase += 2.0 * math.pi * rate / synth.SAMPLE_RATE
        pulsed.append(value * (0.55 + 0.45 * math.sin(phase)))
    return synth.fade(pulsed, 0.01, 0.01)


def robot_shot() -> list[float]:
    """A harsher, lower zap than the player's pistol, so enemy fire sounds different."""
    zap = synth.envelope(synth.sweep(0.25, 1250.0, 200.0, (1.0, 0.0, 0.33, 0.0, 0.2), curve=2.0), 0.002, 12.0)
    hiss = synth.envelope(synth.noise(0.15, seed=13, smoothing=0.4), 0.001, 30.0)
    return synth.mix((zap, 1.0, 0.0), (hiss, 0.3, 0.0))


def vent_hiss() -> list[float]:
    """Hot gas venting: a burst of rushing noise with a whistle, dying away over the vent."""
    rush = synth.envelope(synth.noise(2.0, seed=14, smoothing=0.25), 0.03, 1.6)
    whistle = synth.envelope(synth.sweep(2.0, 2400.0, 1700.0), 0.05, 2.2)
    clunk = synth.envelope(synth.sweep(0.12, 300.0, 120.0, (1.0, 0.5)), 0.001, 30.0)
    return synth.mix((rush, 1.0, 0.0), (whistle, 0.12, 0.0), (clunk, 0.6, 0.0))


def robot_hit() -> list[float]:
    """A laser striking armour: a metallic clang and a crackle of sparks."""
    ring = clang(0.5, (520.0, 1347.0, 2210.0, 3150.0), 9.0)
    crackle = synth.envelope(synth.noise(0.12, seed=15), 0.0005, 35.0)
    return synth.mix((ring, 1.0, 0.0), (crackle, 0.5, 0.0))


def robot_destroyed() -> list[float]:
    """Powering down for good: a falling whine sputtering out over crackling electrics."""
    whine = synth.envelope(synth.sweep(1.4, 1700.0, 70.0, (1.0, 0.4, 0.2), curve=1.6), 0.005, 1.2)
    sputter = synth.sweep(1.4, 14.0, 4.0)
    crackle = synth.envelope(synth.noise(1.0, seed=16, smoothing=0.1), 0.001, 3.5)
    pop = synth.envelope(synth.noise(0.06, seed=17), 0.0005, 50.0)
    sputtered = [w * (0.6 + 0.4 * s) for w, s in zip(whine, sputter)]
    return synth.mix((sputtered, 1.0, 0.0), (crackle, 0.3, 0.0), (pop, 0.8, 0.0))


def robot_crash() -> list[float]:
    """Wreckage hitting the deck: a heavy thud, a clang and a short clatter of loose parts."""
    thud = synth.envelope(synth.sweep(0.35, 110.0, 40.0, (1.0, 0.5)), 0.002, 10.0)
    ring = clang(0.7, (310.0, 787.0, 1290.0), 6.0)
    layers = [(thud, 1.0, 0.0), (ring, 0.5, 0.0)]
    for i, start in enumerate((0.09, 0.17, 0.22, 0.31)):
        layers.append((synth.envelope(synth.noise(0.05, seed=20 + i, smoothing=0.2), 0.0005, 60.0), 0.35, start))
    return synth.mix(*layers)


def main() -> None:
    synth.write(ENEMIES / "drone" / "drone_hum.wav", drone_hum(), peak=0.6)
    synth.write(ENEMIES / "turret" / "turret_servo.wav", turret_servo(), peak=0.6)
    synth.write(SHARED / "chirp_investigate.wav", chirp_investigate())
    synth.write(SHARED / "chirp_alarm.wav", chirp_alarm(), peak=0.8)
    synth.write(SHARED / "chirp_lost.wav", chirp_lost())
    synth.write(SHARED / "lock_on.wav", lock_on())
    synth.write(SHARED / "robot_shot.wav", robot_shot())
    synth.write(SHARED / "vent_hiss.wav", vent_hiss())
    synth.write(SHARED / "robot_hit.wav", robot_hit())
    synth.write(SHARED / "robot_destroyed.wav", robot_destroyed(), peak=0.8)
    synth.write(SHARED / "robot_crash.wav", robot_crash(), peak=0.8)


if __name__ == "__main__":
    main()
