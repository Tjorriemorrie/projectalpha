"""Generates the ship and travel placeholder sounds: the ship's low engine hum, the airlock cycling while interact is
held on its outer door, docking (clunks and a hiss, playing through the fade when boarding or extracting), the
thrusters when the ship flies within a system, the jump drive taking the ship to another system, and the clone pod's
hiss when a new clone wakes up.

A sound lasts as long as the animation it goes with. A flight's length varies, so the thrusters come in three parts
that fit any length: the ignition, a seamless loop that plays for as long as the flight, and the stop as the ship
arrives. The jump lasts the fade to black and back (2 x the player's jump_fade_time, 0.9 s).

Run from the repository root: python art-source/audio/ship_sounds.py
Writes 16-bit mono 44.1 kHz WAVs into game/assets/audio/ship/. ship_hum.wav, airlock_cycle.wav and
thruster_loop.wav loop seamlessly and are imported looping.
"""

import math

import synth

SHIP = synth.GAME / "assets" / "audio" / "ship"
# Each loop lasts a whole number of cycles of every steady tone in it; its noise is crossfaded across the seam.
HUM_DURATION = 4.0
CYCLE_DURATION = 1.0
THRUSTER_LOOP_DURATION = 2.0
CROSSFADE = 0.4
# The jump lasts the player's fade to black and back: 2 x jump_fade_time.
JUMP_DURATION = 1.8
# The thrusters' drone, in Hz: a whole number of cycles in THRUSTER_LOOP_DURATION.
THRUSTER_HZ = 54.0


def looped(samples: list[float], crossfade: float) -> list[float]:
    """Folds the last crossfade seconds over the start, so the sound loops without a click; returns the rest."""
    fold = int(synth.SAMPLE_RATE * crossfade)
    body = samples[:-fold]
    tail = samples[-fold:]
    for i in range(fold):
        t = i / fold
        body[i] = body[i] * t + tail[i] * (1.0 - t)
    return body


def knock(duration: float, hz: float, decay: float, seed: int, grit: float = 0.3) -> list[float]:
    """A heavy hollow knock: a low tone dying away, with a tick of noise at the start."""
    tone = synth.envelope(synth.sweep(duration, hz * 1.5, hz, (1.0, 0.4, 0.2), curve=3.0), 0.001, decay)
    tick = synth.envelope(synth.noise(duration, seed=seed, smoothing=0.4), 0.0005, decay * 3.0)
    return [t + n * grit for t, n in zip(tone, tick)]


def hiss(duration: float, seed: int, smoothing: float, attack: float, release: float) -> list[float]:
    """Gas escaping: noise that swells in and fades out."""
    return synth.fade(synth.noise(duration, seed=seed, smoothing=smoothing), attack, release)


def ship_hum() -> list[float]:
    """The engine's low drone: two close tones beating slowly, a quiet octave, and a dull rumble of air."""
    drone = synth.sweep(HUM_DURATION, 55.0, 55.0, (1.0, 0.5, 0.25, 0.1))
    beat = synth.sweep(HUM_DURATION, 55.5, 55.5, (0.6, 0.2))
    octave = synth.sweep(HUM_DURATION, 110.0, 110.0, (0.25,))
    rumble = looped(synth.noise(HUM_DURATION + CROSSFADE, seed=61, smoothing=0.97), CROSSFADE)
    return [d + b + o + r * 6.0 for d, b, o, r in zip(drone, beat, octave, rumble)]


def airlock_cycle() -> list[float]:
    """The airlock working: a pump thumping twice a second over a rushing hiss and a strained motor whine."""
    rush = looped(synth.noise(CYCLE_DURATION + CROSSFADE, seed=62, smoothing=0.35), CROSSFADE)
    whine = synth.sweep(CYCLE_DURATION, 180.0, 180.0, (0.5, 0.3, 0.2, 0.1))
    wobble = synth.sweep(CYCLE_DURATION, 2.0, 2.0)
    layers = [([r * 0.45 + w * 0.25 * (0.7 + 0.3 * m) for r, w, m in zip(rush, whine, wobble)], 1.0, 0.0)]
    for n, start in enumerate((0.0, 0.5)):
        layers.append((knock(0.3, 48.0, 14.0, seed=63 + n, grit=0.25), 1.2, start))
    mixed = synth.mix(*layers)
    return mixed[:len(rush)]


def dock() -> list[float]:
    """Docking: a heavy clamp clunk, a second one as the seal locks, a clink, then pressure equalising with a long
    hiss."""
    first = knock(0.6, 42.0, 7.0, seed=64, grit=0.5)
    second = knock(0.5, 55.0, 9.0, seed=65, grit=0.4)
    clink = [math.sin(2.0 * math.pi * 1700.0 * i / synth.SAMPLE_RATE) * math.exp(-25.0 * i / synth.SAMPLE_RATE)
             for i in range(int(synth.SAMPLE_RATE * 0.2))]
    release = hiss(1.4, seed=66, smoothing=0.5, attack=0.08, release=0.9)
    return synth.mix((first, 1.0, 0.0), (second, 0.8, 0.45), (clink, 0.15, 0.5), (release, 0.35, 0.75))


def thruster_ignite() -> list[float]:
    """A flight's start: the thrusters light with a thump and the roar swells, while thruster_loop.wav fades in under
    it."""
    ignition = knock(0.4, 38.0, 8.0, seed=69, grit=0.6)
    roar = synth.fade(synth.noise(0.6, seed=70, smoothing=0.92), 0.15, 0.35)
    drone = synth.fade(synth.sweep(0.6, 40.0, THRUSTER_HZ, (1.0, 0.5, 0.3)), 0.2, 0.35)
    return synth.mix((ignition, 0.8, 0.0), (roar, 4.5, 0.05), (drone, 0.5, 0.05))


def thruster_loop() -> list[float]:
    """The thrusters roaring as the ship crosses: a steady drone over a rushing roar, looping seamlessly for as long as
    the flight lasts."""
    roar = looped(synth.noise(THRUSTER_LOOP_DURATION + CROSSFADE, seed=74, smoothing=0.92), CROSSFADE)
    drone = synth.sweep(THRUSTER_LOOP_DURATION, THRUSTER_HZ, THRUSTER_HZ, (1.0, 0.5, 0.3))
    return [r * 4.5 + d * 0.5 for r, d in zip(roar, drone)]


def thruster_stop() -> list[float]:
    """A flight's end, as the ship arrives: the clamps knock and the roar dies away."""
    clamp = knock(0.4, 60.0, 11.0, seed=71, grit=0.3)
    roar = synth.fade(synth.noise(0.4, seed=75, smoothing=0.92), 0.0, 0.35)
    drone = synth.fade(synth.sweep(0.4, THRUSTER_HZ, 38.0, (1.0, 0.5, 0.3)), 0.0, 0.35)
    return synth.mix((clamp, 0.6, 0.0), (roar, 4.5, 0.0), (drone, 0.5, 0.0))


def jump() -> list[float]:
    """Jumping to another system, lasting the fade to black and back: the drive's whine climbs as it charges through
    the fade out, a deep thump as the ship goes through, then a falling shimmer and a rumble that die away as the
    screen fades in at the next hub."""
    half = JUMP_DURATION / 2.0
    charge = synth.fade(synth.sweep(half, 110.0, 880.0, (1.0, 0.4, 0.2), curve=0.6), 0.4, 0.05)
    thump = knock(half, 30.0, 4.0, seed=72, grit=0.7)
    shimmer = synth.fade(synth.sweep(half, 760.0, 90.0, (0.6, 0.3, 0.2), curve=2.0), 0.02, 0.7)
    rumble = synth.fade(synth.noise(half, seed=73, smoothing=0.95), 0.05, 0.8)
    start = half
    return synth.mix((charge, 0.3, 0.0), (thump, 1.0, start), (shimmer, 0.2, start), (rumble, 6.0, start))


def pod_hiss() -> list[float]:
    """The clone pod opening: the seal's soft thunk and a breath of gas that falls away."""
    thunk = knock(0.3, 70.0, 16.0, seed=67, grit=0.2)
    breath = hiss(1.6, seed=68, smoothing=0.7, attack=0.05, release=1.2)
    return synth.mix((thunk, 0.7, 0.0), (breath, 0.6, 0.05))


def main() -> None:
    synth.write(SHIP / "ship_hum.wav", ship_hum(), peak=0.5)
    synth.write(SHIP / "airlock_cycle.wav", airlock_cycle(), peak=0.6)
    synth.write(SHIP / "dock.wav", dock(), peak=0.8)
    synth.write(SHIP / "pod_hiss.wav", pod_hiss(), peak=0.5)
    synth.write(SHIP / "thruster_ignite.wav", thruster_ignite(), peak=0.6)
    synth.write(SHIP / "thruster_loop.wav", thruster_loop(), peak=0.45)
    synth.write(SHIP / "thruster_stop.wav", thruster_stop(), peak=0.55)
    synth.write(SHIP / "jump.wav", jump(), peak=0.7)


if __name__ == "__main__":
    main()
