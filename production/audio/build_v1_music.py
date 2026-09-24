from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Spritesheetweapon-master" / "05-成品项目" / "色彩勇者Demo"
OUTPUT = PROJECT / "assets" / "audio" / "v1"
SAMPLE_RATE = 22_050


TRACKS = {
    "chapter1_gray_border.wav": {
        "bpm": 92,
        "seed": 1101,
        "chords": [[50, 53, 57, 60], [48, 52, 55, 60], [46, 50, 53, 57], [48, 52, 55, 59]],
        "scale": [50, 52, 53, 55, 57, 59, 60, 62],
        "lead": [0, 2, 4, 2, 5, 4, 2, 1, 0, 3, 5, 4, 2, 1, 0, 2],
        "pad": 0.105,
        "pulse": 0.055,
        "brightness": 0.45,
    },
    "chapter2_mirror_lake.wav": {
        "bpm": 106,
        "seed": 2202,
        "chords": [[52, 55, 59, 64], [48, 52, 55, 59], [50, 54, 57, 62], [47, 50, 54, 59]],
        "scale": [52, 54, 55, 57, 59, 60, 62, 64],
        "lead": [0, 4, 7, 4, 2, 5, 7, 5, 1, 4, 6, 4, 2, 3, 5, 7],
        "pad": 0.09,
        "pulse": 0.07,
        "brightness": 0.72,
    },
    "chapter3_colorless_court.wav": {
        "bpm": 114,
        "seed": 3303,
        "chords": [[49, 52, 56, 61], [46, 49, 53, 58], [45, 49, 52, 57], [47, 51, 54, 59]],
        "scale": [49, 50, 52, 54, 56, 57, 59, 61],
        "lead": [0, 1, 4, 3, 6, 4, 2, 1, 0, 5, 3, 2, 7, 6, 4, 1],
        "pad": 0.12,
        "pulse": 0.085,
        "brightness": 0.32,
    },
}


def midi_frequency(note: int) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def envelope(length: int, attack: float, release: float) -> np.ndarray:
    result = np.ones(length, dtype=np.float64)
    attack_samples = min(int(attack * SAMPLE_RATE), length // 2)
    release_samples = min(int(release * SAMPLE_RATE), length // 2)
    if attack_samples > 0:
        result[:attack_samples] = np.linspace(0.0, 1.0, attack_samples, endpoint=False)
    if release_samples > 0:
        result[-release_samples:] = np.linspace(1.0, 0.0, release_samples, endpoint=True)
    return result


def oscillator(kind: str, phase: np.ndarray, brightness: float) -> np.ndarray:
    fundamental = np.sin(phase)
    if kind == "triangle":
        return (2.0 / math.pi) * np.arcsin(fundamental)
    if kind == "bell":
        return fundamental + brightness * 0.42 * np.sin(phase * 2.01) + brightness * 0.2 * np.sin(phase * 3.98)
    if kind == "reed":
        return 0.72 * fundamental + 0.2 * np.sin(phase * 2.0) + brightness * 0.1 * np.sin(phase * 3.0)
    return fundamental


def add_tone(
    track: np.ndarray,
    start: float,
    duration: float,
    frequency: float,
    volume: float,
    pan: float,
    kind: str,
    brightness: float,
    attack: float = 0.01,
    release: float = 0.08,
) -> None:
    first = max(int(start * SAMPLE_RATE), 0)
    count = min(int(duration * SAMPLE_RATE), track.shape[0] - first)
    if count <= 1:
        return
    time = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    phase = 2.0 * math.pi * frequency * time
    signal = oscillator(kind, phase, brightness) * envelope(count, attack, release) * volume
    left = math.sqrt((1.0 - pan) * 0.5)
    right = math.sqrt((1.0 + pan) * 0.5)
    track[first:first + count, 0] += signal * left
    track[first:first + count, 1] += signal * right


def add_drum(track: np.ndarray, start: float, kind: str, volume: float, rng: np.random.Generator) -> None:
    first = int(start * SAMPLE_RATE)
    duration = 0.23 if kind == "kick" else 0.16
    count = min(int(duration * SAMPLE_RATE), track.shape[0] - first)
    if count <= 1:
        return
    time = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    if kind == "kick":
        phase = 2.0 * math.pi * (76.0 * time - 34.0 * time * time)
        signal = np.sin(phase) * np.exp(-time * 17.0)
    elif kind == "snare":
        noise = rng.normal(0.0, 1.0, count)
        signal = (noise - np.concatenate(([0.0], noise[:-1])) * 0.72) * np.exp(-time * 24.0)
    else:
        noise = rng.normal(0.0, 1.0, count)
        signal = (noise - np.concatenate(([0.0], noise[:-1]))) * np.exp(-time * 56.0)
    track[first:first + count, 0] += signal * volume * 0.71
    track[first:first + count, 1] += signal * volume * 0.71


def add_reverb(track: np.ndarray) -> None:
    dry = track.copy()
    for delay_seconds, gain, cross in [(0.17, 0.13, False), (0.29, 0.09, True), (0.43, 0.055, False)]:
        delay = int(delay_seconds * SAMPLE_RATE)
        if cross:
            track[delay:, 0] += dry[:-delay, 1] * gain
            track[delay:, 1] += dry[:-delay, 0] * gain
        else:
            track[delay:] += dry[:-delay] * gain


def build_track(config: dict) -> np.ndarray:
    bpm = config["bpm"]
    beat = 60.0 / bpm
    bar = beat * 4.0
    bars = 16
    duration = bars * bar
    rng = np.random.default_rng(config["seed"])
    track = np.zeros((int(duration * SAMPLE_RATE), 2), dtype=np.float64)
    chords = config["chords"]
    scale = config["scale"]

    for bar_index in range(bars):
        chord = chords[bar_index % len(chords)]
        bar_start = bar_index * bar
        for voice_index, note in enumerate(chord):
            add_tone(
                track,
                bar_start,
                bar * 1.01,
                midi_frequency(note),
                config["pad"],
                -0.5 + voice_index * 0.34,
                "reed",
                config["brightness"],
                attack=0.24,
                release=0.3,
            )

        root = chord[0] - 12
        for beat_index in range(4):
            bass_note = root if beat_index != 2 else root + 7
            add_tone(track, bar_start + beat_index * beat, beat * 0.84, midi_frequency(bass_note), 0.12, -0.08, "triangle", 0.2, release=0.12)
            add_drum(track, bar_start + beat_index * beat, "kick", 0.095, rng)
            if beat_index in [1, 3]:
                add_drum(track, bar_start + beat_index * beat, "snare", 0.048, rng)
        for eighth in range(8):
            add_drum(track, bar_start + eighth * beat * 0.5, "hat", 0.017, rng)
            arp_note = chord[eighth % len(chord)] + (12 if eighth >= 4 else 0)
            add_tone(
                track,
                bar_start + eighth * beat * 0.5,
                beat * 0.42,
                midi_frequency(arp_note),
                config["pulse"],
                0.45 if eighth % 2 == 0 else -0.35,
                "bell",
                config["brightness"],
                release=beat * 0.26,
            )

        melody_offset = (bar_index * 2) % len(config["lead"])
        for phrase_note in range(2):
            scale_index = config["lead"][(melody_offset + phrase_note) % len(config["lead"])]
            note = scale[scale_index % len(scale)] + 12
            add_tone(
                track,
                bar_start + phrase_note * beat * 2.0,
                beat * 1.55,
                midi_frequency(note),
                0.085,
                -0.2 if phrase_note == 0 else 0.22,
                "reed",
                config["brightness"],
                attack=0.035,
                release=0.22,
            )

    add_reverb(track)
    fade = int(0.025 * SAMPLE_RATE)
    track[:fade] *= np.linspace(0.0, 1.0, fade)[:, None]
    track[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    peak = float(np.max(np.abs(track)))
    if peak > 0.0:
        track *= 0.86 / peak
    return track


def write_wave(path: Path, samples: np.ndarray) -> None:
    pcm = np.clip(samples * 32767.0, -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename, config in TRACKS.items():
        output_path = OUTPUT / filename
        write_wave(output_path, build_track(config))
        print(output_path)


if __name__ == "__main__":
    main()
