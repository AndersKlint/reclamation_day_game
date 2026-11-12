# Soul screech source

- Source: `available-assets/sfx/animalsandmonsters_krotosaudio/Monsters/Ghost_Yell_01.wav` (unchanged).
- Source metadata: Krotos Starter Library, artist Krotos, copyright 2021 Krotos; embedded description `ghost, yell`. No pack README or license file was found locally; existing asset entitlement remains the developer's responsibility.
- Shortlist, verified on disk: `Ghost_Yell_01.wav` and `Ghost_Yell_02.wav` (both stereo PCM24, 192 kHz, 1.7688125 seconds), `Ghost_Moan_01.wav` (same format, 3.45890625 seconds), all in the same `Monsters/` directory.
- Selected the first yell by filename/metadata for a short ghost vocal attack rather than the longer moan. No audio audition was performed; sonic suitability needs developer approval.
- Derivative: `soul_screech.wav`, stereo PCM16 WAV at 44.1 kHz. Pitch raised 12%, high-pass 240 Hz, low-pass 6.5 kHz, quiet 89/173/307/521 ms echoes, padded fading tail, hard duration cap 2.4 seconds. Gain reduction and a 0.75-amplitude safety limiter retain headroom; no bus effects.
- Scene playback: nonspatial, existing SFX bus when available, otherwise Master, -10 dB. Visual duration 1.45 seconds; cleanup waits for the full audio duration plus 0.15 seconds and pauses with the game.
- Technical metadata check: 105,840 stereo frames, 2.4 seconds, 423,438 bytes, measured sample peak -11.58 dBFS, zero clipped PCM16 samples. No playback performed.

Reproduction from the project root:

```sh
ffmpeg -nostdin -i available-assets/sfx/animalsandmonsters_krotosaudio/Monsters/Ghost_Yell_01.wav -map_metadata -1 -af 'aresample=44100,asetrate=49392,aresample=44100,highpass=f=240,lowpass=f=6500,volume=0.65,aecho=0.8:0.7:89|173|307|521:0.24|0.18|0.12|0.07,apad=whole_dur=2.4,atrim=duration=2.4,afade=t=in:d=0.008,afade=t=out:st=1.75:d=0.65,alimiter=limit=0.75:level=false:latency=true' -ar 44100 -ac 2 -c:a pcm_s16le game/upgrades/soul_burst/audio/soul_screech.wav
```
