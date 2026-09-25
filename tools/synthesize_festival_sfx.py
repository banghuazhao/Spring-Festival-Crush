"""Procedurally synthesizes the festival sound effects (no samples, no licensing).

Usage: python3 tools/synthesize_festival_sfx.py SpringFestivalCrush/Sounds  (needs numpy + scipy)
The seed is fixed, so rerunning reproduces the committed files.
"""
import numpy as np, wave, os, sys
from scipy.signal import butter, lfilter

SR = 22050
rng = np.random.default_rng(2027)
OUT = sys.argv[1]

def write(name, x, peak=0.7):
    x = np.asarray(x, dtype=np.float64)
    fade = min(len(x), int(0.03 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())

def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return lfilter(b, a, x)

def lp(x, hi, order=2):
    b, a = butter(order, hi / (SR / 2), btype='low')
    return lfilter(b, a, x)

def hp(x, lo, order=2):
    b, a = butter(order, lo / (SR / 2), btype='high')
    return lfilter(b, a, x)

def reverb(x, amount=0.25, delays=(0.029, 0.037, 0.043, 0.051), fb=0.55):
    out = np.copy(x)
    for d in delays:
        n = int(d * SR)
        y = np.zeros(len(x) + n * 8)
        y[:len(x)] += x
        for i in range(n, len(y)):
            y[i] += fb * y[i - n]
        out = out + amount / len(delays) * y[:len(x)]
    return out

def pluck(freq, dur=0.9, bright=0.6, bend=0.012):
    """Karplus-Strong string with a guzheng-like press bend and a soft body resonance."""
    n = int(dur * SR)
    L = max(2, int(round(SR / freq)))
    excite = rng.uniform(-1, 1, L)
    excite = lp(excite, min(SR / 2 - 200, freq * (4 + 10 * bright)))
    excite -= excite.mean()
    y = np.zeros(n + L + 1)
    y[:L] = excite
    decay = 0.9965
    for i in range(L, len(y) - 1):
        y[i] = decay * 0.5 * (y[i - L] + y[i - L + 1])
    out = y[L:L + n]
    t = np.arange(n) / SR
    warp = t * (1 + bend * np.sin(np.minimum(t, 0.35) / 0.35 * np.pi / 2))
    out = np.interp(warp * SR, np.arange(n), out, right=0)
    body = bp(out, freq * 0.9, min(SR / 2 - 200, freq * 6))
    x = 0.7 * out + 0.5 * body
    env = np.exp(-t * 3.2)
    attack = np.minimum(1, t / 0.003)
    return hp(reverb(x * env * attack, 0.35), 70)

notes = {  # D major pentatonic, the guzheng's home tuning (宫商角徵羽)
    1: 293.66, 2: 329.63, 3: 369.99, 4: 440.00,
    5: 493.88, 6: 587.33, 7: 659.26, 8: 739.99,
}
for k, f in notes.items():
    write(f"Pluck{k}.wav", pluck(f), peak=0.65)

# Glissando: a quick upward sweep across the strings (Ruyi Swap, envelopes).
g = np.zeros(int(1.1 * SR))
for i, f in enumerate([587.33, 659.26, 739.99, 880.0, 987.77, 1174.66]):
    p = pluck(f, dur=0.8, bright=0.8)
    s = int(i * 0.045 * SR)
    g[s:s + len(p)] += p[:len(g) - s] * (0.7 + 0.06 * i)
write("Glissando.wav", g, peak=0.6)

# Gong: inharmonic partials with the characteristic upward shimmer, plus mallet thump.
dur = 2.2
t = np.arange(int(dur * SR)) / SR
f0 = 98
gong = np.zeros_like(t)
for ratio, amp, dec in [(1, 1.0, 1.1), (1.52, 0.7, 1.4), (2.03, 0.55, 1.8), (2.74, 0.45, 2.2),
                        (3.41, 0.3, 2.6), (4.13, 0.22, 3.1), (5.2, 0.15, 3.8)]:
    glide = 1 + 0.018 * (1 - np.exp(-t * 2.5))
    phase = 2 * np.pi * f0 * ratio * np.cumsum(glide) / SR
    gong += amp * np.sin(phase + rng.uniform(0, 6.28)) * np.exp(-t * dec)
swell = 0.6 + 0.4 * np.minimum(1, t / 0.25)
thump = lp(rng.uniform(-1, 1, len(t)), 400) * np.exp(-t * 40) * 2.5
write("Gong.wav", reverb(gong * swell + thump, 0.4), peak=0.75)

# Tanggu drum hit for guardian damage: pitch-dropping membrane plus a skin click.
dur = 0.55
t = np.arange(int(dur * SR)) / SR
freq = 70 + 60 * np.exp(-t * 30)
drum = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 7.5)
drum += 0.35 * np.sin(2 * np.pi * np.cumsum(freq * 1.6) / SR) * np.exp(-t * 11)
click = bp(rng.uniform(-1, 1, len(t)), 1200, 5000) * np.exp(-t * 90) * 0.8
write("Drum.wav", reverb(drum + click, 0.2), peak=0.8)

# Firecracker string: irregular sharp cracks with a short tail.
dur = 1.0
x = np.zeros(int(dur * SR))
pos = 0.0
while pos < 0.78:
    s = int(pos * SR)
    n = int(rng.uniform(0.004, 0.012) * SR)
    burst = rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / (n / 4))
    x[s:s + n] += burst * rng.uniform(0.45, 1.0)
    pos += rng.uniform(0.018, 0.065)
x = hp(x, 700) + 0.3 * bp(x, 150, 700)
write("Firecracker.wav", reverb(x, 0.3), peak=0.7)

# Firework: a rising whistle, a soft boom, then glittering crackle.
dur = 1.6
t = np.arange(int(dur * SR)) / SR
whistle_f = 900 + 1500 * np.minimum(1, t / 0.45)
whistle = 0.18 * np.sin(2 * np.pi * np.cumsum(whistle_f) / SR) * (t < 0.45) * np.minimum(1, t / 0.05)
boom_t = np.maximum(0, t - 0.45)
boom = lp(rng.uniform(-1, 1, len(t)), 260) * np.exp(-boom_t * 9) * (t >= 0.45) * 1.8
glitter = np.zeros_like(t)
for _ in range(40):
    s = int(rng.uniform(0.5, 1.4) * SR)
    n = int(0.004 * SR)
    if s + n < len(t):
        glitter[s:s + n] += rng.uniform(-1, 1, n) * rng.uniform(0.1, 0.4)
glitter = hp(glitter, 2500)
write("Firework.wav", reverb(whistle + boom + glitter, 0.35), peak=0.7)

# Chime: a bright bell arpeggio for opening envelopes and chests.
dur = 1.5
t = np.arange(int(dur * SR)) / SR
chime = np.zeros_like(t)
for i, f in enumerate([1174.66, 1479.98, 1760.0, 2349.32]):
    st = i * 0.07
    tt = np.maximum(0, t - st)
    on = t >= st
    for ratio, amp in [(1, 1), (2.0, 0.35), (2.76, 0.25), (5.4, 0.1)]:
        chime += on * amp * np.sin(2 * np.pi * f * ratio * tt) * np.exp(-tt * (3 + ratio))
write("Chime.wav", reverb(chime, 0.4), peak=0.55)
print("ok")
