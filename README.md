# Nightcrawler Warp

A single LocalScript that warps **everything in the game** — the map, other
players, vehicles, props — in the Nightcrawler teleport / Harry Potter
Apparition style, based on the per-point time-offset trick from
[Default Cube — 4D Animations](https://www.youtube.com/watch?v=7iXkP3jI3YE).

## Install (30 seconds, no tools)

1. Open Roblox Studio.
2. In Explorer, go to **StarterPlayer → StarterPlayerScripts**.
3. Hover it, click **+**, insert a **LocalScript** (any name).
4. Open `NightcrawlerWarp.client.luau` in this repo, copy everything, paste.
5. Press Play. It auto-fires one warp after 2 seconds so you can see it.

## Controls

| Key | Action |
|-----|--------|
| **T** | fire one warp pulse (chaos in, hold, chaos out) |
| **Y** | toggle constant warp on/off |

## What it does to "everything"

- **Moving things** (characters, cars, doors) get a rolling history of their
  real CFrames recorded at 30 Hz. During a warp, each part is shown a
  different number of frames in the past, with the amount driven by a
  scrolling 3D noise field — so every limb/part exists in a different moment
  at once. That is exactly the video's noise time-offset effect.
- **Static things** (your map) never moved, so they get noise-driven chunk
  jitter instead: nearby parts move together in ~8-stud cells, spinning and
  shifting, then settle back.
- Parts that stream in / spawn later are picked up automatically.

## Performance

- One `Workspace:BulkMoveTo(...FireCFrameChanged)` batch per rendered frame,
  regardless of part count — no per-part property sets.
- History rings are allocated lazily and **only for parts that actually
  move**; the static map costs one CFrame reference each.
- Output buffers are reused every frame; nothing is allocated during a warp.
- `HumanoidRootPart`s are never moved (your camera and physics stay stable;
  limbs still scramble, and motors re-pose them every frame).
- When a warp ends, every static part is snapped back to its exact rest CFrame
  in one batch — the world returns pixel-perfect, no drift.

## Tuning

All knobs are in the `Config` table at the top of the script:

| Field | Effect |
|-------|--------|
| `JitterStuds` | how far static map chunks shift |
| `RotationJitter` | how much they spin (radians) |
| `NoiseFrequency` | smaller = bigger chunks, bigger = finer scramble |
| `ScrollSpeed` | how fast the noise field moves over time |
| `HistoryFrames` / `RecordFPS` | how far back moving things can jump |
| `PulseIn` / `PulseHold` / `PulseOut` | pulse timing in seconds |
| `AutoDemoPulse` | self-fire once 2s after start |

## Limitations

- Terrain and voxels can't be moved (Roblox doesn't allow it).
- Unanchored loose physics props may rubber-band a little at the end of a
  long constant warp; anchored geometry and characters are clean.
- It's a client-side visual effect — other players don't see your warp and
  nothing replicates, which is normally what you want for a teleport VFX.
