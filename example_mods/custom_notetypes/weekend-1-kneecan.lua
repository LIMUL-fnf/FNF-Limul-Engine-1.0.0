-- weekend-1-kneecan.lua -- Limul Engine (Psych 0.6.3) custom note type for the V-Slice Weekend 1 charts.
--
-- Chart string: 'weekend-1-kneecan' -- Darnell knees the spray can.
-- Psych uses this string verbatim as the script name (ChartingState fills its dropdown from
-- mods/custom_notetypes/ and PlayState loads the same path at gameplay), so the file name is part
-- of the note type.
--
-- WHAT IT DOES (1.0.4 / JS Engine parity). PhillyStreets.hx plays 'kneeCan' plus
-- Paths.sound('Kick_Can_FORWARD') and touches nothing else: the knee note never moves the can and
-- never costs health. The native can (source/SpraycanAtlasSprite.hx) is driven only by kickcan
-- (weekend1CanStart) and firegun (weekend1CanShot).

local TYPE = 'weekend-1-kneecan'
local ANIMS = {'kneeCan'}
local HIT_SOUND = 'Kick_Can_FORWARD'

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

function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if noteType ~= TYPE or isSustainNote then return end
    play(ANIMS, {'boyfriend', 'dad'})
    playFx(HIT_SOUND, 1)
end

function opponentNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if noteType ~= TYPE or isSustainNote then return end
    play(ANIMS, {'dad', 'boyfriend'})
    playFx(HIT_SOUND, 1)
end
