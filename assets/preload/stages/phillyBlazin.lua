-- Limul Engine: Blazin' stage, ported from FNF-JS-Engine 1.51.1 source/stages/PhillyBlazin.hx.
-- This file is the sky / lightning / colour-tint stack; the rain itself is data/blazin/rain.lua.
--
-- Layer order below is back-to-front, which is the order the original adds them too
-- (FlxCamera members are drawn by index, and addLuaSprite(..., false) inserts in front of the
-- character groups, so the first call ends up furthest back):
--   scrollingSky -> skyAdditive -> lightning -> streetBlur -> foregroundMultiply -> additionalLighten
-- Original numbers kept verbatim: scale 1.75 (setupScale), sky scroll -35 px/s, bolt every
-- 7-15 s (first one at 3 s, like lightningTimer = 3.0), skyAdditive 0.7 -> 0 in 1.5 s,
-- foregroundMultiply 0.64 -> 0 in 1.5 s, additionalLighten 0.3 -> 0 in 0.3 s, lightning x
-- random(-250,280) with 65% odds else random(780,900), characters 0xFF606060 -> 0xFFDEDEDE
-- and gf/abot 0xFF606060 -> 0xFF888888 in 0.3 s.

local skyX = -600
local skyTileW = 2427          -- skyBlur is 1387 px wide, setupScale 1.75
local skyScroll = 35           -- scrollingSky.scrollX -= elapsed * 35
local abotParts = {'abot', 'abotBG', 'abotEyes', 'abotEyeBack'}

-- Fight state, used by the choreography block at the bottom of this file. It is declared up
-- here because Lua only closes over locals that appear BEFORE the function in the chunk, and
-- onStartCountdown (below) has to reset part of it.
local fightArmed = false
local lastScore = 0            -- songScore as seen on the last note event, for the judgement delta
local judgement = 'unknown'    -- 'sick' | 'good' | 'bad' | 'shit' of the last scored hit
local pico = {alt = false, cantUppercut = false, anim = 'idle'}
local darn = {alt = false, cantUppercut = false, anim = 'idle'}

local function charName(obj)
	local ok, name = pcall(getProperty, obj .. '.curCharacter')
	if ok and type(name) == 'string' then return name end
	return nil
end

function onCreate()
	if not lowQuality then
		-- scrollingSky: a FlxTiledSprite in the original, two pinned copies here.
		makeLuaSprite('scrollingSky1', 'phillyBlazin/skyBlur', skyX, -120);
		scaleObject('scrollingSky1', 1.75, 1.75);
		setScrollFactor('scrollingSky1', 0, 0);
		addLuaSprite('scrollingSky1', false);

		makeLuaSprite('scrollingSky2', 'phillyBlazin/skyBlur', skyX + skyTileW, -120);
		scaleObject('scrollingSky2', 1.75, 1.75);
		setScrollFactor('scrollingSky2', 0, 0);
		addLuaSprite('scrollingSky2', false);

		makeLuaSprite('skyAdditive', 'phillyBlazin/skyBlur', -600, -175);
		scaleObject('skyAdditive', 1.75, 1.75);
		setScrollFactor('skyAdditive', 0, 0);
		setProperty('skyAdditive.alpha', 0);
		setProperty('skyAdditive.visible', false);

		makeAnimatedLuaSprite('lightning', 'phillyBlazin/lightning', -50, -300);
		addAnimationByPrefix('lightning', 'strike', 'lightning0', 24, false);
		scaleObject('lightning', 1.75, 1.75);
		setScrollFactor('lightning', 0, 0);
		setProperty('lightning.visible', false);

		-- Limul Engine: the original's foregroundMultiply is the SAME streetBlur art with a
		-- MULTIPLY blend (PhillyBlazin.hx builds both BGSprites from 'phillyBlazin/streetBlur').
		-- The old code looked for a separate images/phillyBlazin/foregroundMultiply.png that no
		-- pack ships, makeLuaSprite threw on the missing key and killed the rest of onCreate().
		makeLuaSprite('foregroundMultiply', 'phillyBlazin/streetBlur', -600, -175);
		scaleObject('foregroundMultiply', 1.75, 1.75);
		setScrollFactor('foregroundMultiply', 0, 0);
		setBlendMode('foregroundMultiply', 'multiply');
		setProperty('foregroundMultiply.alpha', 0);
		setProperty('foregroundMultiply.visible', false);
	end

	makeLuaSprite('phillyForegroundCity', 'phillyBlazin/streetBlur', -600, -175);
	scaleObject('phillyForegroundCity', 1.75, 1.75);
	setScrollFactor('phillyForegroundCity', 0, 0);

	makeLuaSprite('additionalLighten', 'empty', -600, -175);
	makeGraphic('additionalLighten', 2500, 2500, 'FFFFFF');
	setScrollFactor('additionalLighten', 0, 0);
	setBlendMode('additionalLighten', 'add');
	setProperty('additionalLighten.alpha', 0);
	setProperty('additionalLighten.visible', false);

	-- Limul Engine: flat sky backdrop pinned to the camera: at this stage zoom the camera
	-- sees more world than the painted skybox covers, so the corners went black. This is
	-- the backmost layer, only visible where the real art does not reach the screen edge.
	makeLuaSprite('limulSkyFill', 'empty', -500, -500);
	makeGraphic('limulSkyFill', 2600, 1800, '4B4B4B');
	setScrollFactor('limulSkyFill', 0, 0);

	-- back-to-front, see the header
	addLuaSprite('limulSkyFill', false);
	if not lowQuality then
		addLuaSprite('scrollingSky1', false);
		addLuaSprite('scrollingSky2', false);
		addLuaSprite('skyAdditive', false);
		addLuaSprite('lightning', false);
	end
	addLuaSprite('phillyForegroundCity', false);
	if not lowQuality then
		addLuaSprite('foregroundMultiply', false);
		addLuaSprite('additionalLighten', false);
	end

	-- PhillyBlazin.hx: var lightningTimer:Float = 3.0
	runTimer('lightningTimer', 3);
end

function onCreatePost()
	-- createPost in the original: the whole scene runs desaturated until the next bolt.
	-- Written as flat colours instead of colour tweens on purpose -- flixel's ColorTween rewrites
	-- sprite.alpha every frame from the target colour's alpha byte, and until the engine parsed
	-- those hex strings correctly (CoolUtil.colorFromString; the old Std.parseInt('0xff'+hex)
	-- overflowed to 0x7FFFFFFF on Windows) every tween here also dragged Pico and Darnell down to
	-- alpha 0.498. A flat setProperty on .color never touches alpha, so it stays the safe form.
	--
	-- The colour has to reach FlxSprite.color as a Haxe Int. setProperty() forwards its value
	-- straight into FunkinLua.setVarInArray -> Reflect.setProperty, which does no parsing at all
	-- (only doTweenColor and getColorFromHex prefix the '0xff' alpha byte), so the bare
	-- 'FFDEDEDE' string this file used to pass became 0 and the cast rendered as silhouettes
	-- until the first bolt re-tinted them. RRGGBB through getColorFromHex -- the same helper
	-- base-game phillyTrain.lua uses -- returns exactly the ints PhillyBlazin.hx:121/126/131/133
	-- assigns (0xFFDEDEDE for bf/dad, 0xFF888888 for gf and the ABot speakers).
	setProperty('boyfriend.color', getColorFromHex('DEDEDE'));
	setProperty('dad.color', getColorFromHex('DEDEDE'));
	setProperty('gf.color', getColorFromHex('888888'));
	for i = 1, #abotParts do
		if luaSpriteExists(abotParts[i]) then setProperty(abotParts[i] .. '.color', getColorFromHex('888888')); end
	end

	-- PhillyBlazin.hx:135-143 -- "override animations for note types": the original strips the
	-- sing/miss animation off the fight notes, because on this stage the fight owns both
	-- fighters. Left alone, PlayState.hx:4837 (opponentNoteHit) and :4926 (goodNoteHit) play a
	-- sing animation with force=true on each note, which cuts in front of the choreography
	-- picoAct()/darnAct() drive from the note-type callbacks at the bottom of this file.
	-- Only weekend-1-* notes are stripped: the GameBanana Blazin chart also carries plain
	-- untyped notes that sing normally in the source engine. unspawnNotes is already full
	-- here -- same timing the base-game phillyTrain.lua relies on when it walks
	-- 'eventNotes.length' in its own onCreatePost -- and the notes are moved into the live
	-- group by reference, so the flags survive the spawn.
	local noteCount = getProperty('unspawnNotes.length')
	if type(noteCount) == 'number' and noteCount > 0 then
		for n = 0, noteCount - 1 do
			local noteType = getPropertyFromGroup('unspawnNotes', n, 'noteType')
			if type(noteType) == 'string' and string.sub(noteType, 1, 10) == 'weekend-1-' then
				setPropertyFromGroup('unspawnNotes', n, 'noAnimation', true)
				setPropertyFromGroup('unspawnNotes', n, 'noMissAnimation', true)
			end
		end
	end
end

function onStartCountdown()
	setProperty('dad.scale.x', 1.75);
	setProperty('dad.scale.y', 1.75);
	setProperty('boyfriend.scale.x', 1.75);
	setProperty('boyfriend.scale.y', 1.75);

	-- Fight state: score baseline for the judgement tracker, and arm the choreography only
	-- for the Blazin' cast (see the block at the bottom of this file).
	lastScore = (type(score) == 'number') and score or 0
	fightArmed = charName('dad') == 'darnell-blazin' and charName('boyfriend') == 'pico-blazin'
end

function onUpdate(elapsed)
	if lowQuality then return end
	if inGameOver then return end
	skyX = skyX - skyScroll * elapsed
	if skyX <= -600 - skyTileW then
		skyX = skyX + skyTileW
	end
	setProperty('scrollingSky1.x', skyX);
	setProperty('scrollingSky2.x', skyX + skyTileW);
end

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == 'lightningTimer' then
		applyLightning();
		-- PhillyBlazin.hx: lightningTimer = FlxG.random.float(7, 15)
		runTimer('lightningTimer', getRandomInt(7, 15));
	end
end

function applyLightning()
	if lowQuality or inGameOver then return end

	-- final LIGHTNING_FULL_DURATION = 1.5; final LIGHTNING_FADE_DURATION = 0.3;
	setProperty('skyAdditive.visible', true);
	setProperty('skyAdditive.alpha', 0.7);
	doTweenAlpha('boltSky', 'skyAdditive', 0, 1.5, 'linear');

	setProperty('foregroundMultiply.visible', true);
	setProperty('foregroundMultiply.alpha', 0.64);
	doTweenAlpha('boltMultiply', 'foregroundMultiply', 0, 1.5, 'linear');

	setProperty('additionalLighten.visible', true);
	setProperty('additionalLighten.alpha', 0.3);
	doTweenAlpha('boltLighten', 'additionalLighten', 0, 0.3, 'linear');

	setProperty('lightning.visible', true);
	setProperty('lightning.alpha', 1);
	playAnim('lightning', 'strike', true);
	if getRandomInt(0, 100) < 65 then
		setProperty('lightning.x', getRandomInt(-250, 280));
	else
		setProperty('lightning.x', getRandomInt(780, 900));
	end

	-- Darken characters, then let them fade back to the resting tint.
	-- 1.0.4 PhillyBlazin.hx:227-230 tweens from 0xFF606060 to 0xFFDEDEDE (gf/abot to 0xFF888888)
	-- over LIGHTNING_FADE_DURATION = 0.3; both colour APIs here take RRGGBB and add the FF alpha
	-- themselves, which also keeps flixel's ColorTween from writing an alpha below 1 into the
	-- sprite every frame.
	setProperty('boyfriend.color', getColorFromHex('606060'));
	doTweenColor('boltBf', 'boyfriend', 'DEDEDE', 0.3, 'linear');
	setProperty('dad.color', getColorFromHex('606060'));
	doTweenColor('boltDad', 'dad', 'DEDEDE', 0.3, 'linear');
	setProperty('gf.color', getColorFromHex('606060'));
	doTweenColor('boltGf', 'gf', '888888', 0.3, 'linear');
	for i = 1, #abotParts do
		if luaSpriteExists(abotParts[i]) then
			setProperty(abotParts[i] .. '.color', getColorFromHex('606060'));
			doTweenColor('bolt' .. abotParts[i], abotParts[i], '888888', 0.3, 'linear');
		end
	end

	playSound('Lightning' .. getRandomInt(1, 3), 1);
end

function onTweenCompleted(tag)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up

	-- the original hides the whole flash stack in skyAdditive's onComplete callback (1.5 s)
	if tag == 'boltSky' then
		if not lowQuality then
			setProperty('skyAdditive.visible', false);
			setProperty('lightning.visible', false);
			setProperty('foregroundMultiply.visible', false);
			setProperty('additionalLighten.visible', false);
		end
		return;
	end

	-- ColourTween writes sprite.alpha = color.alphaFloat every frame; snap the characters back
	-- to fully opaque so a bad start colour can never leave Pico or Darnell see-through.
	if tag == 'boltBf' or tag == 'boltDad' then
		setProperty('boyfriend.alpha', 1);
		setProperty('dad.alpha', 1);
		setProperty('gf.alpha', 1);
	elseif tag == 'boltGf' then
		setProperty('gf.alpha', 1);
	end
end

-- =========================================================================================
-- BLAZIN' FIGHT CHOREOGRAPHY
--
-- Lua port of FNF-JS-Engine 1.51.1 source/stages/objects/PicoBlazinHandler.hx and
-- DarnellBlazinHandler.hx. The original dispatch is PhillyBlazin.hx:229-258: one note event
-- drives BOTH fighters, and note.noteType alone decides what each of them does (the lane is
-- irrelevant -- blockHigh means "Darnell throws a high punch and Pico answers it" no matter
-- whose strumline the arrow sits on).
--
-- WHY IT LIVES IN THE STAGE AND NOT IN custom_notetypes/. Psych 0.6.3 loads one Lua per note
-- type (PlayState.hx:1208-1231) and then hands EVERY loaded script EVERY callback
-- (callOnLuas, PlayState.hx:5399), so a per-type file cannot own a fight step: the two
-- fighters would be driven from 26 different states, and noteMissPress -- which carries only
-- a direction and no note type -- would fire Pico's wild punch once per shim. The 26
-- weekend-1-* fight shims are inert markers now, kept only so the Chart Editor still lists
-- the types (ChartingState.hx:1064 fills the dropdown from these files). The five 2 Hot
-- can/gun types still animate from their own scripts, they are not part of the fight.
--
-- Differences from the Haxe, every one of them forced by 0.6.3:
--  * boyfriend/dad.getAnimationName() is replaced by the pico.anim / darn.anim mirror.
--    Character.dance() beats both fighters back to 'idle' between notes, which would blank
--    the fakeout -> taunt and cringe -> pissed chains and the uppercutPrep guards. The
--    mirror only remembers moves this script played, so a chain survives however far apart
--    its two notes are. JS Engine's 'uppercut-hold' is 'uppercut-loop' in these defs.
--  * note.rating never reaches Lua. popUpScore adds daRating.score (sick 350 / good 200 /
--    bad 100 / shit 50) to songScore and RecalculateRating pushes it as the global `score`
--    BEFORE callOnLuas('goodNoteHit'), so the judgement is recovered from the score delta.
--    Nothing is scored in practice mode or bot play, so the two poor-hit guards simply
--    never fire there -- which matches the intent, they exist to punish sloppy play.
--  * opponentNoteHit routes to the noteMiss handlers, exactly like PhillyBlazin.hx:253-258.
--  * Sustain segments are skipped: Psych calls goodNoteHit again for every tick of a hold,
--    and the same move would otherwise re-trigger dozens of times per second.
--  * Darnell's cantUppercut flag is dead code in the original (noteHit/noteMiss set it
--    inside the switch and clear it two lines later at the end of the same call), kept
--    verbatim so the two implementations stay readable side by side. Pico's flag does work
--    and is only cleared by the block it triggers.

local PICO_P = {
	block        = {a='block',        sh={0.002, 0.1}},
	dodge        = {a='dodge'},
	idle         = {a='idle',         force=false},   -- playAnim('idle', false)
	fakeout      = {a='fakeout'},
	taunt        = {a='taunt'},
	uppercutPrep = {a='uppercutPrep', front=true},
	uppercut     = {a='uppercut',     front=true},   -- playUppercutAnim(false)
	uppercutLand = {a='uppercut',     front=true, sh={0.005, 0.25}},  -- playUppercutAnim(true)
	uppercutHit  = {a='uppercutHit',  sh={0.005, 0.25}},
	hitHigh      = {a='hitHigh',      sh={0.0025, 0.15}},
	hitLow       = {a='hitLow',       sh={0.0025, 0.15}},
	hitSpin      = {a='hitSpin',      sh={0.0025, 0.15}},
	punchHigh    = {a='punchHigh',    alt=true, front=true},
	punchLow     = {a='punchLow',     alt=true, front=true},
}

local DARN_P = {
	block        = {a='block',        sh={0.002, 0.1}},
	dodge        = {a='dodge'},
	idle         = {a='idle',         force=false},
	fakeout      = {a='fakeout'},
	cringe       = {a='cringe'},
	pissed       = {a='pissed'},
	uppercutPrep = {a='uppercutPrep', front=true},
	uppercut     = {a='uppercut',     front=true},   -- Darnell's uppercut does not shake
	uppercutHit  = {a='uppercutHit'},                -- ... and neither does his uppercutHit
	hitHigh      = {a='hitHigh',      sh={0.0025, 0.15}},
	hitLow       = {a='hitLow',       sh={0.0025, 0.15}},
	hitSpin      = {a='hitSpin',      sh={0.0025, 0.15}},
	punchHigh    = {a='punchHigh',    alt=true, front=true},
	punchLow     = {a='punchLow',     alt=true, front=true},
}

-- type -> primitive. Keys are the chart strings with the 'weekend-1-' prefix stripped;
-- a missing key means the Haxe case list simply does not mention that type.
local PICO_HIT = {
	punchlow='punchLow', punchlowblocked='punchLow', punchlowdodged='punchLow', punchlowspin='punchLow',
	punchhigh='punchHigh', punchhighblocked='punchHigh', punchhighdodged='punchHigh', punchhighspin='punchHigh',
	blockhigh='block', blocklow='block', blockspin='block',
	dodgehigh='dodge', dodgelow='dodge', dodgespin='dodge',
	hithigh='hitHigh', hitlow='hitLow', hitspin='hitSpin',          -- "Pico ALWAYS gets punched"
	picouppercutprep='uppercutPrep', picouppercut='uppercutLand',
	darnelluppercutprep='idle', darnelluppercut='uppercutHit',
	idle='idle', fakeout='fakeout', reversefakeout='idle',
	taunt='tauntConditional', tauntforce='taunt',
}

local PICO_MISS = {
	punchlow='hitLow', punchlowblocked='hitLow', punchlowdodged='hitLow', punchlowspin='hitSpin',
	punchhigh='hitHigh', punchhighblocked='hitHigh', punchhighdodged='hitHigh', punchhighspin='hitSpin',
	blockhigh='hitHigh', blocklow='hitLow', blockspin='hitSpin',
	dodgehigh='hitHigh', dodgelow='hitLow', dodgespin='hitSpin',
	hithigh='hitHigh', hitlow='hitLow', hitspin='hitSpin',
	picouppercutprep='punchHighCant', picouppercut='uppercut',
	darnelluppercutprep='idle', darnelluppercut='uppercutHit',
	idle='idle', fakeout='hitHigh', reversefakeout='idle',
	taunt='tauntConditional', tauntforce='taunt',
}

local DARN_HIT = {
	punchlow='hitLow', punchlowblocked='block', punchlowdodged='dodge', punchlowspin='hitSpin',
	punchhigh='hitHigh', punchhighblocked='block', punchhighdodged='dodge', punchhighspin='hitSpin',
	blockhigh='punchHigh', blocklow='punchLow', blockspin='punchHigh',
	dodgehigh='punchHigh', dodgelow='punchLow', dodgespin='punchHigh',
	hithigh='punchHigh', hitlow='punchLow', hitspin='punchHigh',
	picouppercut='uppercutHit',                                          -- picouppercutprep: keep the old anim
	darnelluppercutprep='uppercutPrep', darnelluppercut='uppercut',
	idle='idle', fakeout='cringe', reversefakeout='fakeout',
	taunt='pissedConditional', tauntforce='pissed',
}

local DARN_MISS = {
	punchlow='punchLow', punchlowblocked='punchLow', punchlowdodged='punchLow', punchlowspin='punchLow',
	punchhigh='punchHigh', punchhighblocked='punchHigh', punchhighdodged='punchHigh', punchhighspin='punchHigh',
	blockhigh='punchHigh', blocklow='punchLow', blockspin='punchHigh',
	dodgehigh='punchHigh', dodgelow='punchLow', dodgespin='punchHigh',
	hithigh='punchHigh', hitlow='punchLow', hitspin='punchHigh',
	picouppercutprep='hitHighCant', picouppercut='dodge',
	darnelluppercutprep='uppercutPrep', darnelluppercut='uppercut',
	idle='idle', fakeout='cringe', reversefakeout='fakeout',
	taunt='pissedConditional', tauntforce='pissed',
}

local function spriteOf(state)
	return (state == pico) and 'boyfriend' or 'dad'
end

local function groupOf(state)
	return (state == pico) and 'boyfriendGroup' or 'dadGroup'
end

-- Haxe swaps boyfriendGroup and dadGroup inside FlxG.state.members. Same result here:
-- setObjectOrder() removes silently first, so the fighter being moved slides one slot the
-- other way when the *other* group lands on the index it just vacated. That puts `state`
-- exactly one place in front of (or behind) the other fighter, which is all draw order cares
-- about -- the absolute indices do not matter, and neither group ever crosses the stage
-- sprites because both indices are character indices.
local function moveUpDown(state, front)
	local mine = groupOf(state)
	local other = (mine == 'boyfriendGroup') and 'dadGroup' or 'boyfriendGroup'
	local okA, a = pcall(getObjectOrder, mine)
	local okB, b = pcall(getObjectOrder, other)
	if not okA or not okB or type(a) ~= 'number' or type(b) ~= 'number' or a < 0 or b < 0 then return end
	if (front and a < b) or (not front and a > b) then
		setObjectOrder(other, a)
	end
end

local function healthNow()
	local ok, value = pcall(getHealth)
	if ok and type(value) == 'number' then return value end
	return 1
end

local function prim(state, defs, key)
	local def = defs[key]
	if def == nil then return end

	local name = def.a
	if def.alt then
		-- doAlternate(): each fighter owns its own 1/2 counter, just like the Haxe classes.
		state.alt = not state.alt
		name = name .. (state.alt and '1' or '2')
	end

	playAnim(spriteOf(state), name, def.force ~= false)
	state.anim = name

	if def.sh then cameraShake('camGame', def.sh[1], def.sh[2]) end
	moveUpDown(state, def.front == true)
end

local function picoAct(key)
	if key == nil then return end
	if key == 'tauntConditional' then
		-- playTauntConditionalAnim(): taunt only straight after a fakeout, otherwise idle.
		prim(pico, PICO_P, (pico.anim == 'fakeout') and 'taunt' or 'idle')
	elseif key == 'punchHighCant' then
		prim(pico, PICO_P, 'punchHigh')
		pico.cantUppercut = true
	else
		prim(pico, PICO_P, key)
	end
end

local function darnAct(key)
	if key == nil then return end
	if key == 'pissedConditional' then
		prim(darn, DARN_P, (darn.anim == 'cringe') and 'pissed' or 'idle')
	elseif key == 'hitHighCant' then
		prim(darn, DARN_P, 'hitHigh')
		darn.cantUppercut = true
	else
		prim(darn, DARN_P, key)
	end
end

local function poor()
	return judgement == 'bad' or judgement == 'shit'
end

local function lowHealth()
	-- PlayState.instance.health <= 0.3 * 2 -- the bar is 0..2 in both engines.
	return healthNow() <= 0.6
end

local function lethal()
	-- willMissBeLethal(): health <= 0 && !practiceMode.
	return healthNow() <= 0 and practice ~= true
end

local function shortType(noteType)
	if type(noteType) ~= 'string' then return nil end
	if string.sub(noteType, 1, 10) == 'weekend-1-' then return string.sub(noteType, 11) end
	return noteType
end

local function trackJudgement()
	if type(score) ~= 'number' then return end
	local delta = score - lastScore
	lastScore = score
	if delta == 350 then judgement = 'sick'
	elseif delta == 200 then judgement = 'good'
	elseif delta == 100 then judgement = 'bad'
	elseif delta == 50 then judgement = 'shit'
	end
end

local function usable()
	if inGameOver then return false end        -- LIMUL-GAMEOVER-GUARD: the death anim owns the fighters
	return fightArmed
end

local function noteEventHit(t)
	-- PicoBlazinHandler.noteHit
	if poor() and lowHealth() and darn.anim == 'uppercutPrep' then
		prim(pico, PICO_P, 'punchHigh')
	elseif pico.cantUppercut then
		prim(pico, PICO_P, 'block')
		pico.cantUppercut = false
	else
		picoAct(PICO_HIT[t])
	end

	-- DarnellBlazinHandler.noteHit
	if poor() and lowHealth() and getRandomInt(1, 100) <= 30 then
		prim(darn, DARN_P, 'uppercutPrep')
		return
	end
	if darn.cantUppercut then
		prim(darn, DARN_P, 'punchHigh')
		return
	end
	darnAct(DARN_HIT[t])
	darn.cantUppercut = false
end

local function noteEventMiss(t)
	-- PicoBlazinHandler.noteMiss
	if darn.anim == 'uppercut' or darn.anim == 'uppercut-loop' or darn.anim == 'uppercut-hold' then
		prim(pico, PICO_P, 'uppercutHit')
	elseif lethal() then
		prim(pico, PICO_P, 'hitLow')
	elseif pico.cantUppercut then
		prim(pico, PICO_P, 'hitHigh')   -- the flag is deliberately not cleared here
	else
		picoAct(PICO_MISS[t])
	end

	-- DarnellBlazinHandler.noteMiss
	if darn.anim == 'uppercutPrep' then
		prim(darn, DARN_P, 'uppercut')  -- FINISH HIM!
		return
	end
	if lethal() then
		prim(darn, DARN_P, 'punchLow')
		return
	end
	if darn.cantUppercut then
		prim(darn, DARN_P, 'punchHigh')
		return
	end
	darnAct(DARN_MISS[t])
	darn.cantUppercut = false
end

local function noteEventMissPress()
	-- PicoBlazinHandler / DarnellBlazinHandler noteMissPress, direction is ignored by both.
	if lethal() then
		prim(pico, PICO_P, 'hitLow')    -- Darnell lands the punch that finishes Pico
		prim(darn, DARN_P, 'punchLow')
		return
	end
	prim(pico, PICO_P, 'punchHigh')     -- Pico throws wild punches into the rain...
	if getRandomInt(1, 100) <= 50 then
		prim(darn, DARN_P, 'dodge')     -- ...and Darnell sidesteps or guards, 50/50
	else
		prim(darn, DARN_P, 'block')
	end
end

function goodNoteHit(membersIndex, lane, noteType, isSustainNote)
	trackJudgement()
	if not usable() or isSustainNote then return end
	local t = shortType(noteType)
	if t == nil then return end
	noteEventHit(t)
end

-- PhillyBlazin.hx:253-258 -- the opponent landing its own note is Pico failing his.
function opponentNoteHit(membersIndex, lane, noteType, isSustainNote)
	if not usable() or isSustainNote then return end
	local t = shortType(noteType)
	if t == nil then return end
	noteEventMiss(t)
end

function noteMiss(membersIndex, lane, noteType, isSustainNote)
	trackJudgement()
	if not usable() or isSustainNote then return end
	local t = shortType(noteType)
	if t == nil then return end
	noteEventMiss(t)
end

function noteMissPress(direction)
	trackJudgement()
	if not usable() then return end
	local ok, stunned = pcall(getProperty, 'boyfriend.stunned')
	if ok and stunned == true then return end
	noteEventMissPress()
end
