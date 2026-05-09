# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Roblox mining game built with [Rojo](https://rojo.space/). Authority is **server-side**: the server owns all ore state and the client renders from snapshots + events. Each player gets their own isolated ore world on a dedicated platform.

## Build & Run

Requires Rojo 7.6.1+ and Roblox Studio.

```bash
rojo build -o "robloxs.rbxlx"   # one-shot build of the place file
rojo serve                       # live-sync src/ into Studio (open robloxs.rbxlx and connect)
```

There are no automated tests or linters configured. Validation is manual in Studio.

## Architecture

### Filesystem → Roblox mapping

Defined in [default.project.json](default.project.json):

- `src/shared/` → `ReplicatedStorage.Shared` (modules used by both sides)
- `src/server/` → `ServerScriptService.Server` (authoritative game logic)
- `src/client/` → `StarterPlayer.StarterPlayerScripts.Client` (renderer + UI)
- `Workspace.OrePlatforms` — 8 pre-defined `Slot1..Slot8` parts that the server hands out one per player.

### Boot order & remote handshake

Remotes are constructed at runtime, not declared in the project tree:

1. [RemotesInit.server.luau](src/server/RemotesInit.server.luau) creates `ReplicatedStorage.OreRemotes` (folder) with 4 RemoteEvents and 2 RemoteFunctions, then sets attribute `Ready=true`.
2. [src/shared/Remotes.luau](src/shared/Remotes.luau) — both sides call `Remotes.get()`. On the client it blocks on the `Ready` attribute before resolving children, so any client code that needs remotes must call `RemotesModule.waitReady()` first (see [src/client/init.client.luau](src/client/init.client.luau)).
3. [src/server/init.server.luau](src/server/init.server.luau) wires `OreSnapshot` (RemoteFunction) and `MineOre` (RemoteFunction), and starts a per-player world on `PlayerAdded`.

The 6 remotes (server → client unless noted):

| Name | Kind | Purpose |
|---|---|---|
| `OreSpawned` | Event | Tell client to spawn + animate-rise an ore |
| `OreMineable` | Event | Ore finished rising and is now clickable |
| `OreDamaged` | Event | HP decreased (multi-hit ores) |
| `OreDestroyed` | Event | Ore mined to 0 HP, remove it |
| `OreSnapshot` | Function (C→S) | Client requests full state on (re)join |
| `MineOre` | Function (C→S) | Player clicked an ore; server validates + applies damage |

### Server: per-player worlds ([src/server/OreState.luau](src/server/OreState.luau))

- `worlds[userId]` holds `{ player, platform, ores, destroyed, gridSlots, occupiedSlots, runToken, ... }`.
- Platforms are pooled (`acquirePlatform`/`releasePlatform`) from `Workspace.OrePlatforms` — limits concurrent players to the slot count (currently 8).
- `runToken` is a per-world identity used to cancel pending `task.delay` callbacks if the player leaves before they fire. **Any new deferred work scoped to a world must capture and re-check `runToken`** or it will leak across player sessions.
- `tryMine` is the only mutation entry-point from clients: validates ore exists, is `mineable`, player meets level/rebirth gate, then subtracts `PlayerStats.damage` from `ore.hp`. Reaching 0 moves the ore from `world.ores` to `world.destroyed`; the regen loop respawns it after `regenerationDelay`.
- Tuning lives in the `config` table at the top of [src/server/init.server.luau](src/server/init.server.luau:11-19): `gridSpacing`, `oreSize`, `riseDuration`, `spawnDelay`, `spawnChance`, `maxBlocks`, `regenerationDelay`, `autoMinerHeight`. Note: `autoMinerSpeed` and `autoMinerDelay` remain in the config table but are unused — the miner reads these values from `PlayerStats` instead.

### Server: auto-miner ([src/server/AutoMiner.luau](src/server/AutoMiner.luau))

A per-player gantry machine that autonomously mines ores on the player's platform. Started in `onPlayerAdded` via `AutoMiner.start(player, platform, OreState.getSharedWorld, config.autoMinerHeight)` and stopped in `PlayerRemoving` via `AutoMiner.stop(player)`.

- **Model**: built in code — two crossing beams (`BeamX` spans full platform width, slides Z-only; `BeamZ` spans full platform depth, slides X-only), four guide rails along all platform edges (`RailNX`/`RailPX` span Z at ±X edges; `RailNZ`/`RailPZ` span X at ±Z edges), a `Body` block, and a neon `Drill`. All parts are `Anchored`, `CanCollide = false`.
- **Loop**: scans `sharedWorld.ores` for the nearest `mineable` ore on this player's platform, tweens the body/drill/beams to the ore's XZ position (constrained-axis per part), waits `stats.minerDelay`, then calls `OreState.tryMine`. Speed and delay come exclusively from `PlayerStats` (`minerSpeed`, `minerDelay`) — no config fallback.
- **`runToken`**: captured at start; loop and model cleanup bail if the token changes (player leaves mid-loop).

### Server: player stats ([src/server/PlayerStats.luau](src/server/PlayerStats.luau))

In-memory only — `{ level, rebirth, luck, damage, minerSpeed, minerDelay }` per player. **No persistence yet**; resets on rejoin. Defaults to `level=1, rebirth=0, luck=1.0, damage=1, minerSpeed=6, minerDelay=1.5`.

### Shared: ore definitions ([src/shared/OreTypes.luau](src/shared/OreTypes.luau))

Single source of truth for the 5 ore types (Stone/Coal/Iron/Gold/Diamond). Each has `color`, `material`, `rarity` (weight), `minLevel`, `minRebirth`, `maxHp`. Helper `pickRandomOreType(level, rebirth)` does weighted random selection over types the player has unlocked.

### Client: renderer ([src/client/OreGenerator.luau](src/client/OreGenerator.luau), [src/client/OreManager.luau](src/client/OreManager.luau))

The client is a **dumb renderer** — it never decides whether an ore exists, only how to draw what the server announces.

- `OreManager` is a flat `{ [oreId] = entry }` table; `entry` holds `part`, `type`, `isMineable`, optional `hp/maxHp/hpFill/hpBar`.
- `OreGenerator.start()`:
  1. Binds remote handlers (events received before snapshot are buffered in `pendingMineable`/`pendingDestroyed`/`pendingDamaged`).
  2. Invokes `OreSnapshot` to get current world state.
  3. Calls `applySnapshot` which uses `placeFinal` for already-mineable ores and `spawnLocal` (with remaining rise time) for in-flight ones.
  4. Drains the pending event queues, then sets `snapshotApplied=true`.
- HP bars are only created when `maxHp > 1`. They auto-attach lazily on the first `OreDamaged` if missing.

### Client: loading flow ([src/client/init.client.luau](src/client/init.client.luau))

Shows [LoadingScreen.luau](src/client/LoadingScreen.luau) (Thai-language status text), waits for `OreRemotes.Ready`, then calls `OreGenerator.start()` inside a `pcall`. Don't reorder these steps — `RemotesModule.waitReady()` must complete before any other module that calls `Remotes.get()` runs.

## Conventions

- **Luau** with optional type annotations. Modules `return` a table.
- **No comments** by default — self-explanatory names preferred.
- **Logging**: server logs use `[OreServer]` prefix, client uses `[OreClient]`. Mine attempts always log accept/reject with reason — keep this when modifying `tryMine`.
- **Server is authoritative** — never trust client-supplied IDs without re-validating against `world.ores`. Never let the client compute damage, HP, or spawn outcomes.

## Common Tasks

### Add a new ore type

1. Add an entry to `OreTypes.Definitions` in [src/shared/OreTypes.luau](src/shared/OreTypes.luau) with `color`, `material`, `rarity`, `minLevel`, `minRebirth`, `maxHp`.
2. That's it — `pickRandomOreType` and the client renderer pick it up automatically.

### Adjust spawn/regen pacing

Edit the `config` table in [src/server/init.server.luau](src/server/init.server.luau:11-19). Client picks up `riseDuration` and per-ore `size` from the `OreSpawned` payload, so don't duplicate these values client-side.

### Add a new remote

1. Append to `REMOTE_EVENTS` or `REMOTE_FUNCTIONS` in [src/server/RemotesInit.server.luau](src/server/RemotesInit.server.luau).
2. Add a typed field to the `cached` table in [src/shared/Remotes.luau](src/shared/Remotes.luau) and a `WaitForChild` line in `buildCache`.
3. Both sides resolve it through `RemotesModule.get()`.

### Increase max concurrent players

Add more `SlotN` entries under `Workspace.OrePlatforms` in [default.project.json](default.project.json). The pool size is the player cap.
