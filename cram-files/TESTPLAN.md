# CRAM System — Sale-Readiness Test Plan

Goal: prove the system is functional, consistent, and shippable. Ordered by priority.
Run every test with `CRAM_DEBUG` = true and the Trace tab open. When something
fails, paste the trace lines starting with `[RadarAPI]` plus what the Live tab shows.

Test vehicles: SA330, OH-6 Loach, CH-178, Mi-8, NH-90, UH-60M, LAAT, UH-1Y,
F-16C, A-10C, SU-25 (the 11 confirmed types).

---

## P0 — The two fixes from last session (must pass before anything else)

### P0-1: Reparenting detection (the `Workspace.Model` → workspace root bug)
1. Fresh server, debug on, Trace tab open.
2. `:insert` a SA330. Watch the Trace tab:
   - one-time diagnostic: full path, parent name, `Classified as: Helicopter`, verdict line
   - a reparent line: `reparented -> now under 'Workspace'. Still under a 'Model' container: false`
3. After the reparent completes, the **Live tab must STILL show the vehicle**.
4. Drag the vehicle into a random folder (`TestFolder`) and back to workspace
   root. Each move logs a reparent line; Live tab must keep showing it at root.
5. Repeat for all 11 vehicle types.
- **PASS:** vehicle visible in Live tab at all times after insert finishes.
- **FAIL:** it disappears after the reparent, or never appears. Paste trace.

### P0-2: ENGAGE ALL / IGNORE ALL semantics (the swapped-buttons fix)
1. One unit in **INDIVIDUAL** mode. Spawn a helicopter.
2. In Targets tab, set that vehicle's row to `IGNORE (Safe)` → unit must NOT fire.
3. Set it to `ENGAGE (Shoot)` → unit fires.
4. Press `IGNORE ALL (Safe)` → every row turns gray → unit fires at NOTHING.
5. Press `ENGAGE ALL (Shoot)` → every row turns green → unit fires at valid targets.
6. Repeat the category-level ENGAGE ALL / IGNORE ALL buttons.
- **PASS:** visual state == actual behavior for every button.
- **FAIL:** any button that looks one way but acts the other. Paste what you clicked.

---

## P1 — Consistency (where every previous disagreement lived)

### P1-3: Three views, one truth
For each of the 11 vehicles, confirm these three agree:
1. **Live tab** shows it.
2. **Targets tab → uncategorized** section shows it (if not a preset).
3. **Click-to-tag in the world** recognizes it (hover highlights, click tags it).
- **PASS:** all three agree on every vehicle.
- **FAIL:** Live shows it but uncategorized doesn't (or vice versa). Paste trace +
  which vehicle + which view disagreed. NOTE: the client currently builds the
  uncategorized list with its OWN local heuristics (see ARCHITECTURE.md) — this
  test will tell us if that leftover actually bites.

### P1-4: Damage model per profile (trace must confirm every claim)
**Helicopters** (test at least 2, ideally a multi-Durability one):
1. Let a unit shoot it once. Trace must show EVERY `Durability` value on the
   model dropping by the same amount in one hit (multiple `-> Durability changed to` lines).
2. Keep hitting: all Durability values hit 0 → target considered dead, unit stops firing.
3. If the heli has a single `Health` instead (no Durability), it must drain and kill.

**Jets** (F-16C, A-10C, SU-25):
1. Hits must drain `Health` (trace shows it dropping).
2. At 0: trace shows `Crashed` set to true + ENGINES/APU flipped false, unit stops.
3. Over ~20 hits, expect ~2-3 trace lines where ONE of
   `ENGINE_LEFT` / `ENGINE_RIGHT` / `APU` flips false mid-flight (15%/hit).
4. **Arsenal must NEVER appear in the trace** (ammo counts untouched).

**Generic / ground vehicle:**
1. Health/Durability drains, dies, unit stops.

- **PASS:** trace lines match the model above exactly.
- **FAIL:** wrong value hit, Arsenal touched, target never dies, unit keeps
  shooting a corpse. Paste the trace.

### P1-5: Manual tagging lifecycle
1. Click a detected vehicle in-world → appears in Single list → unit engages it.
2. Untag/remove it → unit stops engaging it.
3. Repeat while the vehicle is moving.

### P1-6 (DECISION): Perm targets in INDIVIDUAL mode
Currently `isTargetAllowed()` only checks perm-target folders in the **non-**
individual branch. In INDIVIDUAL mode a perm target is subject to the whitelist.
- Decide: should perm targets ALWAYS be engaged (even under IGNORE ALL /
  Individual mode)? Test both behaviors, pick one, tell me. This must be locked
  down before sale.

---

## P2 — Robustness

### P2-7: Config-panel lock
1. Unit in GLOBAL mode → config button shows `[LOCKED] SWITCH TO INDIVIDUAL TO CONFIGURE`,
   clicking flashes `SWITCH TO INDIVIDUAL MODE FIRST`, panel does NOT open.
2. Switch to INDIVIDUAL → panel opens, edits apply and persist.

### P2-8: Multi-unit cooperation (claims)
1. 2+ units, ONE vehicle. Exactly one unit engages (trace shows the claim owner).
2. Kill it. Another target appears → a unit claims it. No two units firing the same target.
3. Unit destroyed mid-engagement → no errors, target released, other unit can take it.

### P2-9: Stability soak
1. 30 minutes: insert/remove all 11 vehicles repeatedly, rejoin the server
   mid-engagement, destroy a unit mid-fire, despawn a target mid-fire.
2. Studio console: ZERO red errors. Trace log stays capped (~50k chars, no runaway).

### P2-10: Performance
1. 6-10 CIWS units + ~20 vehicles at once. Watch server Script Activity %
   and memory. Units must still track/target smoothly.

### P2-11: Fresh-install (the "buyer test")
1. Empty baseplate place. Install everything following ONLY the README
   (drop folder into ServerScriptService, tool into StarterPack).
2. Insert vehicles, deploy a unit. Everything works with no other setup.
3. After release-polsih: with debug off by default, trace stays EMPTY.

---

## P3 — Release polish (after tests pass, before sale)

- [ ] `CRAM_DEBUG` auto-creates with `Value = true` today → must default FALSE
      for buyers (server script lines 28-33).
- [ ] Resolve P1-6 decision + occupant-watcher decision.
- [ ] Consistent naming/tags (document `CRAM_Vehicle` vs `CRAMTarget`).
- [ ] Buyer README: install steps, how to configure ranges/whitelists, how to add
      a new vehicle type (one profile in RadarAPI), troubleshooting via Trace tab.
- [ ] Version number + changelog in the code header.
