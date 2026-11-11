# Shared shockwave explosion

Source: `available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Explosion_Fire_Gas/explosion_deep_low_1.wav`.

Selected by filename and metadata, not auditioned. Original: stereo PCM16, 48 kHz, 3.247938 seconds. Source remains unchanged.

`shockwave_muffled.wav` is mono PCM signed 16-bit little-endian, 48 kHz, non-looping. FFmpeg filter chain:

```text
highpass=f=28,lowpass=f=650:p=2,lowpass=f=650:p=2,bass=g=4:f=90:w=0.7,alimiter=limit=0.9:level=false,afade=t=in:d=0.003,afade=t=out:st=2.85:d=0.397938
```

Conversion flags: `-ac 1 -ar 48000 -c:a pcm_s16le -map_metadata -1 -write_bext 0`.

Both upgrades use this exact sample without pitch variation. A dedicated nonspatial player makes player-origin impact volume independent of third-person camera distance, routes to SFX when available (otherwise Master), and never changes audio buses or uses collapse voices.

Instantiate `shockwave_burst.tscn` under the unscaled world/run node, position its root at ground level, then call `play(radius)` once. One plane supplies the ring, trailing wave and short impact pulse; no gameplay/collision. Cosmetic radius is capped at 128 world units to bound extreme-growth transparent overdraw. The ring reaches its supplied radius within 0.64 seconds and fades by 0.8 seconds. The node frees after the longer visual/audio lifetime plus 0.1 seconds. Root processing and its bound tween pause with the scene tree; shader animation does not use TIME.
