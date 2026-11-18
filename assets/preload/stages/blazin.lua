function onCreatePost()
if not lowQuality then
	-- Limul Engine: 'shaders/street' wymaga runtime shadera, którego ta wersja silnika
	-- nie kompiluje (flixel-addons 2.11 nie ma FlxRuntimeShader). Błąd makeLuaSprite przerywał
	-- całą funkcję, więc teraz warstwa jest pomijana, jeśli nie ma pliku.
	if checkFileExists('images/shaders/street.png') then
		makeLuaSprite("overlay", "shaders/street", -1000, -1250)
		setProperty("overlay.alpha", 0.45)
		scaleObject('overlay', 1.5, 1.5);
		setBlendMode('overlay', 'normal')
		addLuaSprite("overlay", true)
	end
	end
end

function onCreate()
	makeLuaSprite('skyAdditive', 'phillyBlazin/skyBlur', -600, -175);
	scaleObject('skyAdditive', 1.75, 1.75);
	setScrollFactor('skyAdditive', 0, 0);

	makeAnimatedLuaSprite('lightning', 'phillyBlazin/lightning', 50, -300);
	addAnimationByPrefix('lightning', 'strike', 'lightning0', 24, false);
	setProperty('lightning.flipX', false);
	scaleObject('lightning', 1.75, 1.75);
	setScrollFactor('lightning', 0, 0);
	setProperty('lightning.alpha', 0);
	runTimer('lightningTimer', getRandomInt(7, 15));

	makeLuaSprite('phillyForegroundCity', 'phillyBlazin/streetBlur', -600, -175);
	scaleObject('phillyForegroundCity', 1.75, 1.75);
	setScrollFactor('phillyForegroundCity', 0, 0);

	-- Limul Engine: oryginalna ścieżka to 'phillyBlazin/' (urwana nazwa pliku), więc
	-- makeLuaSprite rzucał błędem i przerywał onCreate() - przez to ani niebo, ani pioruny,
	-- ani foreground nie trafiały na scenę. Warstwa wróci, gdy w modzie pojawi się
	-- images/phillyBlazin/foregroundMultiply.png.
	if checkFileExists('images/phillyBlazin/foregroundMultiply.png') then
		makeLuaSprite('foregroundMultiply', 'phillyBlazin/foregroundMultiply', -600, -175);
		scaleObject('foregroundMultiply', 1, 1);
		setScrollFactor('foregroundMultiply', 1, 1);
	end

	makeLuaSprite('additionalLighten', 'empty', -600, -175);
	makeGraphic('additionalLighten', 2500, 2500, 'FFFFFF');
	setScrollFactor('additionalLighten', 0, 0);
	setProperty('additionalLighten.alpha', 0);

	-- Limul Engine: flat sky backdrop pinned to the camera: at this stage zoom the camera
	-- sees more world than the painted skybox covers, so the corners went black. This is
	-- the backmost layer, only visible where the real art does not reach the screen edge.
	makeLuaSprite('limulSkyFill', 'empty', -500, -500);
	makeGraphic('limulSkyFill', 2600, 1800, '4B4B4B');
	setScrollFactor('limulSkyFill', 0, 0);
	addLuaSprite('limulSkyFill', false);

	addLuaSprite('skyAdditive', false);
	addLuaSprite('lightning', false);
	addLuaSprite('phillyForegroundCity', false);
	if luaSpriteExists('foregroundMultiply') then
		addLuaSprite('foregroundMultiply', false);
	end
	addLuaSprite('additionalLighten', false);
end

function onSongStart()
	setProperty('lightning.alpha', 1);
end

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == 'lightningTimer' then
		playAnim('lightning', 'strike', false);
		playSound('Lightning'..getRandomInt(1, 3), 1)
		runTimer('lightningTimer', getRandomInt(7, 15));
		setProperty('additionalLighten.alpha', 0.3);
		doTweenAlpha('additionalLighten', 'additionalLighten', 0, 1, 'linear')
	end
end

function onStartCountdown()
	setProperty('dad.scale.x', 1.75);
	setProperty('dad.scale.y', 1.75);
	setProperty('boyfriend.scale.x', 1.75);
	setProperty('boyfriend.scale.y', 1.75);
	-- Limul Engine: this grey desaturation was authored to sit *under* the
	-- 'shaders/street' colour overlay. This build cannot compile that overlay
	-- (flixel-addons 2.11 has no FlxRuntimeShader), so onCreatePost skips it and the
	-- tint landed on its own -- flixel's ColorTween also rewrites sprite.alpha every
	-- frame, which is why Pico and Darnell read as washed out / see-through during
	-- gameplay while the cutscene looked fine. Keep the effect only for builds that
	-- actually have the overlay asset; drop the file in and it comes back.
	if checkFileExists('images/shaders/street.png') then
		doTweenColor('1','gf','8a8a8a', 0.1, 'linear')
		doTweenColor('2','abotEyeBack','8a8a8a', 0.1, 'linear')
		doTweenColor('3','abotEyes','8a8a8a', 0.1, 'linear')
		doTweenColor('4','abotBG','8a8a8a', 0.1, 'linear')
		doTweenColor('5','abot','8a8a8a', 0.1, 'linear')
		doTweenColor('6','dad','e3e3e3', 0.1, 'linear')
		doTweenColor('7','boyfriend','e3e3e3', 0.1, 'linear')
	end
end

-- Limul Engine: flixel's ColorTween writes `sprite.alpha = color.alphaFloat` on
-- every frame it runs, and these colour tweens are the only code in this mod
-- that touches the characters during gameplay. Snap the alphas back to fully
-- opaque once the tint lands so a bad start colour can never leave Pico or
-- Darnell see-through.
function onTweenCompleted(tag)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == '5' or tag == '6' or tag == '7' then
		setProperty('gf.alpha', 1)
		setProperty('dad.alpha', 1)
		setProperty('boyfriend.alpha', 1)
	end
end
