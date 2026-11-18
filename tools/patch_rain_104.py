#!/usr/bin/env python3
"""Install the Psych Engine 1.0.4 rain in Limul Engine.

Two things happen here:

1. assets/shaders/limulRain104.frag (already written by hand in bin/assets) is mirrored into
   assets/preload/shaders/, so the next build ships it. PlayState/FunkinLua were patched to
   also search Paths.getPreloadPath('shaders/'), which is why it can live in the asset tree
   instead of mods/shaders/.

2. data/<song>/rain.lua is regenerated for the four Weekend 1 songs from one template. The
   script drives the shader (1.0.4's own RainShader math) and keeps a sprite-pool rain as the
   fallback for when runtime shaders are unavailable - Options -> Shaders is OFF by default on
   a fresh Limul save (ClientPrefs.loadPrefs), and the shader only exists after a rebuild, so
   without the fallback those songs would simply stop raining.

Trees written: export/release/windows/bin/assets/data/<song>/  (live) and
assets/preload/data/<song>/  (build source). example_mods/ is deliberately NOT touched: its
weekend1 copy is a dead mirror and mods/data/<song>/*.lua would SHADOW the assets copy
(PlayState.hx:1275 checks mods/ before assets/), so extra copies there are a bug, not a backup.

Usage:
    python tools/patch_rain_104.py            # write (backs up every replaced file)
    python tools/patch_rain_104.py --check     # report what differs, write nothing
"""

import os
import shutil
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(ROOT, "export", "release", "windows", "bin")
LIVE = os.path.join(BIN, "assets", "data")
SRC = os.path.join(ROOT, "assets", "preload", "data")
FRAG_LIVE = os.path.join(BIN, "assets", "shaders", "limulRain104.frag")
FRAG_SRC = os.path.join(ROOT, "assets", "preload", "shaders", "limulRain104.frag")

STAMP = time.strftime("%y%m%d-%H%M%S")
BACKUP = os.path.join(ROOT, "_backup_rain104_" + STAMP)

# per song: uIntensity (1.0.4's uniform), fallback pool size, camera-zoom fallback from the
# stage json, and whether notes drive rainTimeScale (states/stages/PhillyBlazin.hx has the
# field; PhillyStreets.setupRainShader does not touch it).
SONGS = [
    # song        start  end    pool   zoom   surge
    # 1.0.4 ramps intensity from start to end over the song length in PhillyStreets.hx:507-515
    # (darnell 0.0->0.1, lit-up 0.1->0.2, 2hot 0.2->0.4). PhillyBlazin.hx:162 keeps 0.5 constant
    # and instead speeds uTime up on hits, which is what "surge" reproduces.
    ("darnell",    0.0,   0.1,   0.35,  0.77,  False),
    ("lit-up",     0.1,   0.2,   0.55,  0.77,  False),
    ("2hot",       0.2,   0.4,   0.75,  0.77,  False),
    ("blazin",     0.5,   0.5,   1.00,  0.75,  True),
]

TEMPLATE = r'''-- Limul Engine - @SONG@ rain, rebuilt to match Psych Engine 1.0.4.
--
-- 1.0.4 does not script this week in Lua: states.stages.PhillyStreets / PhillyBlazin are Haxe
-- classes and both call setupRainShader(), which attaches shaders/RainShader.hx to the game
-- camera with uScale = FlxG.height / 200. Intensity is constant on Blazin' (0.5) and ramped over
-- the song length on the street stages (see SONGS below). The GLSL drop math is preserved verbatim
-- in assets/shaders/rain_104_reference.frag and re-issued for a sprite (flixel 5.5.0 has no
-- camera shader) as assets/shaders/limulRain104.frag. This file is the driver: it pins a
-- full-view quad to the camera, feeds the four uniforms and advances uTime.
--
-- Shader first, pool second. Paths.getPreloadPath('shaders/') was added to
-- PlayState.initLuaShader()'s search list, so the .frag is read from the asset tree at runtime
-- (no rebuild needed for shader tweaks). initLuaShader() returns false when Options -> Shader
-- Graphics is off or when the exe predates runtime-shader support, and then the old sprite
-- pool takes over so the song never ends up rain-free.

local TAG = 'limulRain104'
local SHADER = 'limulRain104'

local START_INTENSITY = @START@   -- 1.0.4 uIntensity at song start (PhillyStreets.hx:507-515 / PhillyBlazin.hx:162)
local END_INTENSITY = @END@       -- 1.0.4 lerps start->end over the music length; equal values = no ramp
local POOL_SCALE = @POOL@            -- sprite-pool budget when the shader is unavailable
local FALLBACK_ZOOM = @ZOOM@         -- phillyStreets/phillyBlazin.json defaultZoom
local NOTE_SURGE = @SURGE@           -- PhillyBlazin.hx rainTimeScale (+0.7 per good note)

-- 1.0.4's RainShader layers; scales[] from main(), alphas/counts are the pool's own budget.
local LAYERS = {
    {s = 1.0, n = 14, a = 0.16},
    {s = 1.8, n = 34, a = 0.19},
    {s = 2.6, n = 52, a = 0.23},
    {s = 4.8, n = 78, a = 0.27}
}
local STEPS = {0.02, 0.05, 0.09, 0.15, 0.22, 0.30}
local STEP_MAX = 0.30

local shaderOn = false
local uScale = 3.6
local uTime = 0
local rect = {x = 0, y = 0, w = 0, h = 0}
local rainTimeScale = 1
local speedStep = -1
local lastIntensity = -1

local drops = {}
local dropCount = 0

local function num(value, fallback)
    if type(value) == 'number' and value == value then
        return value
    end
    return fallback
end

-- getProperty can only reach what PlayState exposes; camGame is a public PlayState field
-- (PlayState.hx:216), so the Reflect fallback inside getObjectDirectly finds it. Wrapped in
-- pcall because a nil read here would otherwise abort the whole update.
local function readPlayStateVar(name, fallback)
    local ok, value = pcall(getProperty, name)
    if ok then return num(value, fallback) end
    return fallback
end

local function readCam(name, fallback)
    return readPlayStateVar('camGame.' .. name, fallback)
end

--------------------------------------------------------------------------------
-- shader path
--------------------------------------------------------------------------------

-- rect is the visible world area plus a margin: for the shader it is the sprite's own rect and
-- the uWorldRect uniform, for the pool it is the wrap-around area (a scrollFactor-0 sprite uses
-- the same units, screen px divided by zoom).
local function computeRect()
    local left = readCam('viewLeft', -1)
    local top = readCam('viewTop', -1)
    local right = readCam('viewRight', -1)
    local bottom = readCam('viewBottom', -1)
    if right <= left or bottom <= top then
        -- no usable bounds (older save, odd camera state): derive the view from the zoom
        local zoom = readCam('zoom', readPlayStateVar('defaultCamZoom', FALLBACK_ZOOM))
        if zoom < 0.05 then zoom = FALLBACK_ZOOM end
        local w = screenWidth / zoom
        local h = screenHeight / zoom
        left = readCam('scrollX', w * 0.5) - w * 0.5
        top = readCam('scrollY', h * 0.5) - h * 0.5
        right = left + w
        bottom = top + h
    end
    -- 12% margin keeps the streaks on screen while the camera lerps after a boop
    local padX = (right - left) * 0.12
    local padY = (bottom - top) * 0.12
    rect.x = left - padX
    rect.y = top - padY
    rect.w = (right - left) + padX * 2
    rect.h = (bottom - top) + padY * 2
end

local function applyRect()
    setProperty(TAG .. '.x', rect.x)
    setProperty(TAG .. '.y', rect.y)
    -- the graphic is 2x2, so the scale factor is the size over 2
    scaleObject(TAG, rect.w * 0.5, rect.h * 0.5, false)
    setShaderFloatArray(TAG, 'uWorldRect', {rect.x, rect.y, rect.w, rect.h})
end

local function pinToCamera()
    computeRect()
    applyRect()
end

local function pushShaderUniforms()
    local ramp = 0
    local ok, percent = pcall(getProperty, 'songPercent')
    if ok and type(percent) == 'number' then
        ramp = num(percent, 0)
        if ramp < 0 then ramp = 0 elseif ramp > 1 then ramp = 1 end
    end
    -- 1.0.4: FlxMath.remapToRange(Conductor.songPosition, 0, music.length, start, end);
    -- Limul's PlayState.hx:3295 songPercent is exactly curTime / songLength.
    local intensity = START_INTENSITY + (END_INTENSITY - START_INTENSITY) * ramp
    if intensity ~= lastIntensity then
        lastIntensity = intensity
        setShaderFloat(TAG, 'uIntensity', intensity)
    end
    setShaderFloat(TAG, 'uScale', uScale)
    setShaderFloat(TAG, 'uTime', uTime)
end

--------------------------------------------------------------------------------
-- sprite-pool fallback (kept from the previous revision of this file)
--------------------------------------------------------------------------------

local function stepFor(value)
    local chosen = 1
    for i = 1, #STEPS do
        if value >= STEPS[i] then chosen = i end
    end
    return chosen
end

local function applyPoolStep(step)
    speedStep = step
    local t = STEPS[step]
    local strain = t / STEP_MAX
    for i = 1, dropCount do
        local d = drops[i]
        d.vy = d.baseVy * t
        d.vx = d.vy * 0.1
        scaleObject(d.n, d.w, d.h * (1 + strain * 2.2), false)
        setProperty(d.n .. '.alpha', d.a * (0.7 + strain * 0.8))
        setProperty(d.n .. '.velocity.x', d.vx)
        setProperty(d.n .. '.velocity.y', d.vy)
    end
end

local function buildPool()
    dropCount = 0
    for li = 1, #LAYERS do
        local layer = LAYERS[li]
        local count = math.floor(layer.n * POOL_SCALE)
        if lowQuality then count = math.floor(count / 2) end
        if count < 3 then count = 3 end

        local w = 2.5 * uScale / layer.s
        local h = 133 * uScale / layer.s
        local vy = 5000 * uScale / (layer.s * layer.s)

        for i = 1, count do
            dropCount = dropCount + 1
            local name = 'limulRainP' .. dropCount
            makeLuaSprite(name, 'limul/rainStreak', 0, 0)
            addLuaSprite(name, true)
            setObjectCamera(name, 'game')
            setScrollFactor(name, 0, 0)
            setProperty(name .. '.angle', -5.71)

            local d = {
                n = name, w = w, h = h, a = layer.a, baseVy = vy, vy = 0, vx = 0,
                x = math.random() * rect.w,
                y = math.random() * (rect.h + h) - h
            }
            drops[dropCount] = d
            setProperty(name .. '.x', d.x)
            setProperty(name .. '.y', d.y)
            scaleObject(name, w, h, false)
        end
    end
    speedStep = -1
    applyPoolStep(stepFor(math.min(rainTimeScale, STEP_MAX)))
end

local function updatePool(elapsed)
    rainTimeScale = 0.02 + (math.min(1, rainTimeScale) - 0.02) * math.exp(-elapsed * 3)
    local step = stepFor(math.min(rainTimeScale, STEP_MAX))
    if step ~= speedStep then applyPoolStep(step) end

    for i = 1, dropCount do
        local d = drops[i]
        d.y = d.y + d.vy * elapsed
        d.x = d.x + d.vx * elapsed
        if d.y - d.h > rect.h or d.x > rect.w + 60 then
            d.y = -d.h - math.random() * 160
            d.x = math.random() * rect.w
            setProperty(d.n .. '.y', d.y)
            setProperty(d.n .. '.x', d.x)
        end
    end
end

--------------------------------------------------------------------------------
-- callbacks
--------------------------------------------------------------------------------

function onCreate()
    uScale = screenHeight / 200
    computeRect()

    if type(initLuaShader) == 'function' and type(setSpriteShader) == 'function'
        and type(setShaderFloat) == 'function' and type(setShaderFloatArray) == 'function' then
        local okInit, gotShader = pcall(initLuaShader, SHADER)
        if okInit and gotShader == true then
            makeLuaSprite(TAG, '', rect.x, rect.y)
            makeGraphic(TAG, 2, 2, 'ffffff')
            addLuaSprite(TAG, true)
            setObjectCamera(TAG, 'game')
            scaleObject(TAG, rect.w * 0.5, rect.h * 0.5, false)
            -- keep it invisible until the shader is really on it: a 2x2 white graphic scaled to
            -- the whole view would otherwise paint the screen white (or black) when
            -- setSpriteShader() fails on a shader that initLuaShader() did find.
            setProperty(TAG .. '.alpha', 0)
            local okSet, attached = pcall(setSpriteShader, TAG, SHADER)
            shaderOn = (okSet and attached == true)
            if shaderOn then
                setProperty(TAG .. '.alpha', 1)
                applyRect()
                pushShaderUniforms()
            else
                removeLuaSprite(TAG, true)
            end
        end
    end

    if not shaderOn then
        buildPool()
    end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if inGameOver then return end
    if not NOTE_SURGE then return end
    -- states/stages/PhillyBlazin.hx: rainTimeScale += 0.7 on every good hit
    rainTimeScale = rainTimeScale + 0.7
end

function onUpdate(elapsed)
    if elapsed <= 0 then return end

    if shaderOn then
        local tScale = 1
        if NOTE_SURGE then
            rainTimeScale = 0.02 + (math.min(1, rainTimeScale) - 0.02) * math.exp(-elapsed * 3)
            tScale = math.max(0.02, math.min(1.7, rainTimeScale))
        end
        uTime = uTime + elapsed * tScale
        pinToCamera()
        pushShaderUniforms()
    else
        updatePool(elapsed)
    end
end
'''


def read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def backup(path):
    if not os.path.isfile(path):
        return None
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    dest = os.path.join(BACKUP, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copy2(path, dest)
    return dest


def main():
    check_only = "--check" in sys.argv

    if not os.path.isfile(FRAG_LIVE):
        print("FATAL: missing %s (write the shader first)" % FRAG_LIVE)
        return 1

    frag_text = read(FRAG_LIVE)
    same_frag = os.path.isfile(FRAG_SRC) and read(FRAG_SRC) == frag_text
    print("[1] limulRain104.frag  bin/assets -> assets/preload : %s"
          % ("already mirrored" if same_frag else "COPY"))
    if not same_frag and not check_only:
        backup(FRAG_SRC)
        write(FRAG_SRC, frag_text)

    patched = 0
    for song, start, end, pool, zoom, surge in SONGS:
        text = (TEMPLATE
                .replace("@SONG@", song)
                .replace("@START@", "%s" % start)
                .replace("@END@", "%s" % end)
                .replace("@POOL@", "%s" % pool)
                .replace("@ZOOM@", "%s" % zoom)
                .replace("@SURGE@", "true" if surge else "false"))
        for folder in (LIVE, SRC):
            path = os.path.join(folder, song, "rain.lua")
            changed = (not os.path.isfile(path)) or read(path) != text
            print("[2] data/%s/rain.lua : %s" % (song, "WRITE" if changed else "identical"))
            if changed and not check_only:
                backup(path)
                write(path, text)
                patched += 1

    if check_only:
        print("\ncheck-only run, nothing written")
    else:
        print("\nwrote %d file(s); originals backed up in %s"
              % (patched, os.path.relpath(BACKUP, ROOT) if patched else "n/a"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
