-- weekend-1-firegun.lua -- Limul Engine (Psych 0.6.3) custom note type for the V-Slice Weekend 1 charts.
--
-- Chart string: 'weekend-1-firegun' -- Pico fires (shot1..4, random, see LIMUL-SHOT-SFX).
-- Psych uses this string verbatim as the script name (ChartingState fills its dropdown from
-- mods/custom_notetypes/ and PlayState loads the same path at gameplay), so the file name is part
-- of the note type.
--
-- WHAT IT DOES (1.0.4 / JS Engine parity).
--   * plays 'shoot' on the fighter that owns the note and one of the four shot takes;
--   * spraycan.playCanShot(): the native JS can (source/SpraycanAtlasSprite.hx) plays 'Can Shot'
--     and disappears from the street;
--   * the shot pulls the light out of the block for a beat (LIMUL-DARKEN-PROPS, 1.0.4
--     PhillyStreets.hx:843-846 and :999-1012);
--   * a missed firegun note is the only can damage in the week: 0.4 health (PhillyStreets.hx:971),
--     the can flinch, the bonk and the blink (LIMUL-PICO-FLICKER). Nothing is spawned in Lua --
--     the can is one native FlxAnimate and the old PicoBullet was cosmetic.

local TYPE = 'weekend-1-firegun'

local ANIMS = {'shoot'}
local MISS_ANIMS = {}
-- LIMUL-SHOT-SFX: this type used to fire 'Shoot_1', which is digital silence (peak -82dBFS), so
-- every shot note was mute. 1.0.4 plays Paths.soundRandom('shots/shot', 1, 4) (PhillyStreets.hx:331
-- and :840); this fork carries the four takes flat as sounds/shot1..4.ogg. Random per hit so a
-- burst of shots is not one looping sample.
local HIT_SOUND = nil
local HIT_SOUNDS = {'shot1', 'shot2', 'shot3', 'shot4'}

local function hitSoundName()
    if HIT_SOUNDS ~= nil and #HIT_SOUNDS > 0 then return HIT_SOUNDS[getRandomInt(1, #HIT_SOUNDS)] end
    return HIT_SOUND
end

local DAMAGE = 0.4
local IMPACT_SOUND = 'Pico_Bonk'

local HURT_ANIMS  = {'shootMISS', 'CanHit'}   -- first name the character actually has wins.
                                   -- 'shootMISS' is 1.0.4's spelling (PhillyStreets.hx:933); this
                                   -- fork's pico-playable.json only defines 'CanHit' (prefix
                                   -- "Pico Hit Can"), and playAnim() on a missing name is a silent
                                   -- no-op. pico-blazin has neither -- Blazin's hit reactions come
                                   -- from the stage fight choreography.

local rotate = 0

local function currentAnim(obj)
    local ok, name = pcall(getProperty, obj..'.animation.curAnim.name')
    if ok and name ~= nil then return name end
    ok, name = pcall(getProperty, obj..'.atlas.anim.lastPlayedAnim')
    if ok then return name end
    return nil
end

-- playAnim() says nothing about whether the animation existed, so read the name back.
local function tryAnim(obj, name)
    playAnim(obj, name, true)
    return currentAnim(obj) == name
end

-- Returns the name that actually played (nil when the character has none of them), because the
-- flicker below needs to know which animation it is waiting to finish.
local function tryAnims(obj, names)
    for i = 1, #names do
        if tryAnim(obj, names[i]) then return names[i] end
    end
    return nil
end

-- LIMUL-PICO-FLICKER: 1.0.4 PhillyStreets.hx:927-969. When a firegun note is missed the can lands,
-- shootMISS plays, and once that animation is over Pico blinks: 30 visibility toggles at 1/30s,
-- then 30 more at 1/60s, always finishing on visible = true. 0.6.3 has no onAnimationComplete Lua
-- callback, so the end of the animation is polled with currentAnim. FLICKER_MAX_WAIT is the safety
-- valve: if the read never changes, or the character has no hurt animation at all (pico-blazin),
-- the blink starts on the clock instead of never happening.
--
-- Nothing can leave Pico missing: the sequence forces visible = true between phases, at the end,
-- when a new impact arrives (flickerStop) and from onGameOver.
local PICO_FLICKER     = true
local FLICKER_STEP_A   = 1 / 30
local FLICKER_LOOPS_A  = 30
local FLICKER_STEP_B   = 1 / 60
local FLICKER_LOOPS_B  = 30
local FLICKER_MAX_WAIT = 1.2
local FLICKER_TARGET   = 'boyfriend'

local flicker = nil

local function isVisible()
    local ok, v = pcall(getProperty, FLICKER_TARGET .. '.visible')
    if ok then return v == true end
    return true
end

local function setVisible(state)
    pcall(setProperty, FLICKER_TARGET .. '.visible', state and true or false)
end

local function flickerStop()
    if flicker == nil then return end
    flicker = nil
    setVisible(true)
end

-- 1.0.4 gates the blink on game.health > 0.0, !game.practiceMode and game.gameOverTimer == null.
-- 'practice' and 'inGameOver' are the two globals 0.6.3 pushes for those, and getHealth() is the bar.
local function flickerStart(hurtAnim)
    if not PICO_FLICKER then return end
    if inGameOver then return end
    if practice then return end
    if not isVisible() then return end
    local ok, h = pcall(getHealth)
    if not ok or type(h) ~= 'number' or h <= 0 then return end
    flicker = {anim = hurtAnim, pending = true, wait = 0, phase = 1,
               step = FLICKER_STEP_A, left = FLICKER_LOOPS_A, t = 0}
end

local function updateFlicker(elapsed)
    local f = flicker
    if f == nil then return end

    if f.pending then
        f.wait = f.wait + elapsed
        local ok, name = pcall(currentAnim, FLICKER_TARGET)
        if f.anim == nil or (ok and name ~= f.anim) or f.wait >= FLICKER_MAX_WAIT then
            f.pending = false
        end
        return
    end

    f.t = f.t + elapsed
    while f.t >= f.step and f.left > 0 do
        f.t = f.t - f.step
        f.left = f.left - 1
        setVisible(not isVisible())
    end
    if f.left > 0 then return end

    if f.phase == 1 then
        setVisible(true)
        f.phase = 2
        f.step = FLICKER_STEP_B
        f.left = FLICKER_LOOPS_B
    else
        flickerStop()
    end
end

-- LIMUL-104-DEATH-SWAP: 1.0.4 PhillyStreets.hx:972-977 rewrites the death presentation on a lethal
-- firegun miss (pico-explosion-dead plus its two sounds). WHY IT IS OFF: that corpse folder is an
-- Adobe Animate 2020 atlas, and Character.hx's loader (animateatlas.AtlasFrameMaker) accepts only
-- the 2018 layout, traces its refusal and returns null; Character.hx then dereferences it and the
-- game closes. A lethal miss therefore ends on the usual pico-dead death that 2hot/script.lua and
-- scripts/pico-death.lua already set up; the 0.4 damage and the flicker are untouched.
-- DEATH_CHAR/SOUND/LOOP keep the 1.0.4 mapping on file for the day the corpse can load.
local USE_DEATH_SWAP = false
local DEATH_CHAR  = 'pico-explosion-dead'
local DEATH_SOUND = 'gameplay/gameover/fnf_loss_sfx-pico-explode'
local DEATH_LOOP  = 'gameplay/gameover/gameOverStart-pico-explode'

local function swapGameOverOnDeath()
    if not USE_DEATH_SWAP then return end
    if practice then return end
    local ok, h = pcall(getHealth)
    if not ok or type(h) ~= 'number' or h > 0 then return end
    pcall(setPropertyFromClass, 'GameOverSubstate', 'characterName', DEATH_CHAR)
    pcall(setPropertyFromClass, 'GameOverSubstate', 'deathSoundName', DEATH_SOUND)
    pcall(setPropertyFromClass, 'GameOverSubstate', 'loopSoundName', DEATH_LOOP)
end

-- Limul Engine: owners are the object NAME strings ('boyfriend', 'dad'), never bare globals --
-- this engine does not push the characters into the Lua environment.
local function play(candidates, owners)
    if #candidates == 0 then return false end
    local first = 1
    if #candidates > 1 then
        rotate = rotate % #candidates
        first = rotate
        rotate = rotate + 1
    end
    for _, who in ipairs(owners) do
        for i = 0, #candidates - 1 do
            local name = candidates[((first + i - 1) % #candidates) + 1]
            if tryAnim(who, name) then
                setProperty(who..'.specialAnim', true)
                return true
            end
        end
    end
    return false
end

-- playSound throws on a missing file and the error takes the rest of the callback down.
local function playFx(name, volume)
    if name == nil or name == '' then return end
    pcall(playSound, name, volume)
end

local function hurtPlayer(amount)
    if amount <= 0 then return end
    local ok, h = pcall(getHealth)
    if ok and type(h) == 'number' then setHealth(h - amount) end
end

-- ---------------------------------------------------------------- the shot darkens the street
-- LIMUL-DARKEN-PROPS: 1.0.4's PhillyStreets.hx:843-846 arms a 1/24s timer on every firegun note
-- the player hits, and darkenStageProps() (:999-1012) pushes the whole background through a
-- two-step tint -- every sprite in its `darkenable` array goes straight to 0xFF111111, and 1/24s
-- later to 0xFF222222 with a 1.4s tween back to 0xFFFFFFFF.
--
-- DARKENABLE is that array translated to the names the four weekend-1 stage scripts here actually
-- create (streets/phillyStreets name layers after what they draw, streetsErect adds
-- gradient1/gradient2/mist/paper, phillyStreetsErect keeps 1.0.4's philly* names). One superset
-- list plus luaSpriteExists() means a stage darkens exactly the scenery it built.
--
-- Deliberately NOT in the list: the fighters, the can (1.0.4 dims the can PILE, never the can
-- object) and rainFilter, which is a shader and has no colour.
local DARKENABLE = {
    'sky1', 'sky2', 'sky3', 'skyline', 'city', 'constructionSite', 'highwayLights',
    'highwayLightMap', 'highway', 'smog', 'cars1', 'cars2', 'trafficLight', 'trafficLightMap',
    'street', 'sprayCans',
    'phillySkybox', 'phillySkyline', 'phillyForegroundCity', 'phillyConstruction',
    'phillyHighwayLights', 'phillyHighwayLights_lightmap', 'phillyHighway', 'phillySmog',
    'phillyCars1', 'phillyCars2', 'phillyTraffic', 'phillyTraffic_lightmap', 'phillyForeground',
    'spraycanPile', 'limulSkyFill',
    'gradient1', 'gradient2', 'mist', 'paper'
}
local DARKEN_TAG = 'limulDarkenProps'
local DARKEN_ARM = DARKEN_TAG..'_arm'

local function tintStageProps(hex)
    for i = 1, #DARKENABLE do
        local name = DARKENABLE[i]
        if luaSpriteExists(name) then
            -- getColorFromHex is the only safe way in: setProperty's colour path does no string
            -- parsing, so a bare '111111' would reach FlxSprite.color as Int 0, black.
            setProperty(name..'.color', getColorFromHex(hex))
        end
    end
end

-- Stage 1: the tint never lands on the hit itself, only 1/24s after it.
local function darkenStageProps()
    runTimer(DARKEN_ARM, 1 / 24)
end

-- Stage 2: one shared timer replaces the original's per-sprite ones -- same 1/24s for every
-- sprite, and runTimer cancels a pending tag, so a second shot restarts the pass instead of
-- stacking two like 1.0.4 does.
local function dropStageProps()
    tintStageProps('111111')
    runTimer(DARKEN_TAG, 1 / 24)
end

-- Stage 3: doTweenColor starts from whatever the sprite holds right now, so setting 222222 first
-- is what makes the tween run 222222 -> FFFFFF over 1.4s with the linear ease.
local function liftStageProps()
    for i = 1, #DARKENABLE do
        local name = DARKENABLE[i]
        if luaSpriteExists(name) then
            setProperty(name..'.color', getColorFromHex('222222'))
            doTweenColor(DARKEN_TAG..name, name, 'FFFFFF', 1.4, 'linear')
        end
    end
end

-- ---------------------------------------------------------------- callbacks
function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if noteType ~= TYPE or isSustainNote then return end
    play(ANIMS, {'boyfriend', 'dad'})
    playFx(hitSoundName(), 1)
    if weekend1CanShot ~= nil then weekend1CanShot() end
    darkenStageProps()
end

function opponentNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if noteType ~= TYPE or isSustainNote then return end
    play(ANIMS, {'dad', 'boyfriend'})
    playFx(hitSoundName(), 1)
end

-- A missed firegun note is the can arriving: flinch, bonk, health and the blink. This is the only
-- reachable damage site in the week (the can types' noteMiss never fires, Darnell's cans are
-- opponent notes).
function noteMiss(membersIndex, noteData, noteType, isSustainNote)
    if noteType ~= TYPE or isSustainNote then return end
    if #MISS_ANIMS > 0 then play(MISS_ANIMS, {'boyfriend', 'dad'}) end
    local hurt = tryAnims('boyfriend', HURT_ANIMS)
    setProperty('boyfriend.specialAnim', true)
    if IMPACT_SOUND ~= '' then playFx(IMPACT_SOUND, 1) end
    hurtPlayer(DAMAGE)
    -- 1.0.4 writes the death presentation right after spending the health (PhillyStreets.hx:971-977)
    -- and arms the blink on the flinch above (927-969). flickerStop first so a second miss cannot
    -- stack a blink on a half-finished one.
    swapGameOverOnDeath()
    flickerStop()
    flickerStart(hurt)
end

function onTimerCompleted(tag, loops, loopsLeft)
    -- LIMUL-GAMEOVER-GUARD: FlxTimer runs on FlxTimer.globalManager, which keeps ticking during a
    -- death, so without this early return the street would be dropped dark on the game-over screen.
    if inGameOver then return end
    if tag == DARKEN_ARM then
        dropStageProps()
    elseif tag == DARKEN_TAG then
        liftStageProps()
    end
end

-- LIMUL-PICO-FLICKER: the blink is driven from here because 0.6.3 gives Lua no animation-finished
-- callback at all. When nothing is blinking this is one nil check.
function onUpdate(elapsed)
    if elapsed == nil or elapsed <= 0 then return end
    if flicker == nil then return end
    if inGameOver then
        flickerStop()
        return
    end
    updateFlicker(elapsed)
end

-- The corpse on the death screen is a separate sprite added by GameOverSubstate, so a blink still
-- running would only make the PlayState Pico invisible behind it; stop it and hand visibility back.
function onGameOver()
    flickerStop()
end
