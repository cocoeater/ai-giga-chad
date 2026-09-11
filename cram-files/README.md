# CIWS/C-RAM System — File Inventory & Verification

Extracted from the continuation summary (`hey` at repo root) on 2026-09-11.
These are the latest versions of every script as of the end of the previous session.

## Core files (all in ServerScriptService)

| File | Role | Lines |
|---|---|---|
| `RadarAPI.lua` | ModuleScript — shared detection / damage / coordination | 527 |
| `MasterCRAM_Server_FIXED.lua` | Main server Script — state broadcast, tagging, deploy | 1374 |
| `MasterCRAM_CIWS_Unit_FIXED.lua` | Per-unit CIWS controller — targeting, firing, damage | 1536 |
| `MasterCRAM_Client_FIXED.lua` | LocalScript inside "Master C-RAM" Tool — UI (Targets/Deploy/Fleet/Global/Live/Trace) | 3450 |

## Supporting files

- `CRAMRegistry.lua` — pre-existing unit registry module (NOT modified, included for completeness)
- `PhalanxClient.lua` — client-side Phalanx turret hookup (transcript snippet)
- `ToolClient.lua` — tool Equipped/Unequipped UI toggling (transcript snippet)

## Fixes verified in these files (against the bug list)

- [x] `blocked(m)` scope bug — gone; top-level `isWorldModel()` used instead (server)
- [x] Duplicate `targetWhitelist` literal keys — gone; only `table.clone(...)` assignments remain (client)
- [x] `getHoverTarget()` — checks `CRAM_Vehicle` CollectionService tag first (client)
- [x] Config-panel lock — Fleet config refuses to open in Global mode, flashes "SWITCH TO INDIVIDUAL MODE FIRST", card shows `[LOCKED] SWITCH TO INDIVIDUAL TO CONFIGURE` (client)
- [x] Detection architecture — server detection is `RadarAPI.scan()` only; no structural heuristic scanning (server)
- [x] ENGAGE ALL / IGNORE ALL swap — ENGAGE ALL populates the whitelist, IGNORE ALL clears it; server-side `isTargetAllowed()` treats whitelist membership as "engage" in INDIVIDUAL mode (client + unit)

## RadarAPI design verified

- `scan()`: children of `"Model"`-named containers (Model or Folder) + workspace direct children; explicitly skips anything named `"Model"`; 0.2s cache (`_cacheTTL`); skips player characters
- `Profiles.Helicopter` — Rotors / PilotSeat / RotorHitbox / BulletHitbox; damage hits EVERY `Durability` NumberValue, falls back to single `Health`
- `Profiles.CombatJet` — Afterburner / MainParts; drains `Health` under `Plane`; kill sets `Crashed = true`; 15%/hit knocks out one of StatusMain `ENGINE_LEFT` / `ENGINE_RIGHT` / `APU` (true = running); `Arsenal` untouched
- `Profiles.Generic` — fallback; `ProfileOrder` first-match wins
- Cooperation: `registerSystem` / `unregisterSystem` / `updateSystemSettings` / `getSystems`, `claimTarget` / `releaseTarget` / `getClaimOwner` / `pruneClaims`
- `watchModel()` — AncestryChanged reparent logs + `.Changed` on Durability/Health/Crashed/CanBeTargetted/APU/ENGINE_* values (incl. DescendantAdded); no seat-occupant watcher (not yet implemented, as agreed)
- `debugModel(model)` + one-time first-sighting diagnostic; logger wired to each controller's `trace()`, gated by `CRAM_DEBUG` BoolValue in ReplicatedStorage
- Implementation comments kept to usage/API only per instruction

## Syntax check

Parsed all 7 files with `luaparse` (Lua 5.3 mode). The 3 reported "errors" are valid Luau that Roblox accepts (`continue`, `model: Model` type annotation, `(require :: any)` cast) — no real syntax problems.

## Still to test in-game (as of handoff)

1. **Reparenting fix** — vehicles moving from `Workspace.Model` staging folder to workspace root must stay visible in the Live tab. The scan fix is in place but unverified in-game.
2. **ENGAGE ALL / IGNORE ALL** — verify the corrected button behavior actually produces correct targeting in INDIVIDUAL mode.
