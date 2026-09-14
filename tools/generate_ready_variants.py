"""Original confirmation cues with a synthesized komuz-inspired plucked timbre.

These are string models, not recordings of an acoustic komuz.
"""
from pathlib import Path
import array
import math
import random
import wave

RATE = 48000
DEST = Path(__file__).resolve().parents[1] / 'work/ready-variants'


def string_note(frequency, duration, seed):
    """Damped delay-line string excited by a soft, uneven finger pluck."""
    rng = random.Random(seed)
    delay = RATE / frequency - .5
    size = math.ceil(delay) + 2
    # A displaced string plus a little finger texture, with its DC removed.
    position = rng.uniform(.19, .27)
    line = []
    for i in range(size):
        x = i / size
        triangle = x / position if x < position else (1 - x) / (1 - position)
        line.append(triangle + rng.uniform(-.14, .14))
    mean = sum(line) / size
    line = [v - mean for v in line]
    for _ in range(2):
        line = [(line[i - 1] + 2 * line[i] + line[(i + 1) % size]) / 4 for i in range(size)]
    cursor = 0
    previous = 0.0
    body = 0.0
    result = []
    for i in range(round(duration * RATE)):
        read = (cursor - delay) % size
        lower = int(read)
        fraction = read - lower
        value = line[lower] * (1 - fraction) + line[(lower + 1) % size] * fraction
        line[cursor] = .996 * (value + previous) * .5
        previous = value
        cursor = (cursor + 1) % size
        body += .16 * (value - body)
        t = i / RATE
        attack = math.sin(min(1.0, t / .009) * math.pi / 2) ** 2
        release = min(1.0, (duration - t) / .12) ** 2
        result.append((value * .72 + body * .28) * attack * release * math.exp(-t / .32))
    return result


def render(name, notes, duration, destination):
    mono = [0.0] * int(RATE * duration)
    for index, (onset, frequency, strength) in enumerate(notes):
        offset = round(onset * RATE)
        note = string_note(frequency, duration - onset, 71423 + index * 73 + round(frequency))
        # Equalize string excitation energy while preserving the individual pluck.
        energy = math.sqrt(sum(v * v for v in note) / len(note))
        level = strength * .12 / max(.001, energy)
        for i, value in enumerate(note[:len(mono) - offset]):
            mono[offset + i] += value * level
    mono.extend([0.0] * round(RATE * .065))
    left, right = [], []
    for i, value in enumerate(mono):
        left.append(value + (.07 * mono[i - 1104] if i >= 1104 else 0.0))
        right.append(value + (.07 * mono[i - 1488] if i >= 1488 else 0.0))
    # Match audition loudness; cap peaks so every variant has ample headroom.
    rms = math.sqrt(sum(v * v for v in left + right) / (2 * len(mono)))
    peak = max(max(map(abs, left)), max(map(abs, right)))
    gain = min(.085 / rms, .34 / peak)
    pcm = array.array('h')
    for l, r in zip(left, right):
        pcm.extend((round(l * gain * 32767), round(r * gain * 32767)))
    assert pcm[0] == pcm[1] == pcm[-2] == pcm[-1] == 0
    assert max(map(abs, pcm)) < 32767
    with wave.open(str(destination / f'{name}.wav'), 'wb') as output:
        output.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(pcm.tobytes())
    print(f'{name}: {len(mono) / RATE:.3f}s, peak {peak * gain:.3f}')


def generate_all(destination=DEST):
    destination.mkdir(parents=True, exist_ok=True)
    # Four related signatures; open intervals keep overlapping confirmations calm.
    signatures = [
        [(0, 587.33, .72), (.08, 880, 1.0)],
        [(0, 440, .72), (.105, 659.25, 1.0)],
        [(0, 392, .25), (.012, 783.99, .72), (.095, 1174.66, 1.0)],
        [(0, 293.66, .65), (.065, 440, .72), (.135, 587.33, 1.0)],
    ]
    for player, notes in enumerate(signatures):
        render(f'ready_{player}', notes, .82, destination)
    # Generic ready calls use the first player's signature.
    (destination / 'ready.wav').write_bytes((destination / 'ready_0.wav').read_bytes())


if __name__ == '__main__':
    generate_all()
