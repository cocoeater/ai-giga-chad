# Master C-RAM — Modular Client Architecture

## Overview

This directory contains the modularized client system for the Master C-RAM, designed to run from `StarterPlayer/StarterPlayerScripts` instead of being parented inside the Tool or PlayerGui.

### Why this architecture is better:
1. **Persistent UI State**: The `ScreenGui` is created once with `ResetOnSpawn = false`. When the player dies or respawns, the UI state, selected unit, active tab, and whitelist selections remain intact without stutter or reloading.
2. **Clean Separation of Concerns**: Each aspect of the client UI has its own module:
   - `UiKit`: Pure UI factory (buttons, labels, stroke styling, sliders, draggable windows)
   - `VehicleResolver`: Client-side target inspection, hitboxes, and model traversal (stops before entering player characters)
   - `CRAMClientConfig`: Central categories, presets, and color palettes
   - `StateStore`: Reactive central state store (fleet units, detected targets, active tab, tool equip status)
   - `PlacementController`: Ghost preview, surface raycast rotation, and CIWS placement
   - `WorldOverlays`: 3D Billboard indicators over CIWS turrets and targets in workspace
   - `Tabs/`: Separate UI views for `FleetTab`, `TargetMatrixTab`, `LiveTargetsTab`, and `TraceTab`
3. **No Code Duplication**: Modules are required on-demand; no 3,500-line monolithic script where editing one tab risks breaking another.

---

## Installation in Roblox Studio

1. Open your place in Roblox Studio.
2. In the Explorer window, navigate to `StarterPlayer` -> `StarterPlayerScripts`.
3. Create a folder named `MasterCRAMClient` (or place the files directly under `StarterPlayerScripts`):
   - Place `MasterCRAM_Client.client.lua` as a `LocalScript` inside `StarterPlayerScripts`.
   - Place `Modules/` as a `Folder` inside `StarterPlayerScripts` (as a sibling or child of `MasterCRAM_Client`).
4. If using the tool `Master C-RAM`:
   - Remove the old monolithic `MasterCRAM_Client_FIXED` script from the Tool or `PlayerGui`.
   - The modular client script automatically discovers the `Master C-RAM` tool in either `Backpack` or `Character`, binds to its `Equipped` and `Unequipped` events, and manages the UI seamlessly.
