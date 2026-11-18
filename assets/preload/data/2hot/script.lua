-- LIMUL-WEEKEND1-CAN: Darnell's can is the JS Engine port now (source/SpraycanAtlasSprite.hx,
-- created by stages/phillyStreets*.lua through weekend1CreateCan for 2hot only). The old
-- Spraycan1/Spraycan2 Lua pair, its tweens and the separate spraypaintExplosionEZ sprite are gone;
-- this file drives the native can through weekend1CanStart() / weekend1CanShot().

function onCreate()
precacheImage('explosionfrom_edd')
precacheSound("explode")
	setPropertyFromClass('GameOverSubstate', 'characterName', 'pico-dead')
	-- LIMUL-PICO-DEATH-SFX: the port had 'Shoot_1' here, but sounds/Shoot_1.ogg in this pack is
	-- digital silence (the same file weekend-1-firegun.lua stopped using as its hit sound), so
	-- every 2hot death started mute. The Weekend 1 original sets fnf_loss_sfx-pico
	-- (mods/Weekend 1/data/2hot/script.lua:3), and that file exists and is audible here.
	setPropertyFromClass('GameOverSubstate', 'deathSoundName', 'fnf_loss_sfx-pico')
	setPropertyFromClass('GameOverSubstate', 'loopSoundName', 'gameplay/gameover/gameOver-pico')
	setPropertyFromClass('GameOverSubstate', 'endSoundName', 'gameplay/gameover/gameOverEnd-pico')
	setPropertyFromClass('PauseSubState', 'songName', 'breakfast-pico/breakfast-pico')

	makeLuaSprite('cutsceneCrutchBlack', 'empty', 0, 0);
	makeGraphic('cutsceneCrutchBlack', 3000, 2000, '000000');
	setObjectCamera('cutsceneCrutchBlack', 'other');

	makeLuaSprite('shootBlack', 'empty', 0, 0);
	makeGraphic('shootBlack', 3000, 2000, '000000');
	setProperty('shootBlack.alpha', 0);

	makeAnimatedLuaSprite('reloadEffect', 'characters/Pico_Playable', 1980, 755);
	addAnimationByPrefix('reloadEffect', 'cock', 'Pico Reload', 24, false);
	setProperty('reloadEffect.alpha', 0);

	makeLuaSprite('reloadEffectScale', 'empty', 1, 1);
	setProperty('reloadEffectScale.alpha', 0);

	addLuaSprite('shootBlack', false);
	addLuaSprite('reloadEffect', true);
end

function onUpdate()
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	setProperty('reloadEffect.scale.x', getProperty('reloadEffectScale.x'))
	setProperty('reloadEffect.scale.y', getProperty('reloadEffectScale.x'))
end

local isGameOver = false
local darnellAnim = false
local picoAnim = false
local reload = false

--[[ LIMUL-COCK-ARMED (2026-11-04)
	In 1.0.4 the shot is armed by the cock, not by the lane: PhillyStreets.hx:181 gives every
	weekend-1-firegun note blockHit, and :829-833 clears it on the alive ones the moment a
	weekend-1-cockgun is hit. A blocked note cannot be hit at all, so it only costs health once it
	passes (noteMiss -> shootMISS, -0.4 at :971). Normal notes are never touched by any of that.
	2hot-erect and 2hot-nightmare carry no note types at all (0 of 1043 notes), so for them this
	script's lane machine IS the choreography -- and it had no arming: any plain vocal note on lane 0
	inside a Pico window that arrived without a preceding lane-1 note ran the shoot-without-reload
	branch and took 0.5 health plus a bonk. cockedHere is the missing gate: lane 0 only means "Pico
	fires" once lane 1 has been hit inside the current window. Measured on the live charts it drops
	one spurious 0.5 HP hit on 2hot-erect and 2hot-nightmare and changes nothing on the typed ones.
]]
local cockedHere = false

--[[ LIMUL-FLINCH-NAME (2026-11-04)
	1.0.4 names the can flinch 'shootMISS' (PhillyStreets.hx:933). This fork's
	assets/preload/characters/pico-playable.json does not define that animation at all -- its flinch
	is 'CanHit' (prefix "Pico Hit Can"), confirmed against the live atlas by
	tools/character_anim_check.py. playAnim() on a name the character lacks is a silent no-op, so
	Pico used to eat the can with no reaction. Try the original spelling first, fall back to the one
	that exists -- the same shape the weekend-1-* note types now use.
]]
local HURT_ANIMS = {'shootMISS', 'CanHit'}

local function currentAnim(obj)
	local ok, name = pcall(getProperty, obj..'.animation.curAnim.name')
	if ok and name ~= nil then return name end
	ok, name = pcall(getProperty, obj..'.atlas.anim.lastPlayedAnim')
	if ok then return name end
	return nil
end

local function tryAnims(obj, names)
	for i = 1, #names do
		playAnim(obj, names[i], true)
		if currentAnim(obj) == names[i] then return true end
	end
	return false
end

-- Limul Engine: the five weekend-1-* custom note types in assets/custom_notetypes/ fire on the
-- very same notes this script used to drive from a lane number inside a step window. Both running
-- meant two animations, two sounds, two projectiles and 0.5 + 0.35 health for one note.
-- For those types this script keeps ONLY what the shims cannot reach: the reloadEffect silhouette
-- and the shootBlack muzzle flash; the can is native (weekend1CanStart/Shot) and driven from the
-- untyped lane machine below. Everything else belongs to the note type.
local SHIMMED = {
	['weekend-1-lightcan'] = true, ['weekend-1-kickcan'] = true, ['weekend-1-kneecan'] = true,
	['weekend-1-cockgun'] = true, ['weekend-1-firegun'] = true
}

local function isShimmed(noteType)
	return type(noteType) == 'string' and SHIMMED[noteType] == true
end

-- LIMUL-DARKEN-PROPS: 1.0.4's PhillyStreets.hx darkens the whole background when Pico fires --
-- goodNoteHit('weekend-1-firegun') starts a 1/24s timer (:843-846), darkenStageProps() then
-- takes every sprite in `darkenable` (:59-123, :189) to 0xFF111111, and one more 1/24s later to
-- 0xFF222222 with a 1.4s tween back to 0xFFFFFFFF (:999-1012). It is the muzzle flash pulling
-- the light out of the street for a beat, and this fork had none of it.
--
-- The same pass lives in assets/custom_notetypes/weekend-1-firegun.lua, which is the owner for
-- charts that carry the note type. It cannot be called from here -- one Lua state per script, so
-- globals are not shared between them -- and only 2hot, 2hot-easy and 2hot-hard carry it (6 notes
-- each; measured over all 144 charts in assets/preload/data). 2hot-normal, 2hot-erect and
-- 2hot-nightmare drive the identical exchange from the lane machine below, so this copy exists for
-- them and the isShimmed() gate keeps one darken per shot: the notetype handles the typed notes,
-- this file the untyped ones.
--
-- DARKENABLE is 1.0.4's array translated to the names the four weekend-1 stage scripts here
-- actually create (streets/phillyStreets name layers after what they draw, streetsErect adds
-- gradient1/gradient2/mist/paper, phillyStreetsErect keeps 1.0.4's philly* names). One superset
-- list filtered by luaSpriteExists() means each stage dims exactly the scenery it built, and
-- lowQuality -- which never creates sky3, smog, constructionSite or either lightmap -- just
-- skips names that are not there. The fighters, the can in flight (1.0.4 dims the can PILE at
-- :189, never the can itself) and rainFilter, a shader with no colour, stay out of the list.
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
local DARKEN_TAG = 'limulDarkenProps'		-- hands stage 2 over to stage 3
local DARKEN_ARM = DARKEN_TAG..'_arm'	-- the original's outer 1/24s timer (:843-846)

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
-- sprite, a quarter of the FlxTimers, and runTimer cancels a pending tag, so a second shot
-- restarts the pass instead of stacking two like 1.0.4 does.
local function dropStageProps()
	tintStageProps('111111')
	runTimer(DARKEN_TAG, 1 / 24)
end

-- Stage 3: doTweenColor starts from whatever the sprite holds right now, so setting 222222
-- first is what makes the tween run 222222 -> FFFFFF over 1.4s with the linear ease
-- FlxTween.color(sprite, 1.4, 0xFF222222, 0xFFFFFFFF) uses.
local function liftStageProps()
	for i = 1, #DARKENABLE do
		local name = DARKENABLE[i]
		if luaSpriteExists(name) then
			setProperty(name..'.color', getColorFromHex('222222'))
			doTweenColor(DARKEN_TAG..name, name, 'FFFFFF', 1.4, 'linear')
		end
	end
end

-- LIMUL-DARKEN-PROPS: stages 2 and 3 run off timers, so this file needs a live onTimerCompleted.
-- It did not have one: the handler below is inside the --[[ block opened at 'function onGameOver'
-- and closed by the nested ]]--) on the runHaxeCode line, so it never reached Lua. Declaring the
-- name here is the only live definition, which is also why nothing else in this file uses
-- 'gameOverStart' as a tag.
function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: FlxTimer keeps ticking during a death; do not drop the stage on the game-over screen
	if tag == DARKEN_ARM then
		dropStageProps()
	elseif tag == DARKEN_TAG then
		liftStageProps()
	end
end

--[[function onGameOver()
	runTimer('gameOverStart', 91/24);
	isGameOver = true
end

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == 'gameOverStart' and picoAnim then
		runHaxeCode([[
			boyfriend.playAnim('deathLoop');
		]]--)
	--end
--end

function opponentNoteHit(id, direction, noteType, isSustainNote)
	if not darnellAnim then return end
	local shimmed = isShimmed(noteType)
	if direction == 1 and not shimmed then
		playAnim('dad', 'lightCan', false);
		setProperty('dad.specialAnim', true);
	end
	if direction == 2 then
		if not shimmed then
			playAnim('dad', 'kickCan', false);
			setProperty('dad.specialAnim', true);
			if weekend1CanStart ~= nil then weekend1CanStart() end
		end
	end
	if direction == 3 then
		if not shimmed then
			playAnim('dad', 'kneeCan', false);
			setProperty('dad.specialAnim', true);
		end
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	if not picoAnim then return end
	local shimmed = isShimmed(noteType)
	if direction == 1 then
		reload = true
		cockedHere = true
		-- reloadEffect: the 'Pico Reload' frames drawn as a separate sprite, which the
		-- cockpit gun note type has no idea exists. reload itself stays outside the gate so a
		-- cockgun note still arms the firegun branch below.
		playAnim('reloadEffect', 'cock', false);
		setProperty('reloadEffectScale.x', 1)
		doTweenX('reloadEffectScale', 'reloadEffectScale', 1.1, 0.3, 'linear')
		setProperty('reloadEffect.alpha', 0.5);
		doTweenAlpha('reloadEffect', 'reloadEffect', 0, 0.3, 'linear')
		if not shimmed then
			playAnim('boyfriend', 'cock', false);
			setProperty('boyfriend.specialAnim', true);
			playSound('Gun_Prep', 1);
		end
	end
	if direction == 0 and reload then
		reload = false
		if not shimmed then
			playAnim('boyfriend', 'shoot', false);
			setProperty('boyfriend.specialAnim', true);
			playSound('shot'..getRandomInt(1,3), 1);
			darkenStageProps() -- LIMUL-DARKEN-PROPS: untyped charts only, see the note above
			if weekend1CanShot ~= nil then weekend1CanShot() end
		end
		setProperty('shootBlack.alpha', 1);
		doTweenAlpha('shootBlack', 'shootBlack', 0, 1, 'linear')
	elseif direction == 0 and not reload and cockedHere then
		if not shimmed then
			health = getProperty('health')
			tryAnims('boyfriend', HURT_ANIMS);
			setProperty('boyfriend.specialAnim', true);
			setProperty('health', health -0.4);	-- LIMUL-104-DAMAGE: 1.0.4 states/stages/PhillyStreets.hx:971 spends 0.4 for a missed weekend-1-firegun note (this fork had 0.5)
			playSound('Pico_Bonk', 1);
		end
	end
end

function noteMiss(id, direction, noteType, isSustainNote)
	if direction == 0 and picoAnim and cockedHere then
		reload = false
		if not isShimmed(noteType) then
			health = getProperty('health')
			tryAnims('boyfriend', HURT_ANIMS);
			setProperty('boyfriend.specialAnim', true);
			setProperty('health', health -0.4);	-- LIMUL-104-DAMAGE: 1.0.4 states/stages/PhillyStreets.hx:971 spends 0.4 for a missed weekend-1-firegun note (this fork had 0.5)
			playSound('Pico_Bonk', 1);
		end
	end
end

function onStepHit()
	if curStep >= 108 and curStep <= 126 or curStep >= 492 and curStep <= 510 or curStep >= 620 and curStep <= 638 or curStep >= 972 and curStep <= 990 or curStep >= 1036 and curStep <= 1054 or curStep >= 1420 and curStep <= 1438 then
		darnellAnim = true
	else
		darnellAnim = false
	end
	if curStep >= 119 and curStep <= 126 or curStep >= 503 and curStep <= 510 or curStep >= 631 and curStep <= 638 or curStep >= 983 and curStep <= 990 or curStep >= 1047 and curStep <= 1054 or curStep >= 1431 and curStep <= 1438 then
		picoAnim = true
	else
		picoAnim = false
		cockedHere = false -- LIMUL-COCK-ARMED: the gun is un-armed between exchanges, see the note above
	end
end
