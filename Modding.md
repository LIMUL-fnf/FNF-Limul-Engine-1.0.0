# Modding FNF Limul Engine

Limul uses Psych Engine's mod system: every mod is a folder whose files shadow the base game's
assets, plus optional Lua scripts. No source recompile is needed to add songs, characters, stages,
weeks, events, note types or shaders.

## Enabling a mod

1. Put the mod folder in `mods/` (source build) or `export/release/windows/bin/mods/` (release build).
2. Add a line to `modsList.txt` in the same directory:

   ```
   my-mod|1
   ```

   `1` enables the mod, `0` keeps it installed but disabled. Save the file without a BOM.
3. Restart the game. The folder name is case-sensitive on some platforms, so copy it exactly.

`example_mods/` is an empty skeleton with the full folder layout. `mods/Weekend 1` is a complete
real-world example (charts, characters, stages, events, per-song Lua).

## Folder map

| Folder | Contents |
| --- | --- |
| `characters/` | Character JSONs (sprite path, scale, animations, offsets) |
| `custom_events/` | Event JSONs available in the chart editor |
| `custom_notetypes/` | Note type definitions, including Lua-driven notetypes |
| `data/<song>/` | Charts: `<song>.json`, `<song>-easy.json`, `<song>-hard.json`, `<song>-erect.json`, `events.json`, `script.lua` |
| `data/` | `characterList.txt`, `credits.txt`, `introText.txt` |
| `fonts/` | Custom fonts used by `Paths.font()` |
| `images/` | Every image/atlas the mod overrides (icons, menus, notes, characters) |
| `music/` | Looping menu/other music |
| `songs/<song>/` | `Inst.ogg` and `Voices.ogg` |
| `sounds/` | One-shot sound effects |
| `stages/` | Stage JSONs and optional `.lua` stage scripts |
| `videos/` | Videos played through hxCodec |
| `weeks/` | Week JSONs (song list, week characters, background, colors) |
| `scripts/` | Global Lua scripts loaded with the mod |
| `shaders/` | Custom GLSL fragment shaders |
| `pack.json` | Legacy mod metadata: `name`, `description`, `restart`, `runsGlobally`, `color` |

Path overrides work for any asset the engine loads: a file in `mods/my-mod/images/noteSkins/...`
replaces the same relative path from `assets/`, without touching `assets/` or `export/`.

## Charts

- Standard Psych JSON (same schema as Psych 0.6.3 / 1.0) in `data/<song>/`.
- Charts tagged `"format": "psych_v1..."` (Psych 1.0.x / V-Slice exports such as the original
  Weekend 1 files) are converted at load time by `Song.convertFromPsychV1()`, so they can be
  dropped in unchanged.
- Difficulty suffixes are appended to the base chart name (`-easy`, `-hard`, `-erect`).
- `events.json` in the same folder holds the song's event track.

## Characters

Character JSONs use the Psych format: an image/atlas path, frame grid, scale, flip flag, camera
offsets and an `animations` array with per-animation name, prefix, frame indices and framerate.
Reference a character from a chart's `player1`/`player2`, from a week's `weekCharacters`, or from
Lua with `addCharacterToList`.

## Stages

A stage is a JSON description (layers, sprites, positions, scroll factors, optional animated
props) plus an optional Lua script with the same base name. Both live in `stages/`. Events and
Lua can swap backgrounds at runtime with `changeStage`/event calls.

## Lua scripting

Songs, weeks, stages and the mod itself can run Lua. Per-song scripts live in
`data/<song>/script.lua`, stage scripts next to the stage JSON, global scripts in `scripts/`.

Common callbacks (Psych 0.6.3 set):

- `onCreate`, `onCreatePost`, `onUpdate`, `onUpdatePost`, `onDestroy`
- `onSongStart`, `onEndSong`, `onStartCountdown`, `onCountdownTick`
- `onBeatHit`, `onStepHit`, `onSectionHit`
- `goodNoteHit`, `opponentNoteHit`, `noteMiss`, `noteMissPress`
- `onEvent`, `onPause`, `onResume`, `onKeyPress`, `onKeyRelease`

Usable from Lua: `makeLuaSprite` / `makeAnimatedLuaSprite` / `makeGraphic`, `addLuaSprite`,
`setProperty` / `getProperty`, `addHaxeLibrary`, `runHaxeCode`, `precacheImage` / `precacheSound`,
`playSound`, `triggerEvent`, `setOnLuas` / `callOnLuas`, `doTweenX/Y/Angle/Alpha`, and the rest of
the Psych 0.6.3 Lua API. Lua is only available when `LUA_ALLOWED` is kept in `project.xml`.

## Testing

Run a debug build (`lime test windows`) for on-screen errors and the log window. Press **F3** for
the advanced FPS counter (state, song, BPM, step, stage) and enable **Show FPS** in
Options → HUD for the FPS/memory readout. Crash logs are written to the `crash/` and `logs/`
folders next to the executable.
