-- LIMUL-DARK-FLASH (2026-11-04): the Erect original handles the lightning on two paths, and which
-- one runs depends on whether the character has a '-dark' art variant:
--
--   '-dark' character  -> the stage sets the sprite's alpha to 0 while the bolt is up, and the
--                         character script's own createInstance('objects.Character') Light clone
--                         (spooky-dark.lua) is what the player actually sees flashing. This 0.6.3
--                         fork registers neither createInstance nor addInstance, so the clone is
--                         never made and hiding the silhouette just blanks the character - the
--                         bug these three functions exist to avoid. A dark sprite is already the
--                         dark art, so the honest fallback is to leave it alone and let the
--                         full-screen ADD-blend 'lightingFlash' do the brightening; it draws in
--                         front of everything (addLuaSprite(..., true)), characters included.
--                         1.0.4's own native Spooky.hx does exactly that: white overlay, no
--                         character surgery.
--   normal character   -> the stage tints it DARK_TINT from onCreate, so the flash is a real
--                         colour change: white for a beat, then back to DARK_TINT over 1.5s.
--
-- Spookezone Erect's charts (spookeez/south Erect + Nightmare) ship player1 'bf-dark' and
-- player2 'spooky-dark', so path one is the live one here.
local CHARACTERS = {'boyfriend', 'dad', 'gf'}
local DARK_TINT = 0x070711

local function limulCharacterName(who)
	local name = _G[who..'Name']
	return type(name) == 'string' and name or ''
end

local function limulIsDarkVariant(who)
	return stringEndsWith(limulCharacterName(who), '-dark')
end

function onCreate()
	makeAnimatedLuaSprite('outdoorTrees', 'spookyMansion/erect/bgtrees', 190, 30)
	addAnimationByPrefix('outdoorTrees', 'anim', 'bgtrees', 5)
	setScrollFactor('outdoorTrees', 0.85, 0.85)
	addLuaSprite('outdoorTrees')
	
	makeLuaSprite('corridorDark', 'spookyMansion/erect/bgDark', -360, -220)
	addLuaSprite('corridorDark')
	
	if lowQuality == false then
		makeLuaSprite('corridor', 'spookyMansion/erect/bgLight', -360, -220)
		addLuaSprite('corridor')
		setProperty('corridor.alpha', 0)

		makeLuaSprite('stairsDark', 'spookyMansion/erect/stairsDark', 966, -225)
		addLuaSprite('stairsDark', true)

		makeLuaSprite('stairs', 'spookyMansion/erect/stairsLight', 966, -225)
		addLuaSprite('stairs', true)
		setProperty('stairs.alpha', 0)
	end

	if flashingLights == true then
		makeLuaSprite('lightingFlash', '', -800, -400)
		makeGraphic('lightingFlash', screenWidth * 2, screenHeight * 2, 'FFFFFF')
		setScrollFactor('lightingFlash', 0, 0)
		setBlendMode('lightingFlash', 'ADD')
		addLuaSprite('lightingFlash', true)
		setProperty('lightingFlash.alpha', 0)
	end
	precacheSound('thunder_1')
	precacheSound('thunder_2')
end

function onCreatePost()
	if shadersEnabled == true then
        initLuaShader('rain')
        setSpriteShader('outdoorTrees', 'rain')
        setShaderFloat('outdoorTrees', 'uScale', screenHeight / 200 * 2)
        setShaderFloat('outdoorTrees', 'uIntensity', 0.4)
        setShaderBool('outdoorTrees', 'uSpriteMode', true)
		setShaderFloatArray('outdoorTrees', 'uRainColor', {102 / 255, 128 / 255, 204 / 255})
		-- LIMUL-SHADER-GUARD: setSpriteShader is a no-op in this fork (PlayState.createRuntimeShader
		-- always returns null), so outdoorTrees.shader stays null here and the raw call threw
		-- "Invalid access to field setFloatArray" from hscript on every tree frame.
		-- tankErect/schoolErect wrap the same body in a null check; do the same.
		runHaxeCode([[
            var outdoorTrees = game.getLuaObject('outdoorTrees');
            outdoorTrees.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
            {
                // No runtime shader attached -> nothing to push frame bounds into.
                if (outdoorTrees.shader != null) {
                    outdoorTrees.shader.setFloatArray('uFrameBounds', [outdoorTrees.frame.uv.x, outdoorTrees.frame.uv.y, outdoorTrees.frame.uv.width, outdoorTrees.frame.uv.height]);
                }
            }
        ]])

		-- Need to set up those, or the rain will freak out completely
		setShaderFloatArray('outdoorTrees', 'uScreenResolution', {screenWidth, screenHeight})
		setShaderFloatArray('outdoorTrees', 'uCameraBounds', {0, 0, screenWidth, screenHeight})
    end

	--[[
		This is to make the stage usable with other characters that don't have their dark varient.
		Go see the scripts for 'bf-dark', 'spooky-dark', and 'gf-dark' to see how they work,
		and use it for other characters that have dark varients (like Pico for example).
	]]
	for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
		-- LIMUL-DARK-FLASH: boyfriendName/dadName/gfName are globals this engine does push
		-- (FunkinLua.hx:197-199, straight off SONG.player1/player2/gfVersion), but a chart without a
		-- gfVersion leaves one nil, and stringEndsWith's String argument makes a nil call throw -
		-- which used to abort the rest of onCreate. limulCharacterName returns '' for that, so the
		-- character is simply treated as a normal one and gets tinted like the original intends.
		if not limulIsDarkVariant(character) then
			setProperty(character..'.color', DARK_TINT)
		end
	end
end

local elapsedTime = 0
function onUpdate(elapsed)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	-- Makes the rain active.
    if shadersEnabled == true then
        elapsedTime = elapsedTime + elapsed
		setShaderFloat('outdoorTrees', 'uTime', elapsedTime)
    end
end

-- All of this down below is to make the mechanics of the stage work. 
lastLightningStrike = 0
lightningInterval = 8
function onBeatHit()
	if getRandomBool(10) and curBeat > lastLightningStrike + lightningInterval then
		strikeLighting(curBeat)
	end
end

-- This is the function that makes the lighting strike and affect the background and characters.
function strikeLighting(beatHit)
	lastLightningStrike = beatHit
	lightningInterval = getRandomInt(8, 24)
	local soundNum = getRandomInt(1, 2)
	playSound('thunder_'..soundNum)
	
	if flashingLights == true then
		setProperty('lightingFlash.alpha', 0.4)
		doTweenAlpha('flashAlphaTween', 'lightingFlash', 0.5, 0.075, 'linear')
		runTimer('delayFlashAphaBack', 0.15)
	end

	if lowQuality == false then
		for i, stageObject in ipairs({'corridor', 'stairs'}) do
			setProperty(stageObject..'.alpha', 1)
		end
		for i, character in ipairs(CHARACTERS) do
			-- LIMUL-DARK-FLASH: see the note at the top of this file. A '-dark' character keeps its
			-- own art and its own alpha (there is no Light clone to swap in here), so only the
			-- tinted-normal characters get the white flash.
			if not limulIsDarkVariant(character) then
				setProperty(character..'.color', 0xFFFFFF)
			end
		end
		runTimer('delayLightingBack', 0.06)
		runTimer('startLightingBack', 0.12)
	end

	if cameraZoomOnBeat == true then
		setProperty('camGame.zoom', getProperty('camGame.zoom') + 0.015)
		setProperty('camHUD.zoom', getProperty('camHUD.zoom') + 0.03)

		if getProperty('camZooming') == false then
			doTweenZoom('zoomBack', 'camGame', getProperty('defaultCamZoom'), 0.5, 'linear')
			doTweenZoom('zoomBackHUD', 'camHUD', 1, 0.5, 'linear')
		end
	end

	playAnim('boyfriend', 'scared', true)
	playAnim('gf', 'scared', true)
end

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == 'delayFlashAphaBack' then
		doTweenAlpha('flashAphaBack', 'lightingFlash', 0, 0.25, 'linear')
	end
	if tag == 'delayLightingBack' then
		for i, stageLightingt in ipairs({'corridor', 'stairs'}) do
			-- LIMUL-FIX: this body used 'stageObject', a loop local from strikeLighting, so it was nil
			-- here; concatenating it threw a Lua error and aborted the whole restore.
			setProperty(stageLightingt..'.alpha', 0)
		end
		for i, character in ipairs(CHARACTERS) do
			-- LIMUL-DARK-FLASH: only the tinted-normal characters were flashed, so only they go back
			-- to the stage tint. See the note at the top of this file.
			if not limulIsDarkVariant(character) then
				setProperty(character..'.color', DARK_TINT)
			end
		end
	end
	if tag == 'startLightingBack' then
		for i, stageObject in ipairs({'corridor', 'stairs'}) do
			setProperty(stageObject..'.alpha', 1)
			doTweenAlpha(stageObject..'alphaBack', stageObject, 0, 1.5, 'linear')
		end
		for i, character in ipairs(CHARACTERS) do
			if not limulIsDarkVariant(character) then
				-- LIMUL-DARK-FLASH: the characters a '-dark' script would normally swap for a lit
				-- clone are left untouched here, because that clone cannot exist in this fork.
				-- '070711' reaches the engine through CoolUtil.colorFromString now, so this tween ends
				-- on the opaque stage tint instead of the old clamped 0x7FFFFFFF (alpha 0.498), which
				-- is what faded every character to half transparent after each bolt.
				setProperty(character..'.color', 0xFFFFFF)
				doTweenColor(character..'colorBack', character, '070711', 1.5, 'linear')
			end
		end
	end
end