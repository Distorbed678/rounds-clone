# Rounds Clone (LÖVE 11.5 / LuaJIT)

A clone of the game ROUNDS: 2D side-view duels where the round loser picks an upgrade card. Local play is 2 players on one keyboard. Online play supports up to 4 players over Steam (AppID 480 "Spacewar").

## Running and checking
- **Linux dev machine (current):** `love` 11.5 and `luajit` are on the PATH and Steam is installed. Run with `love .` from the repo root. Check syntax with `luajit -bl file.lua > /dev/null`. Headless harnesses run with `love <harnessDir>`. Save folder: `~/.local/share/love/rounds_clone/`.
- **Windows PC:** LÖVE 11.5 is at `%LOCALAPPDATA%\Programs\love-11.5-win64` (`love.exe`, plus `lovec.exe`, which prints to the console), and Lua 5.4's `luac.exe -p` works for syntax checks. Steam is **not installed** there.
- The game runs on **LuaJIT (Lua 5.1)**, so don't use `//`, `&`/`|` or other 5.4 features. Use the `bit` library and `love.data.pack`.
- Without Steam (or on an unsupported OS) `steam.lua` fails gracefully and online play is disabled.

## Building releases
`./build.sh [all|linux|windows|love]` (Linux; needs curl, zip, unzip) writes to `dist/`:
- `RoundsClone.love`: the game files (everything except `*.dll`, `*.so`, `*.md`, `*.sh`, build output).
- `RoundsClone-x86_64.AppImage`: LÖVE's AppImage with `RoundsClone.love` and the Steam `.so` files at the AppDir root. `FUSE_PATH` is set in `AppRun`, so the game runs fused.
- `RoundsClone-windows-x64.zip`: `RoundsClone.exe` (love.exe with the .love appended), LÖVE's DLLs and the Steam DLLs.

The LÖVE runtimes and appimagetool are downloaded once into `build/cache/` (gitignored). If you add asset folders, make sure `build_love` doesn't exclude them.

## Architecture
| File | Role |
|---|---|
| `main.lua` / `conf.lua` | Entry points. `conf.lua` calls `steam.init()` before the window exists so the Steam overlay can hook. |
| `app.lua` | Screen stack (`switch`/`push`/`pop`). Everything renders to a 1280×720 virtual canvas that is letterboxed to the window. `app.mouse()` returns virtual coordinates. |
| `ui.lua` | Immediate-mode widgets (`button`, `cycler`, `textField`, `panel`). Only the top screen's widgets get input. Arrows/Enter for navigation. |
| `screens/` | `menu`, `settings` (overlay with Video / Controls / Gameplay tabs), `cards` (card pool editor, pushed from settings), `online` (host / join by code), `lobby`, `match`. |
| `world.lua` | **Authoritative simulation**: players, bullets, wells, round flow (`countdown → playing → roundOver → cardPick → matchOver`), sequential card picks (`pickQueue` → `pick`, lowest score first, `picksPerRound` each), continue/new match, disconnects. `World.rules` holds the gameplay rules. It emits `world.on.{toast,roster,pick,matchOver}`. |
| `player.lua` / `bullet.lua` | Gameplay. Players read `self.input` (see `input.lua`), never the keyboard directly. `self.game` is the World. |
| `cards.lua` | Card list with rarities and specials (`reroll`, `tableflip`, `shrine`). `card.index` is used over the network and `card.id` (from the name) in the settings file. `Cards.applyRules(rules)` sets each card's current `rarity`/`disabled` and the rarity weights used by `deal`; `card.baseRarity` is the default. |
| `input.lua` | Input sources: `keys(binds)` (local), `mouse(binds)` (online, mouse aim), `remote()`. Bindings are the live `Settings.values.binds.{p1,p2,online}` tables (keys or `mouse1`..`mouse5`). Jump and block use **press counters** (`jumpCount`, `blockCount`), not events. `pickHover` carries the picker's selection to the host. |
| `net.lua` | Binary message codec (`love.data.pack`) plus `net.loopback(loss)`, an in-process transport for tests. |
| `snapshot.lua` | Host→client world snapshots (~30 Hz, lz4 when large), including fx events. |
| `session.lua` / `steam.lua` | Steam lobby (create, join by code via lobby-list filters, invites, members) and the NetworkingMessages transport. `steam.lua` loads the Steam API via ffi (`steam_api64.dll` / `libsteam_api.so`, globally), then `require`s `luasteam` (`.dll` / `.so`) from the same folder: the repo, or the executable's folder in a fused build. |
| `fx.lua`, `bloom.lua`, `hud.lua`, `map.lua`, `settings.lua` | Particles (with network recorder), bloom pass, HUD/card drawing, arenas, persisted settings. |

### Online model
- The host runs `World`, applies remote inputs (INPUT packets with sequence numbers), and broadcasts snapshots.
- Clients don't simulate. They build proxy tables with the `Player`/`Bullet` metatables and reuse the same `draw()` code.
- **If you add a field that `Player:draw`/`Bullet:draw` reads, add it to `snapshot.lua` and `Match:applySnapshot`**, or clients won't see it.
- Card picks are sequential. The current pick (slot, serial, hover, options, queue) travels in every snapshot so everyone watches it. The picker's hover rides in INPUT (`pickHover`) and the choice is CHOOSE(index, serial); a stale serial is ignored.
- Gameplay rules (cards offered, picks per round, rarity weights, per-card rarity/disabled) come from the **host's** settings: the host sends RULES after START and again on New Match, and clients call `Cards.applyRules`. Local play and the host build them with `Settings.cardRules()`.

## Rules and gotchas
- **Bump `session.PROTOCOL`** whenever the wire format, card order (`Cards.list` indices) or map list changes. Peers with different versions refuse to join.
- New gameplay effects must work with up to 4 players. Use `world:enemiesOf(p)` and `world:nearestEnemy(p, x, y)`, never assume a single opponent.
- Every map needs 4 spawns (`spawns[1..4]`).
- `fx.*` calls on the host are recorded into `fx.recorder` and replayed on clients. Keep fx calls deterministic in shape (`burst`, `ring`, `addShake`, `clear`).
- Steam binaries must match an SDK version. Currently `luasteam.dll` / `luasteam.so` are **v6.0.0** (luasteam GitHub release, built for SDK 1.65). `steam_api64.dll` / `libsteam_api.so` are SDK **1.65**, taken from Steamworks.NET `com.rlabrecque.steamworks.net/Plugins/`. A mismatch shows up as "The specified procedure could not be found" (Windows) or an undefined-symbol error (Linux). Windows and Linux players can play together.
- Settings are saved to `%APPDATA%\LOVE\rounds_clone\settings.txt` (flat `key=value`, plus `bind.<scheme>.<action>=key` and `card.<id>=<rarity>,<on|off>` lines). `Settings.resetBinds` mutates in place because input states hold references to the bind tables.
- `main.lua` overrides `love.run` to add the max-FPS cap. F11 / Alt+Enter toggle fullscreen globally.

## Testing approach (headless, no Steam needed)
Put test harnesses in the session scratchpad, not the repo. Pattern:
```lua
package.path = "<repo>/?.lua;" .. package.path
dofile("<repo>/main.lua")          -- defines love.load/update/draw; call them yourself
love.keyboard.isDown = function(...) ... end   -- fake input
```
- **Local/UI:** drive `love.keypressed`, read state with `require("app").base()`, and screenshot with `love.graphics.captureScreenshot`.
- **Network:** `hub = net.loopback(0.1)`, then `Match.newClient(slots, i, winScore, hub:endpoint(id), "H", nil, {popEvents=fn})` and `Match.newHost(slots, winScore, hub:endpoint("H"), {popEvents=fn})`. Construct clients **before** the host, because `newClient` resets `fx.recorder`. Set `fx.recorder = nil` while updating clients, and compare client proxies with `host.world.players`.
- Run with `lovec.exe <harnessDir>` and a timeout, then check the screenshots by viewing them.

## About the user
Develops on Linux (CachyOS) now; previously Windows 11. Builds the game in feature batches and asks for many features at once. Wants the game to keep a ROUNDS feel. Controls are rebindable in Settings; the defaults are P1 WASD, Space fire, L-Shift block; P2 arrows, R-Ctrl fire, R-Shift block.
