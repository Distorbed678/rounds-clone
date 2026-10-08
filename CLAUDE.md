# ROUNDS clone (LÖVE 11.5 / LuaJIT)

A clone of the game ROUNDS: 2D side-view duels where the round loser picks an upgrade card. Local play is 2 players on one keyboard. Online play supports up to 4 players over Steam (AppID 480 "Spacewar").

## Running and checking
- LÖVE 11.5 is installed at `%LOCALAPPDATA%\Programs\love-11.5-win64` (`love.exe`, plus `lovec.exe`, which prints to the console). Run it with `love .` from the repo root.
- Lua 5.4 is at `%LOCALAPPDATA%\Programs\Lua\bin`. Use `luac.exe -p file.lua` only for syntax checks. The game itself runs on **LuaJIT (Lua 5.1)**, so don't use `//`, `&`/`|` or `goto`-heavy 5.4 features. Use the `bit` library and `love.data.pack`.
- Steam is **not installed** on the dev PC, so real online play can't be tested there. `steam.lua` fails gracefully with "Steam is not running".

## Architecture
| File | Role |
|---|---|
| `main.lua` / `conf.lua` | Entry points. `conf.lua` calls `steam.init()` before the window exists so the Steam overlay can hook. |
| `app.lua` | Screen stack (`switch`/`push`/`pop`). Everything renders to a 1280×720 virtual canvas that is letterboxed to the window. `app.mouse()` returns virtual coordinates. |
| `ui.lua` | Immediate-mode widgets (`button`, `cycler`, `textField`, `panel`). Only the top screen's widgets get input. Arrows/Enter for navigation. |
| `screens/` | `menu`, `settings` (overlay), `online` (host / join by code), `lobby`, `match`. |
| `world.lua` | **Authoritative simulation**: players, bullets, wells, round flow (`countdown → playing → roundOver → cardPick → matchOver`), card picks for N players, continue/new match, disconnects. It emits `world.on.{toast,roster,pick,matchOver}`. |
| `player.lua` / `bullet.lua` | Gameplay. Players read `self.input` (see `input.lua`), never the keyboard directly. `self.game` is the World. |
| `cards.lua` | Card list with rarities and specials (`reroll`, `tableflip`, `shrine`). `card.index` is used over the network. |
| `input.lua` | Input sources: `keys(controls)` (local), `mouse()` (online: WASD/Space, mouse aim, LMB/RMB), `remote()`. Jump and block use **press counters** (`jumpCount`, `blockCount`), not events. |
| `net.lua` | Binary message codec (`love.data.pack`) plus `net.loopback(loss)`, an in-process transport for tests. |
| `snapshot.lua` | Host→client world snapshots (~30 Hz, lz4 when large), including fx events. |
| `session.lua` / `steam.lua` | Steam lobby (create, join by code via lobby-list filters, invites, members) and the NetworkingMessages transport. `steam.lua` loads `steam_api64.dll` via ffi, then `luasteam.dll`. |
| `fx.lua`, `bloom.lua`, `hud.lua`, `map.lua`, `settings.lua` | Particles (with network recorder), bloom pass, HUD/card drawing, arenas, persisted settings. |

### Online model
- The host runs `World`, applies remote inputs (INPUT packets with sequence numbers), and broadcasts snapshots.
- Clients don't simulate. They build proxy tables with the `Player`/`Bullet` metatables and reuse the same `draw()` code.
- **If you add a field that `Player:draw`/`Bullet:draw` reads, add it to `snapshot.lua` and `Match:applySnapshot`**, or clients won't see it.
- Card picks: the host deals cards and sends PICK to each picker, and clients reply with CHOOSE.

## Rules and gotchas
- **Bump `session.PROTOCOL`** whenever the wire format, card order (`Cards.list` indices) or map list changes. Peers with different versions refuse to join.
- New gameplay effects must work with up to 4 players. Use `world:enemiesOf(p)` and `world:nearestEnemy(p, x, y)`, never assume a single opponent.
- Every map needs 4 spawns (`spawns[1..4]`).
- `fx.*` calls on the host are recorded into `fx.recorder` and replayed on clients. Keep fx calls deterministic in shape (`burst`, `ring`, `addShake`, `clear`).
- Steam binaries must match an SDK version. Currently `luasteam.dll` is **v6.0.0** (built for SDK 1.65) and `steam_api64.dll` is SDK **1.65**, taken from the Steamworks.NET repo. A mismatch shows up as "The specified procedure could not be found".
- Settings are saved to `%APPDATA%\LOVE\rounds_clone\settings.txt`.

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
Windows 11. Builds the game in feature batches and asks for many features at once. Wants the game to keep a ROUNDS feel. Local controls are fixed: P1 WASD, Space fire, L-Shift block; P2 arrows, R-Ctrl fire, R-Shift block.
