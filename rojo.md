# Rojo v7 Skill

## What is Rojo?

Rojo is a project management tool for Roblox developers. It syncs files on the filesystem into Roblox Studio in real time, enabling professional workflows like version control (Git), external editors (VS Code), static analysis (Selene), formatting (StyLua), and package management (Wally).

Docs: https://rojo.space/docs/v7/

---

## Installation

**Two components must be installed separately:**

### 1. Server (CLI)
- Via Aftman/Foreman (recommended): add `rojo-rbx/rojo` to your toolchain config
- Via VS Code Extension: install [vscode-rojo](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo) — note: this does **not** add `rojo` to PATH

### 2. Studio Plugin
```bash
rojo plugin install
```
Or download the `.rbxm` from GitHub releases and drop it into Roblox Studio's plugins folder (**Plugins → Plugins Folder**).

> Each major Rojo version has its own plugin. Make sure they match.

---

## Core Commands

| Command | Description |
|---|---|
| `rojo init [name]` | Initialize a new Rojo project |
| `rojo build -o build.rbxlx` | Build a place file (use `.rbxl` for binary) |
| `rojo serve` | Start live-sync server (default port `34872`) |
| `rojo upload --asset_id [ID] --cookie "[COOKIE]"` | Upload place to Roblox.com |
| `rojo plugin install` | Install/upgrade the Studio plugin |

**Live sync workflow:**
1. Run `rojo serve` in the project folder
2. In Studio, click the Rojo plugin button → **Connect**
3. File changes sync to Studio in real time

---

## Project File (`.project.json`)

Every Rojo project has a `default.project.json` (or named `*.project.json`).

### Required fields

```json
{
  "name": "MyGame",
  "tree": { ... }
}
```

### Optional fields

| Field | Default | Description |
|---|---|---|
| `servePort` | `34872` | Port for `rojo serve` |
| `servePlaceIds` | `null` | Allowed place IDs for live sync (prevents accidents) |
| `placeId` | `null` | Sets place ID when connecting from Studio |
| `gameId` | `null` | Sets game ID when connecting from Studio |
| `serveAddress` | `null` | Override default listen address |
| `globIgnorePaths` | `[]` | Glob patterns to exclude (e.g. `["**/*.spec.lua"]`) |
| `emitLegacyScripts` | `true` | Use `Script`/`LocalScript` vs unified `Script` with `RunContext` |

### Instance Description fields

Used inside `"tree"` to describe Roblox instances:

| Field | Required | Description |
|---|---|---|
| `$className` | If no `$path` | Roblox class name (e.g. `"Part"`, `"ReplicatedStorage"`) |
| `$path` | If no `$className` | Relative filesystem path to sync from |
| `$properties` | No | Map of property name → value |
| `$ignoreUnknownInstances` | No | Delete instances Rojo doesn't know about (default: `false` if `$path` set, else `true`) |

Any other key in an instance description becomes a **child instance** with that name.

### Minimal example (library/plugin)
```json
{
  "name": "AwesomeLibrary",
  "tree": {
    "$path": "src"
  }
}
```

### Full game example
```json
{
  "name": "Sisyphus Simulator",
  "globIgnorePaths": ["**/*.spec.lua"],
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "$path": "src/ReplicatedStorage"
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/StarterPlayerScripts"
      }
    },
    "Workspace": {
      "$className": "Workspace",
      "$properties": { "Gravity": 67.3 }
    }
  }
}
```

---

## File → Roblox Instance Mapping

| File pattern | Roblox instance |
|---|---|
| Any directory | `Folder` |
| `*.server.lua` | `Script` |
| `*.client.lua` | `LocalScript` |
| `*.lua` | `ModuleScript` |
| `init.server.lua` | Parent dir → `Script` |
| `init.client.lua` | Parent dir → `LocalScript` |
| `init.lua` | Parent dir → `ModuleScript` |
| `*.rbxmx` | XML Model |
| `*.rbxm` | Binary Model |
| `*.csv` | `LocalizationTable` |
| `*.txt` | `StringValue` |
| `*.json` (non-model) | `ModuleScript` returning a table |
| `*.toml` | `ModuleScript` returning a table |
| `*.model.json` | JSON Model (hand-authored) |
| `*.project.json` | Nested project |
| `*.meta.json` | Metadata for adjacent file |

### JSON Module example
`config.json`:
```json
{ "speed": 16, "enabled": true }
```
Becomes a `ModuleScript` with:
```lua
return { speed = 16, enabled = true }
```

### JSON Model example (`My Tool.model.json`)
```json
{
  "ClassName": "Folder",
  "Children": [
    { "Name": "RootPart", "ClassName": "Part", "Properties": { "Size": [4, 4, 4] } },
    { "Name": "SendMoney", "ClassName": "RemoteEvent" }
  ]
}
```

---

## Meta Files (`.meta.json`)

Meta files attach extra Rojo configuration to existing files.

**`init.meta.json`** — changes a directory's class instead of Folder:
```json
{
  "className": "Tool",
  "properties": {
    "Grip": [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
  }
}
```

**`foo.meta.json`** (next to `foo.server.lua`) — sets properties on a script:
```json
{
  "properties": {
    "Disabled": true
  }
}
```

**`hello.meta.json`** (next to `hello.txt`) — sets Rojo metadata:
```json
{
  "ignoreUnknownInstances": true
}
```

---

## Instance Property Values

**Implicit** — Rojo infers type from Roblox API:
```json
{ "$className": "Part", "$properties": { "Anchored": true } }
```

**Explicit** — specify type directly (needed for unknown/new properties):
```json
{ "$className": "Part", "$properties": { "Anchored": { "Bool": true } } }
```

See full type list: https://rojo.space/docs/v7/properties/

---

## Sync Limitations

Some property types cannot be live-synced (only work via `rojo build`):
- Binary data (Terrain, CSG)
- `MeshPart.MeshId`
- `HttpService.HttpEnabled`

Full coverage: https://github.com/Roblox/rbx-dom#property-type-coverage

---

## Recommended Toolchain (VS Code)

| Tool | Purpose |
|---|---|
| [luau-lsp](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp) | LSP for Luau |
| [StyLua](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.stylua) | Code formatter |
| [Selene](https://marketplace.visualstudio.com/items?itemName=Kampfkarren.selene-vscode) | Static analysis linter |
| [roblox-ui](https://marketplace.visualstudio.com/items?itemName=filiptibell.roblox-ui) | Visual Rojo project navigator |
| [Wally](https://github.com/UpliftGames/wally) | Package manager |

---

## Uploading to Roblox.com

```bash
rojo upload --asset_id [PLACE_ID] --cookie "[.ROBLOSECURITY]"
```

- On Windows with Studio installed, `--cookie` is optional (pulled from Studio session)
- Use a dedicated deploy account, not your personal account
- Example CI/CD: [Desert Bus 2077](https://github.com/Roblox/desert-bus-2077) (GitHub Actions)

---

## Common Patterns

**Ignore test files globally:**
```json
{ "globIgnorePaths": ["**/*.spec.lua"] }
```

**Restrict live-sync to specific places (prevent accidents):**
```json
{ "servePlaceIds": [12345678] }
```

**Use a custom port:**
```json
{ "servePort": 34873 }
```

**Reuse a project inside another project:**
Place a `default.project.json` inside a directory — Rojo uses it instead of treating the directory as a plain Folder.
