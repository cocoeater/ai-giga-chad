# CRAM System — Restructure Proposal ("make it actually organized")

## The honest answer

Yes — splitting is better, and it's not just aesthetics. Your pain has a
structural cause: the same logic exists in 2-3 places, and one file has grown
so big that every change risks something unrelated. Evidence from the current
code:

| Logic | Copies today |
|---|---|
| `cleanModelName` | Server (L122), Unit (L87), Client (L112) |
| `getCleanSignatureTokens` | Server (L101), Unit (L66) |
| `isPermTargetMatch` | Server (L149), Unit (L94) |
| `getBestTargetPart` | Server (L415), Client (L144), + each RadarAPI profile |
| `getSurfaceRotation` | Server (L813), Client (L2100) |
| `makeWhitelist` (client L101) | **Dead code, zero callers** |

Plus a **latent bug found during mapping**: the client's Targets tab
"uncategorized" list (L204) still scans the workspace itself with the OLD
heuristics (`isVehicleOrTarget`, `getBestTargetPart`) instead of deriving from
the server's `targets.detected` payload. That is exactly the "Live tab says one
thing, Targets tab says another" class of bug you've been fighting. It must die
in the refactor (Phase 3).

Also note: `MasterCRAM_CIWS_Unit_FIXED.lua` is not really "per unit" — it's one
global manager for ALL units (discovers them via workspace ChildAdded, runs one
loop over `ciwsUnits`). Fine in practice, but the name lies and it's 1536 lines.

## Target layout (end state)

```
ServerScriptService/
  CramSystem/
    RadarAPI.lua              # unchanged core (profiles, scan, damage, claims, watch)
    CRAMRegistry.lua          # existing registry
    CramConfig.lua            # NEW ModuleScript: every tunable constant + name + tag
    CramShared.lua            # NEW: cleanModelName, signature tokens, perm match,
                              #      tag match, isWorldModel  (ONE copy, server-side)
    CramState.lua             # NEW: single owner of units/configs/perm rules/detected;
                              #      serialization + broadcast
    CramDeploy.lua            # NEW: placement, templates, live-unit registration,
                              #      CRAM_Vehicle / CRAMTarget tagging
    CramPerm.lua              # NEW: perm-target rules
    CramServerMain.server.lua # THIN Script: RemoteEvent wiring + loops (~150 lines)
    CramUnitManager.server.lua# THIN: discovers units, runs the master loop
    CramUnit.lua              # NEW ModuleScript: one unit's brain (setup, fireUp/down,
                              #      LoS, intercept, engage logic)
StarterPack/"Master C-RAM" Tool/
  ClientMain.local            # THIN LocalScript: remote listener, equip/unequip, tabs
  UiKit.lua                   # NEW: mkB/mkL/mkS/mkP/mkC/conn/tw/formatNum/playSound,
                              #      createSlider/createToggle, drag helpers
  StateStore.lua              # NEW: cachedState + pure selectors (cleanModelName,
                              #      uncategorized derivation FROM SERVER PAYLOAD ONLY)
  Tabs/TargetsTab.lua         # NEW: renderTargetMatrix + targets UI
  Tabs/DeployTab.lua          # NEW: placement, templates UI
  Tabs/FleetTab.lua           # NEW: fleet cards, config panel + its lock
  Tabs/GlobalTab.lua          # NEW: global sliders
  Tabs/LiveTab.lua            # NEW: live list render
  Tabs/TraceTab.lua           # NEW: trace render
```

Result: no file over ~600 lines; one copy of every rule; the client becomes a
pure renderer of server data (no detection logic of its own).

## Migration order — 5 phases, each ends with a test gate

Hard rule for Phases 1-4: **pure moves and deletions only, zero behavior
changes.** After every phase: re-run P0 + P1 from TESTPLAN.md. RadarAPI stays
untouched until Phase 4.

- **Phase 0 (now):** Run TESTPLAN P0 + P1 on the current files. Lock in a
  known-good baseline. Do NOT refactor while the baseline is unproven — if
  something breaks after a refactor, you need to know it wasn't already broken.
- **Phase 1 — extract shared helpers (safest win):**
  - Server: create `CramShared.lua` + `CramConfig.lua`; move the duplicated
    helpers into them; replace bodies in Server/Unit with `require` calls.
  - Client: create `UiKit.lua` (all the mkB/mkL/mkS/tw/conn/sound helpers) and
    `StateStore.lua` (cachedState + cleanModelName). Delete dead `makeWhitelist`.
  - Kills 6 of the 8 duplication rows in the table above with zero logic change.
- **Phase 2 — split the two server scripts:**
  - Move state/tagging/perm/deploy out of `MasterCRAM_Server_FIXED.lua` into
    `CramState` / `CramDeploy` / `CramPerm`; the Script keeps only event wiring.
  - Split `setupCIWS` + fire control out of the unit script into `CramUnit.lua`;
    the manager keeps discovery + the loop.
- **Phase 3 — split the client UI + DELETE the heuristic residue:**
  - Move each tab's render code into `Tabs/*.lua`.
  - Delete client `isVehicleOrTarget`, client `getBestTargetPart`, and the
    client-side workspace scan (L204). Uncategorized = `targets.detected` minus
    presets. Click-tag = `CRAM_Vehicle` tag only. This removes the last client
    detection logic — a real bug class, not just tidiness.
- **Phase 4 — consolidation + sale polish:**
  - Remove trivial wrappers (unit `applyShotDamage`/`isVehicleAlive` around
    RadarAPI) and the server `getBestTargetPart` that duplicates the profiles.
  - `CRAM_DEBUG` default false; resolve P1-6 decision; occupant watcher if
    confirmed; consistent naming; buyer README + version header.

## What NOT to do

- Don't split into 30 tiny modules. Target: nothing under ~50 or over ~600 lines.
- Don't refactor AND fix behavior in the same phase — you lose blame-ability.
- Don't touch RadarAPI until Phase 4; it's the only part that already has clean
  boundaries.

## Why this matters for SALE specifically

A buyer will break things in ways you can't predict, with zero trace-log
discipline. The single most valuable things for them are: (1) a config module so
they can rename/retune without reading logic, (2) debug OFF by default, (3) one
place to add a new vehicle type (RadarAPI profile), (4) a README that says
"paste the Trace tab when it misbehaves." The restructure earns all four.
