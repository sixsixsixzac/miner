# Auto-Miner Plan

## Feature Summary
An "Auto Miner" — a 3D-printer-style machine that hovers above each player's platform and autonomously mines ores. It slides on X/Z only (fixed Y above the platform), moves to the nearest mineable ore, waits above it for a mining duration, then repeats.

## Architecture

### Where the logic lives
- **Server-only** (`src/server/AutoMiner.luau`). The miner is authoritative: it calls `OreState.tryMine` on behalf of the player, same as a player click. The client only sees the visual model replicated automatically because it lives in Workspace.
- The miner model is a Model placed in Workspace when `beginPlayer` runs and destroyed when `endPlayer` runs.
- No new remotes needed — existing `OreDamaged`/`OreDestroyed` events already tell every client what happened.

### Miner model (built in code, no Studio model needed)
A small assembly of Parts anchored in Workspace that looks like a 3D printer gantry:
- `Body` — flat chassis block (neon metal)
- Two `Rail` parts on ±Z edges (the gantry arms)
- `Head` — a small nozzle block that visually represents the print head
- Moves as a whole Model by updating the PrimaryPart CFrame

All parts are `CanCollide = false`, `Anchored = true`.

### Server loop (per-player)
```
AutoMiner state per player:
  { platform, model, primaryPart, runToken }

Loop (task.spawn, checked against runToken each step):
  1. Scan sharedWorld.ores for ores on this platformId with state == "mineable"
  2. If none → wait 0.5s, retry
  3. Pick nearest ore (by XZ distance from miner current pos)
  4. Tween/move miner to ore XZ position (keep Y fixed above platform)
     - Move speed: configurable studs/sec, use task.wait increments
  5. Wait `mineDelay` seconds (the "printing" dwell time)
  6. Call OreState.tryMine(player, oreId) — handles HP, events, regen
  7. Repeat
```

### Config additions (init.server.luau config table)
```lua
autoMinerEnabled = true,
autoMinerSpeed   = 12,   -- studs/sec horizontal travel
autoMinerDelay   = 1.5,  -- seconds dwelling on ore before mine hit
autoMinerHeight  = 8,    -- studs above platform top surface
```

### Integration points
- `OreState.beginPlayer` → call `AutoMiner.start(player, platform, sharedWorld, config)`
- `OreState.endPlayer`   → call `AutoMiner.stop(player)`
- `OreState` needs to expose `sharedWorld` (or a getter) so AutoMiner can read `ores` and `platforms`

## Files to create / modify

| File | Change |
|------|--------|
| `src/server/AutoMiner.luau` | **New** — full miner logic + model builder |
| `src/server/OreState.luau` | Add `OreState.getSharedWorld()` getter |
| `src/server/init.server.luau` | Add miner config keys; wire AutoMiner start/stop |

## Key invariants preserved
- Server is still authoritative — miner calls `tryMine`, client reacts to events
- `runToken` pattern used: miner loop captures token on start, bails if token changes
- No client changes needed — the model replicates automatically to all clients
- Platform ownership unchanged
