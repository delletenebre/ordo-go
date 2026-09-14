"""Original procedural score and foley. Standard library only; no samples/downloads.
The plucked timbre is a stylized string model inspired by komuz, not a recording.
Run from anywhere: python3 tools/generate_audio.py
"""
from pathlib import Path
import array, math, random, wave
RATE=24000
DEST=Path(__file__).resolve().parents[1]/'assets/audio'
DEST.mkdir(exist_ok=True)
rng=random.Random(71423)
def save(name,mono,gain=.85,loop=False):
    peak=max(.001,max(map(abs,mono)));scale=min(gain/peak,1.8)
    data=array.array('h')
    for i,v in enumerate(mono):
        # Quiet early reflections: coherent stereo without a hard pan.
        j=(i-733)%len(mono) if loop else max(0,i-733)
        k=(i-1091)%len(mono) if loop else max(0,i-1091)
        left=(v*.86+mono[j]*.14)*scale;right=(v*.86+mono[k]*.14)*scale
        data.extend([int(max(-1,min(1,left))*32760),int(max(-1,min(1,right))*32760)])
    with wave.open(str(DEST/(name+'.wav')),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data.tobytes())
def pluck(midi,length=3.0):
    freq=440*2**((midi-69)/12);n=max(3,round(RATE/freq));line=[rng.uniform(-1,1) for _ in range(n)]
    out=array.array('f');prev=0.0
    for i in range(int(RATE*length)):
        k=i%n;v=line[k];line[k]=.996*(v+line[(k+1)%n])*.5
        # Low-pass body; gradual attack removes the synthetic click.
        prev=.70*prev+.30*v;t=i/RATE
        out.append(prev*min(1,t/.007)*math.exp(-t/2.2))
    return out
notes={m:pluck(m,4.0) for m in [38,45,50,52,54,57,59,62,64,66]}
def add(buf,onset,note,velocity,wrap=False):
    offset=int(onset*RATE)
    for j,v in enumerate(note):
        k=offset+j
        if wrap:buf[k%len(buf)]+=v*velocity
        elif 0<=k<len(buf):buf[k]+=v*velocity
def music(name,bars,soft=False):
    length=bars*4.0;buf=array.array('f',[0])*int(length*RATE)
    phrases=[[(0,54),(1.5,57),(2.5,59)],[(0.5,57),(2,54),(3,52)],[(0,50),(1,54),(3,57)],[(0.5,54),(2,52),(3,50)]]
    for bar in range(bars):
        root=38 if bar%4<2 else 45
        add(buf,bar*4,notes[root],.20,True)
        if bar%2==0:add(buf,bar*4+2.25,notes[50],.10,True)
        for beat,m in phrases[bar%4]:
            if soft and bar%4==3 and beat==3:continue
            add(buf,bar*4+beat+rng.uniform(-.025,.025),notes[m],rng.uniform(.30,.40) if not soft else rng.uniform(.22,.31),True)
    # A handful of decaying room reflections, wrapped for a seamless loop.
    dry=buf[:]
    for delay,amount in [(.071,.10),(.139,.07),(.283,.05)]:
        shift=int(delay*RATE)
        for i in range(len(buf)):buf[i]+=dry[(i-shift)%len(buf)]*amount
    save(name,buf,.56,True)
music('menu',16);music('interlude',8,True)
def tone(name,kind,length=.5):
    b=array.array('f',[0])*int(length*RATE);filtered=0.0
    for i in range(len(b)):
        t=i/RATE;x=t/length;noise=rng.uniform(-1,1);filtered=.90*filtered+.10*noise
        env=min(1,t/.006)*(1-x)**2
        if kind=='impact':v=math.sin(math.tau*(105*t-58*t*t))*.60+filtered*.7
        elif kind=='heavy':v=math.sin(math.tau*(64*t-20*t*t))*.70+filtered*.9
        elif kind=='whoosh':v=filtered*2.8*math.sin(math.pi*x)
        elif kind=='bell':v=(math.sin(math.tau*587.33*t)+.35*math.sin(math.tau*880*t)+.12*math.sin(math.tau*1470*t))*.34
        elif kind=='ice':v=(math.sin(math.tau*1174*t)+math.sin(math.tau*1760*t)*.35)*.27
        elif kind=='vowel':v=(math.sin(math.tau*(150*t+25*t*t)+1.5*math.sin(math.tau*310*t)))*.42
        elif kind=='laugh':v=math.sin(math.tau*(230*t+30*t*t)+.8*math.sin(math.tau*460*t))*.5*max(0,math.sin(math.tau*6*t))**2
        elif kind=='anger':v=math.sin(math.tau*87*t+1.4*math.sin(math.tau*170*t))*.4
        else:v=filtered*.4+math.sin(math.tau*440*t)*.12
        b[i]=v*env
    save(name,b,.70)
for n,k,l in [('impact','impact',.28),('heavy','heavy',.65),('launch','whoosh',.35),('death','whoosh',.65),('hurt','vowel',.30),('shield','bell',.65),('ice','ice',.55),('wind','whoosh',.8),('boss','heavy',1.0),('joy','vowel',.30),('mock','laugh',.70),('anger','anger',.28),('surprise','whoosh',.19),('ui','click',.06)]:tone(n,k,l)
# Preserve the selected ready cue when regenerating the full audio library.
from generate_ready_variants import generate_ready
generate_ready(DEST)
for name,sequence in {'cancel':[54,50],'pickup':[54,57,62],'snare':[45,57],'heal':[50,57],'clear':[50,54,57,62],'victory':[50,54,57,62,66,62],'lose':[54,52,50,38],'ability':[54,59]}.items():
    buf=array.array('f',[0])*int(RATE*(1.3+len(sequence)*.13))
    for i,m in enumerate(sequence):add(buf,i*.13,notes[m],.55)
    save(name,buf,.70)
for name,length,gain in [('fire',8,.35),('slide',2,.30)]:
    buf=array.array('f',[0])*int(length*RATE);filtered=0.0
    for i in range(len(buf)):
        filtered=.985*filtered+.015*rng.uniform(-1,1)
        buf[i]=filtered
    if name=='fire':
        for j in range(38):
            pos=rng.randrange(len(buf));size=rng.randrange(80,380)
            for i in range(size):buf[(pos+i)%len(buf)]+=rng.uniform(-.035,.035)*(1-i/size)**2
    # Crossfade endpoints without changing duration.
    edge=1200
    for i in range(edge):
        value=buf[i]*(i/edge)+buf[-edge+i]*(1-i/edge);buf[i]=value;buf[-edge+i]=value
    save(name,buf,gain,True)
print('Generated',len(list(DEST.glob('*.wav'))),'original WAV files in',DEST)
