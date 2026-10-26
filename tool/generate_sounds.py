"""Generates the three "Suara tenang" loops (rain, forest, waves).

The sounds are synthesized from noise and simple tones, so the team owns
them outright (released as CC0, see ASSETS.md). Every layer is built to be
periodic over the loop length, so the files loop with no seam or click.

Usage:  python tool/generate_sounds.py            (writes assets/audio/*.wav)
Needs:  numpy, scipy (wav writer)
"""
import os

import numpy as np
from scipy.io import wavfile

SR = 32000          # sample rate (Hz); mono keeps files small
SECONDS = 40        # loop length
N = SR * SECONDS
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(2026)
t = np.arange(N) / SR
freqs = np.fft.rfftfreq(N, 1 / SR)


def shaped_noise(shape):
    """White noise filtered in the frequency domain (periodic over N)."""
    spectrum = np.fft.rfft(rng.standard_normal(N)) * shape
    x = np.fft.irfft(spectrum, N)
    return x / (np.std(x) + 1e-12)


def band(lo, hi, slope=0.0):
    """Smooth band-pass shape with an optional 1/f^slope tilt."""
    f = np.maximum(freqs, 1.0)
    shape = f ** (-slope)
    shape *= 1 / (1 + (lo / f) ** 4)
    shape *= 1 / (1 + (f / hi) ** 4)
    return shape


def lfo(period_s, depth, phase=0.0):
    """Slow loudness wobble whose period divides the loop length."""
    cycles = max(1, round(SECONDS / period_s))
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * cycles * t / SECONDS + phase))


def add_event(dest, event, start):
    """Adds [event] at [start], wrapping around the loop end."""
    idx = (start + np.arange(len(event))) % N
    np.add.at(dest, idx, event)


def tilt(x, lo, hi):
    """Final tone shaping (periodic, so the loop stays seamless)."""
    return np.fft.irfft(np.fft.rfft(x) * band(lo, hi), N)


def finish(x, rms_db=-21.0, peak=0.89):
    x = x - np.mean(x)
    x *= 10 ** (rms_db / 20) / (np.sqrt(np.mean(x ** 2)) + 1e-12)
    over = np.max(np.abs(x))
    if over > peak:  # gentle soft-clip instead of hard limiting
        x = np.tanh(x / peak * 1.2) * peak / np.tanh(1.2)
    return x


def rain():
    bed = shaped_noise(band(400, 9000, slope=0.5)) * lfo(10, 0.12)
    bed += 0.45 * shaped_noise(band(120, 900, slope=1.0)) * lfo(20, 0.2, 1)
    drops = np.zeros(N)
    for _ in range(SECONDS * 38):  # light patter
        length = int(SR * rng.uniform(0.004, 0.012))
        env = np.exp(-np.arange(length) / (length / 4))
        tick = rng.standard_normal(length) * env * rng.uniform(0.2, 1.0)
        add_event(drops, tick, int(rng.integers(N)))
    for _ in range(SECONDS * 3):  # a few heavier drops on leaves/roof
        length = int(SR * 0.05)
        k = np.arange(length) / SR
        f0 = rng.uniform(900, 1800)
        plop = np.sin(2 * np.pi * (f0 * k - 3000 * k ** 2)) * np.exp(-k / 0.012)
        add_event(drops, plop * rng.uniform(0.4, 0.9), int(rng.integers(N)))
    drops = tilt(drops, 600, 7000)
    drops /= np.std(drops) + 1e-12
    return finish(tilt(bed + 0.35 * drops, 60, 8000))


def bird(kind):
    """One short bird phrase."""
    if kind == 0:   # two-note whistle
        notes = [(3300, 2900, 0.16), (2700, 2500, 0.22)]
    elif kind == 1:  # quick trill
        notes = [(4200, 3800, 0.035)] * int(rng.integers(6, 11))
    else:           # rising call
        notes = [(2200, 3600, 0.28)]
    out = []
    for f_start, f_end, dur in notes:
        n = int(SR * dur)
        k = np.arange(n) / SR
        f = np.linspace(f_start, f_end, n) * (1 + 0.01 * np.sin(2 * np.pi * 28 * k))
        phase = 2 * np.pi * np.cumsum(f) / SR
        out.append(np.sin(phase) * np.hanning(n))
        out.append(np.zeros(int(SR * (0.03 if kind == 1 else 0.09))))
    call = np.concatenate(out)
    echo = np.zeros(len(call) + int(SR * 0.14))
    echo[: len(call)] += call
    echo[int(SR * 0.14):] += 0.22 * call
    return echo


def forest():
    wind = shaped_noise(band(40, 700, slope=1.2))
    swell = lfo(SECONDS, 0.45) * lfo(SECONDS / 3, 0.25, 2.0)
    leaves = shaped_noise(band(1800, 7000, slope=0.3)) * swell ** 2
    birds = np.zeros(N)
    for i in range(14):
        call = bird(i % 3) * rng.uniform(0.25, 0.6)
        start = int((i + rng.uniform(0.1, 0.9)) * N / 14)
        add_event(birds, call, start)
    x = 0.9 * wind * swell + 0.22 * leaves + 0.55 * birds / (np.max(np.abs(birds)) + 1e-12) * 3
    return finish(tilt(x, 40, 9000), rms_db=-22.0)


def waves():
    cycles = 5  # five waves per 40 s loop (one every 8 s)
    phase = (t * cycles / SECONDS) % 1.0
    rise = np.clip(phase / 0.35, 0, 1) ** 2
    fall = np.exp(-np.clip(phase - 0.35, 0, None) / 0.22)
    env = np.where(phase < 0.35, rise, fall)
    env = 0.25 + 0.75 * np.convolve(
        np.concatenate([env[-800:], env, env[:800]]), np.hanning(1601) / np.hanning(1601).sum(), "same"
    )[800:-800]
    body = shaped_noise(band(60, 1500, slope=1.1)) * env
    foam = shaped_noise(band(1500, 9000, slope=0.4)) * env ** 3
    rumble = 0.5 * shaped_noise(band(25, 180, slope=1.0))
    return finish(tilt(body + 0.5 * foam + rumble, 30, 9000))


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    wavfile.write(path, SR, (x * 32767).astype(np.int16))
    print(f"{path}: {os.path.getsize(path) / 1e6:.1f} MB")


if __name__ == "__main__":
    save("rain.wav", rain())
    save("forest.wav", forest())
    save("waves.wav", waves())
