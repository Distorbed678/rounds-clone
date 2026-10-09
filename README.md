# Rounds Clone

A fan-made clone of [ROUNDS](https://store.steampowered.com/app/1557740/ROUNDS/), built with [LÖVE](https://love2d.org/) 11.5. It's a 2D side-view shooter for 2 to 4 players: when you lose a round, you pick an upgrade card. Cards stack, builds get silly, and the first player to the target score wins.

- **Local play:** 2 players on one keyboard.
- **Online play:** up to 4 players over Steam, joining with a 6-character lobby code.
- **Platforms:** Windows and Linux (64-bit), plus a browser version for local play.

**▶ Play in your browser: https://distorbed678.github.io/rounds-clone/** (local 2-player; online play needs the desktop version)

> This project is not affiliated with or endorsed by Landfall Games, the makers of ROUNDS.

## Features

- **56 upgrade cards** across five rarities: 17 common, 18 uncommon, 14 rare, 5 epic and 2 legendary. They include bouncing and exploding bullets, homing, lasers, black holes, orbiting shields, revives and block abilities.
- **Every card stacks.** Stat cards add up, and ability cards get stronger with each copy (for example more back shots, bigger mine blasts or wider lasers). Each card shows what extra copies do.
- **Blocking reflects bullets** back at the shooter. The *Reflector* card sends extra bullets back.
- **Special cards:** *Reroll* (re-deals your hand), *Table Flip* (rerolls every card you own while keeping their rarities) and *Shrine of Order* (as in Risk of Rain 2: for each rarity, all your cards of that rarity become copies of one of them).
- **10 arenas**, each with spawns for 4 players.
- **Card picks in turn order:** every player except the round winner picks, lowest score first. Everyone watches the current picker's hand and sees which card they're hovering.
- **Match flow:** first to N rounds. After a win you can *Continue* (+3 rounds) or start a *New Match*. Online, players vote and the host sees the votes before choosing.
- **Custom rules:** choose how many cards are offered (2–6) and how many picks you get per round (1–5), set the chance of each rarity, and use the card pool editor to change any card's rarity or disable it. **Online, the host's rules are used.**
- **Settings:** window mode, monitor, resolution, VSync (off/on/adaptive), FPS cap, bloom, screen shake, particles and fully rebindable controls.

## Download and install

### Linux (AppImage)

1. Download `RoundsClone-x86_64.AppImage` (see [Releases](../../releases), or [build it yourself](#building-releases)).
2. Make it executable and run it:
   ```sh
   chmod +x RoundsClone-x86_64.AppImage
   ./RoundsClone-x86_64.AppImage
   ```
   If it fails to start because FUSE is missing, run `./RoundsClone-x86_64.AppImage --appimage-extract-and-run` instead.

### Windows

1. Download `RoundsClone-windows-x64.zip` (see [Releases](../../releases), or [build it yourself](#building-releases)).
2. Unzip it anywhere and run `RoundsClone\RoundsClone.exe`. Keep the DLLs next to the exe.

### Browser

Open **https://distorbed678.github.io/rounds-clone/**. Nothing to install. Both players share the keyboard, settings are saved in your browser, and the **Fullscreen** button above the game gives a bigger view. Online play isn't available in the browser, because it runs over Steam.

### Run from source

Install [LÖVE 11.5](https://love2d.org/), then from the repository root:

```sh
love .
```

On Windows, use `lovec.exe .` if you want a console window for log output.

## Controls

All controls can be rebound in **Settings → Controls**. These are the defaults:

| | Move | Jump | Aim | Fire | Block |
|---|---|---|---|---|---|
| **Local P1** | A / D | W | Facing direction; hold W / S to aim 45° up / down | Space | Left Shift |
| **Local P2** | ← / → | ↑ | Facing direction; hold ↑ / ↓ to aim 45° up / down | Right Ctrl | Right Shift |
| **Online** | A / D | Space or W | Mouse | Left click | Right click |

- **Online only:** hold **S** in the air to fast-fall.
- **Esc** opens the pause/menu screen. **F11** or **Alt+Enter** toggles fullscreen.
- **Card picks:** use your left/right keys and your fire key (local play). Online, click a card, or use A/D with Space.

## Online play (Steam)

Online play runs on Steam's networking. It uses Steam's public test app, **Spacewar (App ID 480)**, so nobody needs to own or install anything extra.

**Requirements**
- Steam must be **running and logged in before you start the game**.
- Each player needs their **own Steam account**. You can't join your own lobby from a second copy on the same account.
- Everyone needs the **same game version**. Lobbies refuse players with a different network protocol version.
- Windows and Linux players can play together.
- No port forwarding is needed, because traffic goes through Steam's relay network.

**Hosting and joining**
1. The host picks **Online Play → Host Lobby** and shares the 6-character lobby code. The **Copy Code** button helps.
2. Other players pick **Online Play**, type the code and join.
3. The host chooses *Rounds to win* and presses **Start Match** once at least 2 players are in.

Steam invites also work, but only if the friend already has the game open. The game runs as Spacewar, so Steam can't launch it for them.

## Building releases

`build.sh` builds release packages on Linux. It needs `curl`, `zip` and `unzip`, plus [Node.js](https://nodejs.org/) for the browser version.

```sh
./build.sh            # everything (the web build is skipped if Node.js isn't installed)
./build.sh linux      # AppImage only
./build.sh windows    # Windows zip only
./build.sh web        # browser version only
./build.sh love       # just the .love file
```

Output goes to `dist/`:

| File | What it is |
|---|---|
| `RoundsClone-x86_64.AppImage` | Single-file Linux executable. LÖVE's AppImage with the game and the Steam libraries inside. |
| `RoundsClone-windows-x64.zip` | `RoundsClone.exe` (LÖVE's `love.exe` with the game appended), LÖVE's DLLs and the Steam DLLs. |
| `RoundsClone.love` | The game files only. Runs anywhere with `love RoundsClone.love`, but without Steam libraries. |
| `web/` | The browser version: [love.js](https://github.com/Davidobot/love.js) (LÖVE compiled to WebAssembly) with the game, using the page in `web/index.html`. Serve the folder over HTTP to test it locally, e.g. `python3 -m http.server -d dist/web`. |

Every published GitHub release also runs `.github/workflows/pages.yml`, which builds the browser version and deploys it to GitHub Pages. You can also run that workflow by hand from the Actions tab.

The LÖVE 11.5 runtimes and `appimagetool` are downloaded once from their official GitHub releases into `build/cache/`.

## Technical details

### Project layout

```
rounds-clone/
├── main.lua, conf.lua   entry points (LÖVE needs them at the root)
├── core/                app (screen stack, virtual canvas), ui, input, settings
├── game/                world (authoritative simulation), player, bullet, cards, map
├── gfx/                 fx (particles), bloom, hud
├── online/              net (message codec), snapshot, session (Steam lobby), steam (library loader)
├── screens/             menu, settings, cards (card pool editor), online, lobby, match
├── lib/
│   ├── windows/         steam_api64.dll, luasteam.dll
│   └── linux/           libsteam_api.so, luasteam.so
├── web/index.html       the browser version's page
├── .github/workflows/   GitHub Pages deployment of the browser version
├── build.sh             release builder
└── steam_appid.txt      Spacewar app id for running from source
```

- `main.lua` adds a frame-capped `love.run`. `conf.lua` starts Steam before the window exists so the overlay can hook in.
- Everything renders to a 1280×720 virtual canvas that is letterboxed to the window.
- `game/world.lua` holds the whole match state and round flow, including the card pick queue and disconnects.

### Networking model

- **Host-authoritative.** The host runs the only simulation. Clients send their input every frame (unreliable, with sequence numbers) and render what the host sends back. Clients reuse the same `draw()` code on lightweight proxy objects.
- **Snapshots** go out about 30 times a second. They are compact binary (`love.data.pack`), lz4-compressed when large, and include particle and screen-shake events so effects look the same everywhere.
- **Reliable messages** cover match start, roster/cards, toasts, return-to-lobby and the gameplay **rules** (cards offered, picks per round, rarity weights, per-card overrides). The host sends the rules at match start and again on New Match.
- **Card picks:** the current pick (picker, hand, hover, queue) travels in every snapshot. The picker's hover rides along with their input, and their choice is tagged with a serial number so a late or duplicate click can't take the wrong card.
- **Versioning:** `session.PROTOCOL` is stored in the lobby data, and mismatched peers are refused.

### Steam libraries

| Library | Windows | Linux | Source |
|---|---|---|---|
| Steamworks API (SDK 1.65) | `lib/windows/steam_api64.dll` | `lib/linux/libsteam_api.so` | [Steamworks.NET](https://github.com/rlabrecque/Steamworks.NET) redistributables |
| luasteam v6.0.0 | `lib/windows/luasteam.dll` | `lib/linux/luasteam.so` | [uspgamedev/luasteam](https://github.com/uspgamedev/luasteam/releases/tag/v6.0.0) |

The two libraries must come from matching SDK versions. When running from source they're loaded from `lib/<platform>/`; the packaged builds keep them next to the executable. If Steam isn't running, a library is missing, or the OS isn't supported, the game falls back to offline-only play and shows the reason on the Online screen.

### Settings file

Settings are saved as plain `key=value` lines in `settings.txt`:

- **Windows:** `%APPDATA%\LOVE\rounds_clone\` when run from source, `%APPDATA%\rounds_clone\` for the packaged exe
- **Linux:** `~/.local/share/love/rounds_clone/` when run from source, `~/.local/share/rounds_clone/` for the AppImage

Key bindings are stored as `bind.<scheme>.<action>=<key>`, and card pool overrides as `card.<id>=<rarity>,<on|off>`.

### Code notes

The game runs on LuaJIT (Lua 5.1 semantics). Use the `bit` library rather than Lua 5.3+ operators. [`CLAUDE.md`](CLAUDE.md) has more detailed contributor notes, including the rules for keeping the network protocol in sync and how to write headless test harnesses.

## License

This project's source code is released under the [MIT License](LICENSE).

Bundled third-party components keep their own licenses:
- [LÖVE](https://love2d.org/) (included in the packaged builds) is under the zlib license.
- [luasteam](https://github.com/uspgamedev/luasteam) is under the MIT license.
- The Steamworks API libraries (`steam_api64.dll`, `libsteam_api.so`) are Valve redistributables covered by the [Steamworks SDK Access Agreement](https://partner.steamgames.com/documentation/sdk_access_agreement).

ROUNDS is a trademark of Landfall Games. This is an unofficial fan project.
