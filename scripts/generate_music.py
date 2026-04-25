"""
Procedural chiptune music generator for Mini Games.

Generates two original loopable WAV tracks:
  - home_loop.wav  : friendly arcade menu music (C major, ~110 BPM)
  - game_loop.wav  : energetic action music    (A minor, ~140 BPM)

Original compositions. No samples or copyrighted material used.
"""

import numpy as np
import wave
import struct
import os

SR = 44100  # sample rate

# ---------- Note utilities ----------
NOTE_NAMES = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,
              'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}

def midi(name):
    """e.g. 'A4' -> 69, 'C5' -> 72"""
    if name is None:
        return None
    n = name[:-1]
    octv = int(name[-1])
    return 12 * (octv + 1) + NOTE_NAMES[n]

def freq(m):
    if m is None:
        return 0.0
    return 440.0 * 2.0 ** ((m - 69) / 12.0)

# ---------- Oscillators ----------
def t_axis(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)

def osc_sine(f, dur):
    return np.sin(2 * np.pi * f * t_axis(dur))

def osc_square(f, dur, duty=0.5):
    if f <= 0: return np.zeros(int(SR*dur))
    t = t_axis(dur)
    return np.where((t * f) % 1.0 < duty, 1.0, -1.0)

def osc_tri(f, dur):
    if f <= 0: return np.zeros(int(SR*dur))
    t = t_axis(dur)
    return 2 * np.abs(2 * (t * f - np.floor(t * f + 0.5))) - 1

def osc_saw(f, dur):
    if f <= 0: return np.zeros(int(SR*dur))
    t = t_axis(dur)
    return 2 * (t * f - np.floor(t * f + 0.5))

def noise(dur):
    return np.random.uniform(-1, 1, int(SR * dur))

# ---------- Envelopes ----------
def adsr(n_samples, a=0.01, d=0.08, s=0.6, r=0.05):
    a_n = max(1, int(SR * a))
    d_n = max(1, int(SR * d))
    r_n = max(1, int(SR * r))
    s_n = max(0, n_samples - a_n - d_n - r_n)
    if s_n == 0:
        # short note: scale down release
        total = a_n + d_n + r_n
        scale = n_samples / total
        a_n = max(1, int(a_n * scale))
        d_n = max(1, int(d_n * scale))
        r_n = max(1, n_samples - a_n - d_n)
        s_n = 0
    env = np.concatenate([
        np.linspace(0, 1, a_n),
        np.linspace(1, s, d_n),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    if len(env) > n_samples:
        env = env[:n_samples]
    elif len(env) < n_samples:
        env = np.concatenate([env, np.zeros(n_samples - len(env))])
    return env

def perc_env(n_samples, decay=0.15):
    """Quick percussive envelope."""
    t = np.arange(n_samples) / SR
    return np.exp(-t / decay)

# ---------- Note rendering ----------
def render_note(note, dur, osc='square', vol=0.2, duty=0.5,
                a=0.005, d=0.05, s=0.7, r=0.05, vibrato=0.0):
    """Render a single note. note can be MIDI number or name string. Returns float array."""
    if isinstance(note, str):
        m = midi(note)
    else:
        m = note
    if m is None:
        return np.zeros(int(SR * dur))
    f = freq(m)
    n_samples = int(SR * dur)

    if vibrato > 0:
        # subtle vibrato via FM
        t = t_axis(dur)
        vib = 1.0 + vibrato * np.sin(2 * np.pi * 5.5 * t)
        phase = 2 * np.pi * np.cumsum(f * vib) / SR
        if osc == 'square':
            wave_arr = np.where(np.sin(phase) > (1 - 2*duty), 1.0, -1.0)
        elif osc == 'tri':
            wave_arr = (2 / np.pi) * np.arcsin(np.sin(phase))
        elif osc == 'saw':
            wave_arr = (phase / np.pi) % 2 - 1
        else:
            wave_arr = np.sin(phase)
    else:
        if osc == 'square':
            wave_arr = osc_square(f, dur, duty)
        elif osc == 'tri':
            wave_arr = osc_tri(f, dur)
        elif osc == 'saw':
            wave_arr = osc_saw(f, dur)
        else:
            wave_arr = osc_sine(f, dur)

    env = adsr(n_samples, a, d, s, r)
    return vol * wave_arr * env

def render_kick(dur=0.18, vol=0.55):
    n = int(SR * dur)
    t = np.arange(n) / SR
    # pitch sweep 120Hz -> 45Hz
    f = 120 * np.exp(-t * 12) + 45
    phase = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(phase)
    env = np.exp(-t / 0.10)
    click = np.exp(-t / 0.005) * np.random.uniform(-1, 1, n) * 0.3
    return vol * (body * env + click * env)

def render_hat(dur=0.05, vol=0.18):
    n = int(SR * dur)
    t = np.arange(n) / SR
    n_samp = noise(dur)
    # high-pass-ish via diff
    n_samp = np.diff(n_samp, prepend=0)
    env = np.exp(-t / 0.018)
    return vol * n_samp * env

def render_snare(dur=0.18, vol=0.42):
    n = int(SR * dur)
    t = np.arange(n) / SR
    # tonal body
    body = np.sin(2 * np.pi * 200 * t) * np.exp(-t / 0.04)
    # noise
    ns = noise(dur)
    ns = np.diff(ns, prepend=0)
    env = np.exp(-t / 0.12)
    return vol * (body * 0.35 + ns * env * 0.9)

# ---------- Sequencer ----------
class Track:
    """Accumulates audio onto a buffer at given time offsets."""
    def __init__(self, total_dur):
        self.buf = np.zeros(int(SR * total_dur))

    def place(self, audio, t_start):
        i = int(SR * t_start)
        end = i + len(audio)
        if end > len(self.buf):
            audio = audio[:len(self.buf) - i]
            end = len(self.buf)
        self.buf[i:end] += audio

    def data(self):
        return self.buf

# ---------- Mixing & WAV write ----------
def mix(*tracks):
    out = sum(t.data() for t in tracks)
    # Soft clipping (tanh) to keep sound warm & avoid harsh clipping
    out = np.tanh(out * 0.9)
    # Normalize to ~ -3 dBFS
    peak = np.max(np.abs(out))
    if peak > 0:
        out = out / peak * 0.85
    return out

def write_wav(path, data):
    data = np.clip(data, -1.0, 1.0)
    pcm = (data * 32767).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"Wrote {path}  ({len(data)/SR:.2f}s)")

# ============================================================
# HOME LOOP - friendly arcade menu, C major, 110 BPM
# Chord progression: C - Am - F - G  (8 bars, played twice = 16 bars)
# ============================================================
def make_home_loop():
    BPM = 110
    beat = 60 / BPM           # 0.545s
    bar = 4 * beat            # 2.18s
    bars = 16
    total = bars * bar        # ~34.9 s -> let's do 8 bars instead = ~17.5s

    bars = 8
    total = bars * bar

    melody = Track(total)
    bass = Track(total)
    pad = Track(total)
    arp = Track(total)
    drums = Track(total)

    # Chord progression per bar (root, third, fifth)
    chords = [
        ('C',  ['C3','E3','G3'],  ['C4','E4','G4']),
        ('Am', ['A2','C3','E3'],  ['A3','C4','E4']),
        ('F',  ['F2','A2','C3'],  ['F3','A3','C4']),
        ('G',  ['G2','B2','D3'],  ['G3','B3','D4']),
        ('C',  ['C3','E3','G3'],  ['C4','E4','G4']),
        ('Am', ['A2','C3','E3'],  ['A3','C4','E4']),
        ('F',  ['F2','A2','C3'],  ['F3','A3','C4']),
        ('G',  ['G2','B2','D3'],  ['G3','B3','D4']),
    ]

    # Cheerful melody (over 8 bars). Notes from C major scale, syncopated.
    # Format: (note_name_or_None, start_beat_offset_in_bar, duration_beats)
    melody_phrase = [
        # bar 0 - C
        [('E5', 0.0, 0.5), ('G5', 0.5, 0.5), ('C5', 1.0, 1.0),
         ('E5', 2.0, 0.5), ('D5', 2.5, 0.5), ('C5', 3.0, 1.0)],
        # bar 1 - Am
        [('A4', 0.0, 1.0), ('C5', 1.0, 0.5), ('E5', 1.5, 0.5),
         ('A5', 2.0, 1.0), ('G5', 3.0, 1.0)],
        # bar 2 - F
        [('F5', 0.0, 0.5), ('A5', 0.5, 0.5), ('C5', 1.0, 0.5), ('F5', 1.5, 0.5),
         ('E5', 2.0, 1.0), ('D5', 3.0, 1.0)],
        # bar 3 - G
        [('D5', 0.0, 0.5), ('G5', 0.5, 0.5), ('B4', 1.0, 0.5), ('D5', 1.5, 0.5),
         ('G5', 2.0, 0.5), ('F5', 2.5, 0.5), ('E5', 3.0, 1.0)],
        # bar 4 - C (reprise with variation)
        [('C5', 0.0, 0.5), ('E5', 0.5, 0.5), ('G5', 1.0, 0.5), ('E5', 1.5, 0.5),
         ('C5', 2.0, 0.5), ('G4', 2.5, 0.5), ('E5', 3.0, 1.0)],
        # bar 5 - Am
        [('A4', 0.0, 0.5), ('C5', 0.5, 0.5), ('E5', 1.0, 0.5), ('A5', 1.5, 0.5),
         ('G5', 2.0, 0.5), ('E5', 2.5, 0.5), ('C5', 3.0, 1.0)],
        # bar 6 - F
        [('F5', 0.0, 1.0), ('E5', 1.0, 0.5), ('D5', 1.5, 0.5),
         ('A4', 2.0, 1.0), ('C5', 3.0, 1.0)],
        # bar 7 - G (resolving)
        [('G4', 0.0, 0.5), ('B4', 0.5, 0.5), ('D5', 1.0, 0.5), ('G5', 1.5, 0.5),
         ('F5', 2.0, 0.5), ('D5', 2.5, 0.5), ('G4', 3.0, 1.0)],
    ]

    for bar_i, (chord_name, low_chord, high_chord) in enumerate(chords):
        bar_t = bar_i * bar

        # --- Bass (root + fifth bounce, square wave) ---
        root_note = low_chord[0]
        fifth_note = low_chord[2]
        # rhythm: root - root - fifth - root  (per beat)
        bass_pattern = [(root_note, 0.0, 0.9), (root_note, 1.0, 0.9),
                        (fifth_note, 2.0, 0.9), (root_note, 3.0, 0.9)]
        for n, off, d in bass_pattern:
            bass.place(
                render_note(n, d * beat, osc='tri', vol=0.34,
                            a=0.005, d=0.04, s=0.55, r=0.06),
                bar_t + off * beat)

        # --- Pad / Chord (soft sine triad sustained whole bar) ---
        for n in low_chord:
            pad.place(
                render_note(n, bar * 0.95, osc='sine', vol=0.07,
                            a=0.20, d=0.30, s=0.6, r=0.30),
                bar_t)

        # --- Arpeggio (gentle 8th notes, triangle wave) ---
        arp_pattern = high_chord + [high_chord[1]]  # root-3rd-5th-3rd repeating
        for i in range(8):
            n = arp_pattern[i % len(arp_pattern)]
            arp.place(
                render_note(n, beat * 0.45, osc='tri', vol=0.10,
                            a=0.005, d=0.08, s=0.3, r=0.04),
                bar_t + i * 0.5 * beat)

        # --- Melody ---
        for n, off, d in melody_phrase[bar_i]:
            arp_v = render_note(n, d * beat * 0.95, osc='square', duty=0.5,
                                vol=0.26, a=0.006, d=0.06, s=0.7, r=0.05,
                                vibrato=0.003)
            melody.place(arp_v, bar_t + off * beat)

        # --- Soft hat on off-beats for groove ---
        for i in range(8):
            if i % 2 == 1:  # off-beats
                drums.place(render_hat(0.04, vol=0.10), bar_t + i * 0.5 * beat)
        # subtle kick on beats 1 and 3
        drums.place(render_kick(dur=0.16, vol=0.30), bar_t + 0 * beat)
        drums.place(render_kick(dur=0.16, vol=0.25), bar_t + 2 * beat)

    out = mix(melody, bass, pad, arp, drums)
    return out

# ============================================================
# GAME LOOP - energetic action music, A minor, 140 BPM
# Chord progression: Am - F - C - G  (vi-IV-I-V "epic" loop)
# ============================================================
def make_game_loop():
    BPM = 140
    beat = 60 / BPM       # 0.4286s
    bar = 4 * beat        # 1.714s
    bars = 8
    total = bars * bar    # ~13.7s

    lead = Track(total)
    bass = Track(total)
    chord = Track(total)
    drums = Track(total)

    # Per-bar chord (root, third, fifth)
    chords = [
        ('Am', ['A2','C3','E3']),
        ('F',  ['F2','A2','C3']),
        ('C',  ['C3','E3','G3']),
        ('G',  ['G2','B2','D3']),
        ('Am', ['A2','C3','E3']),
        ('F',  ['F2','A2','C3']),
        ('C',  ['C3','E3','G3']),
        ('G',  ['G2','B2','D3']),
    ]

    # Energetic lead melody — A minor pentatonic flavor
    lead_phrase = [
        # bar 0 - Am
        [('A4', 0.0, 0.5), ('C5', 0.5, 0.5), ('E5', 1.0, 0.5), ('A5', 1.5, 0.5),
         ('G5', 2.0, 0.5), ('E5', 2.5, 0.5), ('A5', 3.0, 1.0)],
        # bar 1 - F
        [('F5', 0.0, 0.75), ('A5', 0.75, 0.25),
         ('C6', 1.0, 0.5), ('A5', 1.5, 0.5),
         ('F5', 2.0, 0.5), ('E5', 2.5, 0.5), ('D5', 3.0, 1.0)],
        # bar 2 - C
        [('C5', 0.0, 0.5), ('E5', 0.5, 0.5), ('G5', 1.0, 0.5), ('C6', 1.5, 0.5),
         ('B5', 2.0, 0.5), ('G5', 2.5, 0.5), ('E5', 3.0, 1.0)],
        # bar 3 - G
        [('D5', 0.0, 0.5), ('G5', 0.5, 0.5), ('B5', 1.0, 0.5), ('D6', 1.5, 0.5),
         ('B5', 2.0, 0.5), ('G5', 2.5, 0.5), ('E5', 3.0, 1.0)],
        # bar 4 - Am  (variation - faster runs)
        [('A4', 0.0, 0.25), ('B4', 0.25, 0.25), ('C5', 0.5, 0.25), ('E5', 0.75, 0.25),
         ('A5', 1.0, 0.5), ('G5', 1.5, 0.5),
         ('E5', 2.0, 0.5), ('A5', 2.5, 0.5), ('C6', 3.0, 1.0)],
        # bar 5 - F
        [('A5', 0.0, 0.5), ('C6', 0.5, 0.5), ('A5', 1.0, 0.5), ('F5', 1.5, 0.5),
         ('G5', 2.0, 0.5), ('A5', 2.5, 0.5), ('F5', 3.0, 1.0)],
        # bar 6 - C
        [('G5', 0.0, 0.5), ('C6', 0.5, 0.5), ('B5', 1.0, 0.5), ('G5', 1.5, 0.5),
         ('E5', 2.0, 0.25), ('G5', 2.25, 0.25), ('C6', 2.5, 0.5),
         ('B5', 3.0, 1.0)],
        # bar 7 - G  (climb back to start)
        [('D5', 0.0, 0.5), ('F5', 0.5, 0.5), ('G5', 1.0, 0.5), ('B5', 1.5, 0.5),
         ('D6', 2.0, 0.5), ('B5', 2.5, 0.5), ('G5', 3.0, 0.5), ('E5', 3.5, 0.5)],
    ]

    for bar_i, (chord_name, triad) in enumerate(chords):
        bar_t = bar_i * bar
        root, third, fifth = triad

        # --- Driving bass (square, 8th notes alternating root/octave) ---
        # rhythm: root root oct root | root root oct fifth (per pair)
        bass_rhythm = [
            (root,  0.0, 0.5),
            (root,  0.5, 0.5),
            (root,  1.0, 0.5),
            (third, 1.5, 0.5),
            (fifth, 2.0, 0.5),
            (root,  2.5, 0.5),
            (root,  3.0, 0.5),
            (fifth, 3.5, 0.5),
        ]
        for n, off, d in bass_rhythm:
            bass.place(
                render_note(n, d * beat * 0.92, osc='square', duty=0.5,
                            vol=0.26, a=0.003, d=0.04, s=0.55, r=0.04),
                bar_t + off * beat)

        # --- Chord stabs on beats 2 and 4 (square, low duty for "organ" feel) ---
        for stab_beat in (1.0, 3.0):
            for n in triad:
                # raise an octave for stab
                m = midi(n) + 12
                chord.place(
                    render_note(m, beat * 0.40, osc='square', duty=0.25,
                                vol=0.10, a=0.004, d=0.06, s=0.3, r=0.04),
                    bar_t + stab_beat * beat)

        # --- Lead melody ---
        for n, off, d in lead_phrase[bar_i]:
            lead.place(
                render_note(n, d * beat * 0.95, osc='square', duty=0.5,
                            vol=0.22, a=0.004, d=0.05, s=0.7, r=0.05,
                            vibrato=0.004),
                bar_t + off * beat)

        # --- Drums: kick on 1 & 3, snare on 2 & 4, hats on 8ths ---
        drums.place(render_kick(dur=0.16, vol=0.55), bar_t + 0 * beat)
        drums.place(render_kick(dur=0.14, vol=0.45), bar_t + 2 * beat)
        # extra kick anticipation on the "and" of beat 2 every other bar
        if bar_i % 2 == 1:
            drums.place(render_kick(dur=0.12, vol=0.35), bar_t + 2.5 * beat)

        drums.place(render_snare(dur=0.20, vol=0.40), bar_t + 1 * beat)
        drums.place(render_snare(dur=0.20, vol=0.40), bar_t + 3 * beat)

        for i in range(8):
            v = 0.13 if i % 2 == 0 else 0.09
            drums.place(render_hat(0.05, vol=v), bar_t + i * 0.5 * beat)

        # On bar 7 (last bar) add a snare fill on the "and"s of beats 3-4
        if bar_i == 7:
            for off in (3.0, 3.25, 3.5, 3.75):
                drums.place(render_snare(dur=0.10, vol=0.30), bar_t + off * beat)

    out = mix(lead, bass, chord, drums)
    return out


def main():
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    print("Generating home_loop.wav...")
    home = make_home_loop()
    write_wav(os.path.join(out_dir, 'home_loop.wav'), home)

    print("Generating game_loop.wav...")
    game = make_game_loop()
    write_wav(os.path.join(out_dir, 'game_loop.wav'), game)

    print("Done.")

if __name__ == '__main__':
    main()
