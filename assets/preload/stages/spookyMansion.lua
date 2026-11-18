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
		if not stringEndsWith(_G[character..'Name'], '-dark') then
			setProperty(character..'.color', 0x070711)
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
		for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
			-- LIMUL-DARK-FLASH: Erect's '-dark' branch hides the real sprite and shows a lit clone
			-- built with createInstance('objects.Character'). This 0.6.3 fork has no createInstance /
			-- addInstance (bf-dark, spooky-dark and gf-dark stub both to no-ops), so the clone is never
			-- created and hiding the sprite just blanks the characters on every thunder crack.
			-- Fall through to the stage's own non-dark trick: a white colour flash.
			setProperty(character..'.color', 0xFFFFFF)
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
		for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
			setProperty(character..'.color', 0x070711)
		end
	end
	if tag == 'startLightingBack' then
		for i, stageObject in ipairs({'corridor', 'stairs'}) do
			setProperty(stageObject..'.alpha', 1)
			doTweenAlpha(stageObject..'alphaBack', stageObject, 0, 1.5, 'linear')
		end
		for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
			-- LIMUL-DARK-FLASH: same reason as in strikeLighting - the lit clone does not exist in
			-- this fork, so this second alpha dip (0 -> 1 over 1.5s) is what made the characters
			-- fade back in from invisible after each thunder crack.
			setProperty(character..'.color', 0xFFFFFF)
			doTweenColor(character..'colorBack', character, '070711', 1.5, 'linear')
		end
	end
end