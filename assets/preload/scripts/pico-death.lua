-- Limul Engine / Psych 0.6.3 -- Weekend 1 "Pico game over" set piece.
--
-- What it adds: Nene's knife throw from the GF slot, and the pico corpse + pico
-- game-over sounds for every song whose player is a pico variant (Darnell, Lit Up,
-- Blazin, 2hot...).
--
-- It deliberately does NOT add a RETRY sign. The one that used to be created here
-- (Pico_Death_Retry) drew a second RETRY next to the corpse: the RETRY text is baked
-- into the corpse atlas itself -- frames DEATH PICO0049 / DEATH PICO0098 of
-- characters/Pico_Death.png already carry the blood splatter and its glowing
-- confirm state -- and GameOverSubstate.hx adds no retry sprite of its own (only the
-- corpse and camFollowPos), so the art's own RETRY is the only one that should show.
--
-- WHY THIS FILE IS INSTALLED IN TWO PLACES
-- PlayState scans the "global scripts" folders in this order:
--   mods/<globalMods>/scripts/ , mods/<currentModDirectory>/scripts/ ,
--   mods/scripts/ , assets/scripts/
-- and de-duplicates by FILE NAME, so the same file sitting in two of them is
-- still loaded exactly once. assets/scripts/ is the only one that is scanned no
-- matter what Paths.currentModDirectory ends up being, so the copy there is the
-- guarantee that the set piece runs at all; the copy in mods/weekend1/scripts/
-- is the canonical mod location and wins when the mod directory resolves.
-- Keep both byte-identical.
--
-- WHY IT LOGS
-- The exported release build has no console, so a Lua error here would be
-- invisible. saveFile() writes the decisions to mods/limul-pico-death.log,
-- which is enough to tell "script never loaded" from "detection failed" from
-- "sprites failed". Delete this script's note() calls if the file ever annoys.
--
-- Ported from the Erect original (mods/_erect-unused/characters/pico-playable.lua),
-- which cannot run here: it keys off Erect-only APIs (setPropertyFromGameOver,
-- runHaxeFunction, backend.ClientPrefs) and aims at pico-playable-dead, whose
-- "Pico Death Stab" prefix resolves to zero frames in this build's atlas.

local logLines = {}
local function note(line)
	logLines[#logLines + 1] = tostring(line)
	saveFile('limul-pico-death.log', table.concat(logLines, '\n'))
end

local picoDeath = false
local haveThrow = false

-- Three ways to learn who is playing, because the corpse has to be picked in
-- onGameOver, which runs one frame before the substate exists.
local function playerSlotName()
	local n = getProperty('boyfriend.curCharacter')
	if type(n) ~= 'string' or n == '' then
		n = boyfriendName
	end
	if type(n) ~= 'string' or n == '' then
		n = getProperty('curCharacter')
	end
	if type(n) ~= 'string' then
		n = ''
	end
	return n
end

function onCreate()
	note('loaded | currentModDirectory=[' .. tostring(currentModDirectory) .. '] | bf=[' .. playerSlotName() .. '] | song=' .. tostring(songName))
end

function onGameOver()
	local name = playerSlotName()
	local corpse = getPropertyFromClass('GameOverSubstate', 'characterName')
	local corpseIsPico = (type(corpse) == 'string') and string.find(corpse, 'pico') ~= nil
	if string.find(name, 'pico') == nil and not corpseIsPico then
		note('onGameOver: not a pico death (bf=[' .. name .. '] corpse=[' .. tostring(corpse) .. '])')
		return
	end
	picoDeath = true

	-- A song script may already have chosen the corpse (blazin -> pico-blazin-dead,
	-- 2hot/lit-up -> pico-dead). Respect it; only fill in when it is still vanilla.
	local dead = 'pico-dead'
	if corpseIsPico then
		dead = corpse
	elseif name == 'pico-blazin' then
		dead = 'pico-blazin-dead'
	end
	setPropertyFromClass('GameOverSubstate', 'characterName', dead)

	if getPropertyFromClass('GameOverSubstate', 'deathSoundName') == 'fnf_loss_sfx' then
		setPropertyFromClass('GameOverSubstate', 'deathSoundName', 'fnf_loss_sfx-pico')
	end
	if getPropertyFromClass('GameOverSubstate', 'loopSoundName') == 'gameOver' then
		setPropertyFromClass('GameOverSubstate', 'loopSoundName', 'gameplay/gameover/gameOver-pico')
	end
	if getPropertyFromClass('GameOverSubstate', 'endSoundName') == 'gameOverEnd' then
		setPropertyFromClass('GameOverSubstate', 'endSoundName', 'gameplay/gameover/gameOverEnd-pico')
	end

	-- GameOverSubstate.new() zeroes FlxG.camera.scroll, so screen positions taken
	-- after that are world positions. Grab GF's spot now, while the gameplay camera
	-- is still the one that framed it.
	runHaxeCode([[
		var gfPos = (game.gf != null) ? game.gf.getScreenPosition() : null;
		setVar('limulDeathGfX', gfPos != null ? gfPos.x : 980);
		setVar('limulDeathGfY', gfPos != null ? gfPos.y : 120);
	]])
	note('onGameOver: bf=[' .. name .. '] corpse=' .. dead .. ' gf=' .. tostring(getProperty('boyfriend.x')) .. ',' .. tostring(getProperty('boyfriend.y')))
end

function onGameOverStart()
	if not picoDeath then
		return
	end

	makeAnimatedLuaSprite('neneDeathThrow', 'characters/NeneKnifeToss', 0, 0)
	addAnimationByPrefix('neneDeathThrow', 'throw', 'knife toss0', 24, false)
	addLuaSprite('neneDeathThrow', true)
	smooth('neneDeathThrow')
	runHaxeCode([[
		var knife = game.modchartSprites.get('neneDeathThrow');
		if (knife != null) {
			knife.x = getVar('limulDeathGfX') + 150;
			knife.y = getVar('limulDeathGfY');
		}
	]])
	haveThrow = true
	note('onGameOverStart: knife throw created at corpse ' .. tostring(getProperty('boyfriend.x')) .. ',' .. tostring(getProperty('boyfriend.y')))
end

-- The game-over camera eases toward the corpse for the first second (LOCKON follow
-- on a lerped camFollowPos). A sprite that snaps to whole pixels while the camera
-- moves in fractions reads as stutter, which is what "choppy" was here: the knife
-- and the sign are props standing still in the world, so all their motion is the
-- camera's. Let them be placed on subpixels and match the corpse's antialiasing.
function smooth(tag)
	setProperty(tag .. '.pixelPerfectRender', false)
	setProperty(tag .. '.antialiasing', getProperty('boyfriend.antialiasing'))
end

function onUpdate(elapsed)
	-- Ten callback OBSLUZUJE ekran smierci (sprzata noz po animacji), wiec
	-- LIMUL-GAMEOVER-GUARD jest tu celowo wylaczony: ponizszy warunek i tak
	-- przepuszcza tylko 'picoDeath and inGameOver'. Noz jest memberem GameOverSubstate --
	-- addLuaSprite wywolany z onGameOverStart trafia do substate'u, bo PlayState.instance.isDead
	-- jest juz true (limul-gameover-stage.lua ma caly wywod) -- wiec rysuje sie nad czarna
	-- plansza niezaleznie od persistentDraw, i musze go schowac po zakonczeniu animacji.
	if not picoDeath or not inGameOver then
		return
	end

	if haveThrow and getProperty('neneDeathThrow.animation.finished') then
		setProperty('neneDeathThrow.visible', false)
	end
end
