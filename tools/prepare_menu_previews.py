"""Make equally quiet menu auditions while preserving each generated performance."""
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1] / 'work/kyrgyz-menu-rework/quiet'


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def measure(path):
    result = run(['ffmpeg', '-hide_banner', '-nostats', '-i', str(path),
                  '-af', 'loudnorm=I=-25:TP=-6:LRA=7:print_format=json',
                  '-f', 'null', '-'])
    return json.loads(re.findall(r'\{[^{}]+\}', result.stderr)[-1])


sources = sorted(ROOT.glob('*.aac'))
if not sources:
    raise SystemExit(f'No source AAC files in {ROOT}; restore local audition sources first.')

records = []
for source in sources:
    info = json.loads(run(['ffprobe', '-v', 'error', '-show_format',
                          '-show_streams', '-of', 'json', str(source)]).stdout)
    duration = float(info['format']['duration'])
    before = measure(source)
    # Constant gain avoids pumping or changing the phrasing/dynamic contour.
    gain = min(-25 - float(before['input_i']), -6 - float(before['input_tp']))
    output = source.with_suffix('.mp3')
    run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-af',
         f'volume={gain:.3f}dB,afade=t=in:d=0.8,afade=t=out:st={duration-4:.3f}:d=4',
         '-ar', '48000', '-c:a', 'libmp3lame', '-b:a', '192k', str(output)])
    after = measure(output)
    record = {'file': output.name, 'source': source.name,
              'duration_seconds': duration, 'gain_db': round(gain, 3),
              'integrated_lufs': float(after['input_i']),
              'true_peak_dbtp': float(after['input_tp']),
              'source_lufs': float(before['input_i'])}
    records.append(record)
    print(json.dumps(record), flush=True)
(ROOT / 'validation.json').write_text(json.dumps(records, indent=2) + '\n')
