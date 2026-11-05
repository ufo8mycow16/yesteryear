#!/usr/bin/env python3
"""Yesteryear's background sounds, made from scratch (no recordings): seamless loops for each place and the
Guardian's swell. Writes assets/audio/amb/*.wav (22.05 kHz mono, 16-bit).

    python3 tools/yesteryear/make_ambience.py
"""
import os
import wave

import numpy as np

SR = 22050
LOOP = 24.0          # seconds in each loop
XF = 2.0             # crossfade that makes the loop seamless
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "amb")
rng = np.random.default_rng(1966)


def smooth_noise(n, rate_hz, lo=0.0, hi=1.0):
    """A slowly wandering value between lo and hi (gusts, swells)."""
    pts = int(n / SR * rate_hz) + 4
    ctrl = rng.random(pts)
    x = np.linspace(0, pts - 3, n)
    i = np.floor(x).astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    v = ctrl[i] * (1 - f) + ctrl[i + 1] * f
    return lo + (hi - lo) * v


def lowpass(sig, cutoff):
    """One-pole low-pass; cutoff may be an array (a moving filter, for wind)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), sig.shape)
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.empty_like(sig)
    y = 0.0
    for k in range(len(sig)):
        y = (1 - a[k]) * sig[k] + a[k] * y
        out[k] = y
    return out


def wind(n, strength=1.0, brightness=1.0, gusts=0.12):
    w = rng.standard_normal(n)
    cut = smooth_noise(n, gusts * 3, 180 * brightness, 900 * brightness)
    s = lowpass(w, cut)
    s = lowpass(s, 2500)
    env = smooth_noise(n, gusts, 0.35, 1.0) ** 1.5
    s = s * env
    return s / (np.abs(s).max() + 1e-9) * strength


def hum(n):
    t = np.arange(n) / SR
    base = 0.0
    for f, a in [(55, 1.0), (110, 0.45), (165, 0.18), (220, 0.12), (82.5, 0.25)]:
        base = base + a * np.sin(2 * np.pi * f * t + rng.random() * 6.28)
    wob = 1.0 + 0.04 * np.sin(2 * np.pi * 0.21 * t)
    hiss = lowpass(rng.standard_normal(n), 1600) * 0.6
    s = base * wob + hiss
    return s / np.abs(s).max()


def crickets(n, density=0.6):
    """Night insects: short trills of a high tone, scattered, a few voices."""
    out = np.zeros(n)
    t = np.arange(n) / SR
    for voice in range(4):
        f = 3800 + voice * 450 + rng.random() * 200
        tone = np.sin(2 * np.pi * f * t)
        pulse = (np.sin(2 * np.pi * (28 + voice * 3) * t) > 0.2).astype(float)
        gate = np.zeros(n)
        pos = rng.random() * 2.0
        while pos < n / SR:
            ln = 0.4 + rng.random() * 0.9
            a, b = int(pos * SR), int(min(pos + ln, n / SR) * SR)
            ramp = np.minimum(1, np.minimum(np.arange(b - a), np.arange(b - a)[::-1]) / (0.03 * SR))
            gate[a:b] = ramp
            pos += ln + (0.6 + rng.random() * 2.5) / density
        out += tone * pulse * gate * (0.5 + 0.5 * rng.random())
    out = lowpass(out, 6000)
    return out / (np.abs(out).max() + 1e-9)


def chimes(n, count=5):
    """Distant soft chimes for the city: a few bell tones decaying, far apart."""
    out = np.zeros(n)
    for _ in range(count):
        at = int(rng.random() * (n - SR * 4))
        f = rng.choice([523.25, 659.25, 783.99, 880.0, 1046.5])
        k = np.arange(int(SR * 4)) / SR
        tone = (np.sin(2 * np.pi * f * k) + 0.4 * np.sin(2 * np.pi * f * 2.76 * k)) * np.exp(-k * 1.4)
        out[at:at + len(tone)] += tone * (0.4 + 0.6 * rng.random())
    return out / (np.abs(out).max() + 1e-9)


def loopify(s):
    """Fold the extra XF seconds at the end over the start so the loop has no seam."""
    xf = int(XF * SR)
    body = s[:-xf].copy()
    tail = s[-xf:]
    ramp = np.linspace(0, 1, xf)
    body[:xf] = body[:xf] * ramp + tail * (1 - ramp)
    return body


def save(name, s, peak=0.6):
    os.makedirs(OUT, exist_ok=True)
    s = s / (np.abs(s).max() + 1e-9) * peak
    data = (np.clip(s, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, round(len(s) / SR, 1), "s")


def main():
    n = int((LOOP + XF) * SR)
    save("amb_ship", loopify(hum(n)), 0.5)
    save("amb_guardian", loopify(wind(n, 1.0, 0.8) + 0.25 * hum(n) * smooth_noise(n, 0.08, 0.3, 1.0)), 0.55)
    save("amb_guardian_night", loopify(wind(n, 1.0, 0.6, 0.08) + 0.12 * crickets(n, 0.35)), 0.5)
    save("amb_city", loopify(wind(n, 0.7, 0.9, 0.1) + 0.12 * chimes(n, 4)), 0.45)
    save("amb_desert_night", loopify(wind(n, 1.0, 0.7, 0.15) + 0.22 * crickets(n, 0.7)), 0.55)
    save("amb_desert_dawn", loopify(wind(n, 1.0, 1.1, 0.06)), 0.4)
    # the Guardian's swell when the doorway lights: a rising shimmer, 3 seconds (one-shot)
    m = int(3.2 * SR)
    t = np.arange(m) / SR
    env = np.sin(np.pi * np.minimum(t / 3.2, 1.0)) ** 1.5
    tone = sum(np.sin(2 * np.pi * f * (1 + 0.15 * t / 3.2) * t) * a for f, a in [(110, 1), (220, 0.6), (330, 0.4), (440, 0.25), (660, 0.15)])
    shimmer = lowpass(rng.standard_normal(m), 3000) * (0.4 + 0.6 * t / 3.2)
    save("guardian_swell", (tone + shimmer * 0.6) * env, 0.7)


if __name__ == "__main__":
    main()
