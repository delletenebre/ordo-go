"""Four original extended menu compositions using a komuz-inspired string model.

No instrument recordings or third-party samples. Standard-library-only synthesis.
Run: python3 tools/generate_menu_themes.py
Outputs audition WAVs and a manifest under work/menu-themes.
"""
from pathlib import Path
from functools import lru_cache
import array
import hashlib
import json
import math
import random
import wave

RATE = 24000
DEST = Path(__file__).resolve().parents[1] / 'work/menu-themes'


@lru_cache(maxsize=160)
def string(midi, touch, variation):
    rng = random.Random(8100 + midi * 37 + variation * 113)
    frequency = 440 * 2 ** ((midi - 69) / 12)
    delay = RATE / frequency - .5
    size = math.ceil(delay) + 2
    position = rng.uniform(.20, .29)
    line = []
    for i in range(size):
        x = i / size
        triangle = x / position if x < position else (1 - x) / (1 - position)
        line.append(triangle + rng.uniform(-.24, .24))
    mean = sum(line) / size
    line = [v - mean for v in line]
    for _ in range(2):
        line = [(line[i - 1] + 2 * line[i] + line[(i + 1) % size]) / 4 for i in range(size)]
    length = 2.8 if touch == 'open' else 1.4
    decay = 1.35 if touch == 'open' else .38
    out = array.array('f')
    previous = body = 0.0
    cursor = 0
    for i in range(round(RATE * length)):
        read = (cursor - delay) % size
        lower = int(read)
        fraction = read - lower
        value = line[lower] * (1 - fraction) + line[(lower + 1) % size] * fraction
        line[cursor] = .9985 * (value + previous) * .5
        previous = value
        cursor = (cursor + 1) % size
        body += .22 * (value - body)
        t = i / RATE
        attack = math.sin(min(1, t / .010) * math.pi / 2) ** 2
        release = min(1, (length - t) / .18) ** 2
        out.append((value * .72 + body * .28) * attack * release * math.exp(-t / decay))
    peak = max(map(abs, out))
    return array.array('f', (v * .65 / peak for v in out))


def tap(seed, low=False):
    rng = random.Random(seed)
    out = array.array('f')
    filtered = 0.0
    length = .16 if low else .09
    for i in range(round(length * RATE)):
        t = i / RATE
        filtered = .87 * filtered + .13 * rng.uniform(-1, 1)
        body = math.sin(math.tau * (118 if low else 205) * t) * .25
        attack = min(1, t / .006)
        out.append((filtered + body) * attack * (1 - t / length) ** 3)
    return out


# Each eight-bar melody is authored separately; values are semitone offsets.
THEMES = [
    dict(file='01-mountain-dawn', title='Рассвет в горах', bpm=84, meter=4, root=50,
         feel='Просторная мелодия, открытые струны, спокойное развитие.',
         a=[[4,7,9],[7,4,2],[0,4,7],[9,7,4],[7,12,9],[7,4,2],[4,2,0],[2,0]],
         b=[[12,9,7],[9,7,4],[7,9,12],[14,12,9],[12,7,9],[7,4,2],[4,7,2],[2,0]],
         roots=[0,0,7,7,5,5,7,0], rhythm=[0,1.5,2.75], percussion=.035),
    dict(file='02-warm-yurt', title='Тёплая юрта', bpm=72, meter=4, root=45,
         feel='Низкий регистр, неспешные ответы и мягкие переборы.',
         a=[[0,7,4],[2,4,0],[7,9,7],[4,2],[0,4,7],[9,7,4],[2,7,4],[2,0]],
         b=[[7,12,11],[9,7,4],[7,4,2],[4,7],[9,12,9],[7,4,2],[0,2,4],[2,0]],
         roots=[0,0,5,0,5,5,7,0], rhythm=[.25,1.75,3], percussion=0),
    dict(file='03-mountain-path', title='Тропа к перевалу', bpm=66, meter=3, root=50,
         feel='Лёгкое покачивание в трёхдольном ритме, живые переклички.',
         a=[[0,4,7,9],[7,4,2],[4,7,12],[9,7],[7,9,12,9],[7,4,2],[4,2,7],[2,0]],
         b=[[12,14,12,9],[7,9,7],[9,12,14],[12,9],[7,12,9,7],[4,7,9],[7,4,2],[2,0]],
         roots=[0,0,7,7,5,0,7,0], rhythm=[0,.75,1.5,2.25], percussion=.065),
    dict(file='04-evening-hearth', title='Вечер у очага', bpm=80, meter=4, root=50,
         feel='Тихая задумчивая тема, редкие флажолеты и тёплые низкие струны.',
         a=[[9,7,4],[2,0],[4,7,9],[7,4],[2,4,7],[9,7,4],[2,7,4],[2,0]],
         b=[[12,9,7],[4,2],[9,12,14],[12,9],[7,9,12],[9,7,4],[7,4,2],[2,0]],
         roots=[0,7,0,0,5,5,7,0], rhythm=[.5,2,3.25], percussion=.022),
]


def compose(theme, theme_index):
    beat = 60 / theme['bpm']
    meter = theme['meter']
    bar_time = meter * beat
    length = 48 * bar_time
    count = round(length * RATE)
    left = array.array('f', [0]) * count
    right = array.array('f', [0]) * count
    rng = random.Random(20000 + theme_index)
    events = []

    def add(onset, samples, level, pan=0):
        offset = round(onset * RATE)
        l_gain = level * math.sqrt((1 - pan) / 2)
        r_gain = level * math.sqrt((1 + pan) / 2)
        for i, value in enumerate(samples):
            k = (offset + i) % count
            left[k] += value * l_gain
            right[k] += value * r_gain

    def note(bar, when, midi, strength, touch='open', pan=0):
        variation = rng.randrange(3)
        onset = bar * bar_time + when * beat + rng.uniform(-.011, .011)
        strength *= rng.uniform(.92, 1.04)
        add(onset, string(midi, touch, variation), strength, pan)
        events.append([round(onset, 4), midi, round(strength, 4), touch])

    # Intro 4, A 8, A' 8, B 8, bridge 8, return 8, coda 4 bars.
    for bar in range(48):
        intro = bar < 4
        coda = bar >= 44
        bridge = 28 <= bar < 36
        phrase_index = (bar - 4) % 8
        harmony = theme['root'] + theme['roots'][phrase_index]
        density = .70 if intro or coda else (.78 if bridge else 1.0)
        note(bar, 0, harmony - 12, .21 * density, pan=-.12)
        # Broken open fifths supply a restrained three-string foundation.
        if bar % 2 == 0 or not (intro or coda):
            note(bar, meter * .50, harmony - 5, .12 * density, 'muted', .20)
        if not intro and not coda and not bridge:
            note(bar, meter * .25, harmony, .075, 'muted', -.25)
            note(bar, meter * .75, harmony - 5, .07, 'muted', .20)

        if intro:
            if bar >= 2:
                note(bar, meter * .35, theme['root'] + (7 if bar == 2 else 4), .19)
            continue
        if coda:
            for when, interval in zip([.3, meter * .50], [[7,4],[2,0],[7,0],[0]][bar-44]):
                note(bar, when, theme['root'] + interval, .23 if bar < 47 else .18)
            continue

        melody = theme['b'] if 20 <= bar < 28 else theme['a']
        line = melody[phrase_index]
        if bridge:
            # The middle thins out into a lower-register answer.
            line = list(reversed(theme['a'][phrase_index][:2]))
        for index, interval in enumerate(line):
            when = theme['rhythm'][index]
            if index == len(line) - 1 and phrase_index in (3, 7):
                when = min(when, meter * .60)
            note(bar, when, theme['root'] + interval - (12 if bridge else 0),
                 (.30 if index == 0 else .27) * density, pan=-.045)
        # Phrase answers and occasional soft octave harmonics create development.
        if (12 <= bar < 20 or 36 <= bar < 44) and phrase_index in (1, 3, 5):
            note(bar, meter - .35, theme['root'] + line[-1] + 12, .095, 'muted', .22)
        if 20 <= bar < 28 and phrase_index % 2 == 0:
            note(bar, meter - .45, theme['root'] + 7, .10, 'muted', .18)
        if theme['percussion'] and not bridge:
            add(bar * bar_time, tap(23, True), theme['percussion'], -.18)
            add(bar * bar_time + meter * .5 * beat, tap(51), theme['percussion'] * .7, .20)

    # Short wooden-room reflections, wrapped so the score can repeat continuously.
    dry_left, dry_right = left[:], right[:]
    for delay, level in [(.043,.10),(.097,.065),(.181,.035)]:
        shift = round(delay * RATE)
        for i in range(count):
            j = (i - shift) % count
            left[i] += dry_right[j] * level
            right[i] += dry_left[j] * level
    peak = max(max(map(abs, left)), max(map(abs, right)))
    rms = math.sqrt((sum(v*v for v in left) + sum(v*v for v in right)) / (count * 2))
    gain = min(.11 / rms, .68 / peak)
    # A tiny boundary taper guarantees a click-free loop without a long fade gap.
    edge = round(.006 * RATE)
    for i in range(edge):
        fade = math.sin((i / edge) * math.pi / 2) ** 2
        for channel in (left, right):
            channel[i] *= fade
            channel[-1-i] *= fade
    pcm = array.array('h')
    for l, r in zip(left, right):
        pcm.extend((round(l * gain * 32767), round(r * gain * 32767)))
    assert max(map(abs, pcm)) < 32767
    assert pcm[0] == pcm[1] == pcm[-1] == pcm[-2] == 0
    path = DEST / (theme['file'] + '.wav')
    with wave.open(str(path), 'wb') as output:
        output.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(pcm.tobytes())
    result = {**theme, 'seconds': round(count / RATE, 3), 'bars':48,
              'sections': 'intro 4 / A 8 / A variation 8 / B 8 / bridge 8 / return 8 / coda 4',
              'peak':round(peak*gain,4), 'rms':round(rms*gain,4), 'notes':len(events),
              'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    (DEST / (theme['file'] + '.score.json')).write_text(json.dumps(events, indent=2))
    print(f"{theme['title']}: {result['seconds']:.1f}s, {len(events)} notes, peak {result['peak']}", flush=True)
    return result


if __name__ == '__main__':
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = [compose(theme, index) for index, theme in enumerate(THEMES)]
    (DEST / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
