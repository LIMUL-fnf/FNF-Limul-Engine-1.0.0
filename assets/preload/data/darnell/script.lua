-- LIMUL-WEEKEND1-INTRO (2026-11-15)
-- Story-mode intro for Darnell, ported from Psych 1.0.4 / JS Engine PhillyStreets.hx:
-- the darnellCutscene video, then the live 10 s can scene.
-- Pico is a Psych 1.0.4 multi-atlas character (characters/Pico_Playable, characters/Pico_Intro),
-- so intro1/intro2 are regular animations and nothing swaps his frames mid-song.
-- ENTER/SPACE skips the live scene, like the original CutsceneHandler.

local introState = 0 -- 0 = idle, 1 = video, 2 = live scene, 3 = done
local sceneActive = false
local skipArmed = false

local TIMERS = {
	'limulIntroMusic', 'limulIntroZoom', 'limulIntroLight', 'limulIntroCock',
	'limulIntroCasing', 'limulIntroKick', 'limulIntroKnee', 'limulIntroShoot',
	'limulIntroDadLaugh', 'limulIntroNeneLaugh', 'limulIntroEnd', 'limulIntroSkip',
	'limulIntroDarkenArm',
}

function onCreate()
	if not isStoryMode then return end
	precacheImage('characters/Pico_Intro')
	precacheImage('PicoBullet')
	precacheMusic('darnellCanCutscene')
	precacheSound('cutscene/darnell_laugh')
	precacheSound('cutscene/nene_laugh')
	precacheSound('Darnell_Lighter')
	precacheSound('Kick_Can_UP')
	precacheSound('Kick_Can_FORWARD')
	precacheSound('Gun_Prep')
	for i = 1, 4 do precacheSound('shot'..i) end
end

function onStartCountdown()
	if not isStoryMode or introState >= 3 then return Function_Continue end

	if introState == 0 then
		introState = 1
		setProperty('inCutscene', true)
		if weekend1CreateCan ~= nil then weekend1CreateCan(1450, 805) end
		startVideo('darnellCutscene')
		return Function_Stop
	end

	if introState == 1 then
		introState = 2
		startLiveCutscene()
		return Function_Stop
	end

	return Function_Continue
end

function startLiveCutscene()
	sceneActive = true
	setProperty('inCutscene', true)
	setProperty('camHUD.alpha', 0)
	playAnim('boyfriend', 'intro1', true)

	runHaxeCode([[
		game.cameraSpeed = 0;
		game.moveCamera(false);
		game.camFollow.x += 250;
		game.camFollowPos.setPosition(game.camFollow.x, game.camFollow.y);
		FlxG.camera.zoom = 1.3;
		FlxG.camera.fade(0xFF000000, 2, true, null, true);
	]])

	runTimer('limulIntroMusic', 0.01)
	runTimer('limulIntroZoom', 2.0)
	runTimer('limulIntroLight', 5.0)
	runTimer('limulIntroCock', 6.0)
	runTimer('limulIntroCasing', 6.166)
	runTimer('limulIntroKick', 6.4)
	runTimer('limulIntroKnee', 6.8)
	runTimer('limulIntroShoot', 7.1)
	runTimer('limulIntroDadLaugh', 7.9)
	runTimer('limulIntroNeneLaugh', 8.2)
	runTimer('limulIntroEnd', 10.0)
	runTimer('limulIntroSkip', 0.7)
end

function finishCutscene()
	if not sceneActive then return end
	sceneActive = false
	skipArmed = false

	for i = 1, #TIMERS do
		cancelTimer(TIMERS[i])
	end

	-- Native first: even if the Haxe block below fails, the song must not start with a hidden HUD.
	setProperty('camHUD.alpha', 1)
	setProperty('cameraSpeed', 1)
	setProperty('inCutscene', false)

	runHaxeCode([[
		var cutsceneMusic = game.modchartSounds.get('limulCutsceneMusic');
		if (cutsceneMusic != null) {
			cutsceneMusic.stop();
			game.modchartSounds.remove('limulCutsceneMusic');
		}
		FlxTween.cancelTweensOf(game.camFollowPos);
		FlxTween.cancelTweensOf(FlxG.camera);

		var bf = game.boyfriend;
		bf.dance();

		game.dad.dance();
		if (game.gf != null) {
			game.gf.dance();
		}

		if (game.weekend1Can != null) {
			game.weekend1Can.visible = false;
			game.weekend1Can.active = false;
			game.weekend1Can.canAtlas.visible = false;
			game.weekend1Can.explosion.visible = false;
		}

		game.moveCamera(true);
		game.camFollowPos.setPosition(game.camFollow.x, game.camFollow.y);
		FlxTween.cancelTweensOf(FlxG.camera);
		FlxTween.tween(FlxG.camera, {zoom: game.defaultCamZoom}, 1, {ease: FlxEase.sineInOut});
	]])

	introState = 3
	startCountdown()
end

function onUpdate(elapsed)
	if sceneActive and skipArmed and (keyJustPressed('accept') or keyJustPressed('space')) then
		finishCutscene()
	end
end

-- LIMUL-DARKEN-PROPS: the shot pulls the light out of the street for a beat (1.0.4
-- PhillyStreets.darkenStageProps). One superset list filtered by luaSpriteExists() so every
-- stage dims exactly the layers it built; rainFilter stays out (shader, no colour).
local DARKENABLE = {
	'sky', 'sky1', 'sky2', 'sky3', 'skyline', 'city', 'constructionSite', 'highwayLights',
	'highwayLightMap', 'highway', 'smog', 'cars1', 'cars2', 'trafficLight', 'trafficLightMap',
	'street', 'sprayCans',
	'phillySkybox', 'phillySkyline', 'phillyForegroundCity', 'phillyConstruction',
	'phillyHighwayLights', 'phillyHighwayLights_lightmap', 'phillyHighway', 'phillySmog',
	'phillyCars1', 'phillyCars2', 'phillyTraffic', 'phillyTraffic_lightmap', 'phillyForeground',
	'spraycanPile', 'limulSkyFill',
	'gradient1', 'gradient2', 'mist', 'paper'
}

local function tintStageProps(hex)
	for i = 1, #DARKENABLE do
		local name = DARKENABLE[i]
		if luaSpriteExists(name) then
			setProperty(name..'.color', getColorFromHex(hex))
		end
	end
end

local function darkenStageProps()
	tintStageProps('111111')
	runTimer('limulIntroDarkenLift', 1 / 24)
end

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'limulIntroDarkenLift' then
		for i = 1, #DARKENABLE do
			local name = DARKENABLE[i]
			if luaSpriteExists(name) then
				setProperty(name..'.color', getColorFromHex('222222'))
				doTweenColor('limulIntroDarken'..name, name, 'FFFFFF', 1.4, 'linear')
			end
		end
		return
	end

	if not sceneActive then return end

	if tag == 'limulIntroSkip' then
		skipArmed = true
	elseif tag == 'limulIntroMusic' then
		-- A plain FlxSound, not FlxG.sound.music: the reference cutscene track must not drive
		-- Conductor, otherwise beatHit() dances the cast every beat and the held poses snap back.
		runHaxeCode([[
			var snd = FlxG.sound.play(Paths.music('darnellCanCutscene'), 1, true);
			game.modchartSounds.set('limulCutsceneMusic', snd);
		]])
	elseif tag == 'limulIntroZoom' then
		runHaxeCode([[
			game.moveCamera(true);
			game.camFollow.x += 100;
			FlxTween.cancelTweensOf(game.camFollowPos);
			FlxTween.tween(game.camFollowPos, {x: game.camFollow.x + 100, y: game.camFollow.y}, 2.5, {ease: FlxEase.quadInOut});
			FlxTween.cancelTweensOf(FlxG.camera);
			FlxTween.tween(FlxG.camera, {zoom: 0.66}, 2.5, {ease: FlxEase.quadInOut});
		]])
	elseif tag == 'limulIntroLight' then
		playAnim('dad', 'lightCan', true)
		playSound('Darnell_Lighter', 1)
	elseif tag == 'limulIntroCock' then
		playAnim('boyfriend', 'cock', true)
			runHaxeCode([[
			FlxTween.cancelTweensOf(game.camFollowPos);
			FlxTween.tween(game.camFollowPos, {x: game.camFollow.x + 180}, 0.4, {ease: FlxEase.backOut});
		]])
		playSound('Gun_Prep', 1)
	elseif tag == 'limulIntroCasing' then
		runHaxeCode([[
			if (!ClientPrefs.lowQuality) {
				var casing = new FlxSprite(game.boyfriend.x + 250, game.boyfriend.y + 100);
				casing.frames = Paths.getSparrowAtlas('PicoBullet');
				casing.animation.addByPrefix('pop', 'Pop0', 24, false);
				casing.animation.addByPrefix('idle', 'Bullet0', 24, true);
				casing.animation.play('pop', true);
				casing.animation.callback = function(name, frameNumber, frameIndex) {
					if (name == 'pop' && frameNumber == 40) {
						casing.x = casing.x + casing.frame.offset.x - 1;
						casing.y = casing.y + casing.frame.offset.y + 1;
						casing.angle = 125.1;
						var randomFactorA = FlxG.random.float(3, 10);
						var randomFactorB = FlxG.random.float(1.0, 2.0);
						casing.velocity.x = 20 * randomFactorB;
						casing.drag.x = randomFactorA * randomFactorB;
						casing.angularVelocity = 100;
						casing.angularDrag = (casing.drag.x / casing.velocity.x) * 100;
						casing.animation.play('idle');
						casing.animation.callback = null;
					}
				};
				game.add(casing);
			}
		]])
	elseif tag == 'limulIntroKick' then
		playAnim('dad', 'kickCan', true)
		if weekend1CanStart ~= nil then weekend1CanStart() end
		playSound('Kick_Can_UP', 1)
	elseif tag == 'limulIntroKnee' then
		playAnim('dad', 'kneeCan', true)
		playSound('Kick_Can_FORWARD', 1)
	elseif tag == 'limulIntroShoot' then
		playAnim('boyfriend', 'intro2', true)
			runHaxeCode([[
			FlxTween.cancelTweensOf(game.camFollowPos);
			FlxTween.tween(game.camFollowPos, {x: game.camFollow.x + 100}, 2.5, {ease: FlxEase.quadInOut});
		]])
		playSound('shot'..getRandomInt(1, 4), 1)
		if weekend1CanShot ~= nil then weekend1CanShot() end
		runTimer('limulIntroDarkenArm', 1 / 24)
	elseif tag == 'limulIntroDarkenArm' then
		darkenStageProps()
	elseif tag == 'limulIntroDadLaugh' then
		playAnim('dad', 'laughCutscene', true)
		playSound('cutscene/darnell_laugh', 0.6)
	elseif tag == 'limulIntroNeneLaugh' then
		playAnim('gf', 'laughCutscene', true)
		playSound('cutscene/nene_laugh', 0.6)
	elseif tag == 'limulIntroEnd' then
		finishCutscene()
	end
end
