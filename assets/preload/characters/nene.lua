local abotBeatRandom1 = 1
local abotBeatRandom2 = 1
local abotBeatRandom3 = 1
local abotBeatRandom4 = 1
local abotBeatRandom5 = 1
local abotBeatRandom6 = 1
local abotBeatRandom7 = 1
local health = 1
local abotEyes = 0
local viz1Value = 1
local viz2Value = 1
local viz3Value = 1
local viz4Value = 1
local viz5Value = 1
local viz6Value = 1
local viz7Value = 1

function onCreate()

	makeLuaSprite('abotEyeBack', 'empty', getProperty('gf.x') -80, getProperty('gf.y') +550);
	makeGraphic('abotEyeBack', 110, 70, 'FFFFFF');

	makeAnimatedLuaSprite('abotEyes', 'characters/abot/systemEyes', getProperty('gf.x') -76, getProperty('gf.y') +549)
	addAnimationByPrefix('abotEyes', 'l', 'Left', 24, false)
	addAnimationByPrefix('abotEyes', 'r', 'Right', 24, false)

	makeLuaSprite('abotBG', 'characters/abot/stereoBG', getProperty('gf.x') +18, getProperty('gf.y') +318);
	scaleObject('abotBG', 1.05, 1.05);

	makeAnimatedLuaSprite('abotViz1', 'aBotViz', getProperty('gf.x') +66, getProperty('gf.y') +390);
	addAnimationByPrefix('abotViz1', 'viz1', 'viz11', 24, false);
	addAnimationByPrefix('abotViz1', 'viz2', 'viz12', 24, false);
	addAnimationByPrefix('abotViz1', 'viz3', 'viz13', 24, false);
	addAnimationByPrefix('abotViz1', 'viz4', 'viz14', 24, false);
	addAnimationByPrefix('abotViz1', 'viz5', 'viz15', 24, false);
	addAnimationByPrefix('abotViz1', 'viz6', 'viz16', 24, false);
	setProperty('abotViz1.flipX', false);
	scaleObject('abotViz1', 1, 1);

	makeAnimatedLuaSprite('abotViz2', 'aBotViz', getProperty('gf.x') +128, getProperty('gf.y') +383);
	addAnimationByPrefix('abotViz2', 'viz1', 'viz21', 24, false);
	addAnimationByPrefix('abotViz2', 'viz2', 'viz22', 24, false);
	addAnimationByPrefix('abotViz2', 'viz3', 'viz23', 24, false);
	addAnimationByPrefix('abotViz2', 'viz4', 'viz24', 24, false);
	addAnimationByPrefix('abotViz2', 'viz5', 'viz25', 24, false);
	addAnimationByPrefix('abotViz2', 'viz6', 'viz26', 24, false);
	setProperty('abotViz2.flipX', false);
	scaleObject('abotViz2', 1, 1);

	makeAnimatedLuaSprite('abotViz3', 'aBotViz', getProperty('gf.x') +185, getProperty('gf.y') +380);
	addAnimationByPrefix('abotViz3', 'viz1', 'viz31', 24, false);
	addAnimationByPrefix('abotViz3', 'viz2', 'viz32', 24, false);
	addAnimationByPrefix('abotViz3', 'viz3', 'viz33', 24, false);
	addAnimationByPrefix('abotViz3', 'viz4', 'viz34', 24, false);
	addAnimationByPrefix('abotViz3', 'viz5', 'viz35', 24, false);
	addAnimationByPrefix('abotViz3', 'viz6', 'viz36', 24, false);
	setProperty('abotViz3.flipX', false);
	scaleObject('abotViz3', 1, 1);

	makeAnimatedLuaSprite('abotViz4', 'aBotViz', getProperty('gf.x') +251, getProperty('gf.y') +380);
	addAnimationByPrefix('abotViz4', 'viz1', 'viz41', 24, false);
	addAnimationByPrefix('abotViz4', 'viz2', 'viz42', 24, false);
	addAnimationByPrefix('abotViz4', 'viz3', 'viz43', 24, false);
	addAnimationByPrefix('abotViz4', 'viz4', 'viz44', 24, false);
	addAnimationByPrefix('abotViz4', 'viz5', 'viz45', 24, false);
	addAnimationByPrefix('abotViz4', 'viz6', 'viz46', 24, false);
	setProperty('abotViz4.flipX', false);
	scaleObject('abotViz4', 1, 1);

	makeAnimatedLuaSprite('abotViz5', 'aBotViz', getProperty('gf.x') +308, getProperty('gf.y') +380);
	addAnimationByPrefix('abotViz5', 'viz1', 'viz51', 24, false);
	addAnimationByPrefix('abotViz5', 'viz2', 'viz52', 24, false);
	addAnimationByPrefix('abotViz5', 'viz3', 'viz53', 24, false);
	addAnimationByPrefix('abotViz5', 'viz4', 'viz54', 24, false);
	addAnimationByPrefix('abotViz5', 'viz5', 'viz55', 24, false);
	addAnimationByPrefix('abotViz5', 'viz6', 'viz56', 24, false);
	setProperty('abotViz5.flipX', false);
	scaleObject('abotViz5', 1, 1);

	makeAnimatedLuaSprite('abotViz6', 'aBotViz', getProperty('gf.x') +364, getProperty('gf.y') +385);
	addAnimationByPrefix('abotViz6', 'viz1', 'viz61', 24, false);
	addAnimationByPrefix('abotViz6', 'viz2', 'viz62', 24, false);
	addAnimationByPrefix('abotViz6', 'viz3', 'viz63', 24, false);
	addAnimationByPrefix('abotViz6', 'viz4', 'viz64', 24, false);
	addAnimationByPrefix('abotViz6', 'viz5', 'viz65', 24, false);
	addAnimationByPrefix('abotViz6', 'viz6', 'viz66', 24, false);
	setProperty('abotViz6.flipX', false);
	scaleObject('abotViz6', 1, 1);

	makeAnimatedLuaSprite('abotViz7', 'aBotViz', getProperty('gf.x') +416, getProperty('gf.y') +393);
	addAnimationByPrefix('abotViz7', 'viz1', 'viz71', 24, false);
	addAnimationByPrefix('abotViz7', 'viz2', 'viz72', 24, false);
	addAnimationByPrefix('abotViz7', 'viz3', 'viz73', 24, false);
	addAnimationByPrefix('abotViz7', 'viz4', 'viz74', 24, false);
	addAnimationByPrefix('abotViz7', 'viz5', 'viz75', 24, false);
	addAnimationByPrefix('abotViz7', 'viz6', 'viz76', 24, false);
	setProperty('abotViz7.flipX', false);
	scaleObject('abotViz7', 1, 1);

	makeAnimatedLuaSprite('abot', 'characters/abot/abotSystem', getProperty('gf.x') -135, getProperty('gf.y') +310)
	-- Limul Engine: loop = false, exactly as the KA-DE original has it. abotSystem.xml holds
	-- five frames and 0001/0002 share one rect, so a pass is three different pictures over
	-- 0.21 s. The TV is re-played from onBeatHit below (the original calls playAnim('abot','i')
	-- there); with loop = true the animation never ended, so the sprite ran past the beat and
	-- the TV flickered on its own -- that is what read as "the ABot is broken".
	addAnimationByPrefix('abot', 'i', 'Abot System', 24, false)
	setProperty('abot.alpha', 1);

	addLuaSprite('abotEyeBack', false);
	addLuaSprite('abotEyes', false);
	addLuaSprite('abotBG', false);
	addLuaSprite('abotViz1', false);
	addLuaSprite('abotViz2', false);
	addLuaSprite('abotViz3', false);
	addLuaSprite('abotViz4', false);
	addLuaSprite('abotViz5', false);
	addLuaSprite('abotViz6', false);
	addLuaSprite('abotViz7', false);
	addLuaSprite('abot', false);

end

-- Limul Engine: the equalizer frames used to be re-played every single frame from
-- onUpdate (7 playAnim calls x 60fps). The values only change on a quaver step, so
-- they are applied in onStepHit now, after the random walk, and each level is
-- clamped to 1..6 -- the KA-DE walk could reach viz0 / viz-1 / viz7, and those
-- animations are not in aBotViz.xml, so a bar silently stuck on its last frame.
--
-- Limul Engine: Nene\'s knife, ported from the Erect original\'s transitionAnim() state
-- machine (_konwersje/erect_mode_unpacked/Erect Mode/characters/nene.lua:102-149).
-- Why the previous version read as a teleport, and what changes here:
--   * The raise used to fire on the frame health crossed 0.5, which is in the middle of
--     a bop, and it held the knife with the KA-DE \'-alt\' idle suffix. That suffix
--     switches the animation offset from [0,52] to [-99,52] in one frame. Erect waits
--     for danceLeft to finish before raising and holds the looping \'idleKnife\'
--     instead, blinking it on a random beat; both are done here.
--   * PlayState.beatHit() calls gf.dance() every Math.round(gfSpeed *
--     gf.danceEveryNumBeats) BEATS (2 at 182 BPM -> 0.66 s), not every step, and
--     danceLeft/danceRight are 15 frames at 24 fps (0.625 s), so a bop does get to
--     finish -- the wait is not a deadlock, and a 4-beat timeout still covers songs that
--     set a faster gf speed.
--   * Character.playAnim() clears specialAnim and Character.update() releases it by
--     itself when the animation is over (specialAnim && curAnim.finished -> dance()), so
--     every knifeStart() here re-arms the lock and the script needs no timer of its own.
--     transitionAnim() runs from onUpdatePost because PlayState.hx:3448 calls it after
--     super.update(): the dance the engine started on the release frame is replaced
--     before anything is drawn.
--   * Lua\'s curBeat is set to 0 once in FunkinLua.init and never updated in 0.6.3, so
--     the blink delay is counted in onBeatHit.
-- The 0.50 / 0.56 band stays: it is wider than one note (~0.03 of health), so hovering
-- on the threshold cannot restart the animation over and over.
local animTrans = 0 -- 0 bopping | 1 waiting for a clean hand-off | 2 knife up | 3 lowering
local beatCount = 0
local blinkDelay = 3
local lastBlink = 0
local waitBeat = 0

function knifeStart(anim, startFrame)
	playAnim('gf', anim, false, false, startFrame or 0)
	setProperty('gf.specialAnim', true)
end

function transitionAnim()
	if animTrans == 0 then -- bopping: decide whether the knife comes up
		if getProperty('health') <= 0.5 then
			animTrans = 1
			waitBeat = beatCount
		end
	elseif animTrans == 1 then -- wait for the bop to end, then raise from the neutral pose
		if getProperty('gf.specialAnim') then
			return
		end
		if (getProperty('gf.animation.name') == 'danceLeft' and getProperty('gf.animation.finished'))
			or beatCount - waitBeat >= 4 then
			animTrans = 2
			knifeStart('raiseKnife')
		end
	elseif animTrans == 2 then -- knife held: lower it, or keep the loop locked
		if getProperty('health') >= 0.56 then
			animTrans = 3
			knifeStart('lowerKnife')
		elseif not getProperty('gf.specialAnim') then -- the engine released the lock: re-arm it
			if beatCount - lastBlink >= blinkDelay then
				lastBlink = beatCount
				blinkDelay = getRandomInt(3, 7)
				knifeStart('idleKnife')
			else
				local lastFrame = getProperty('gf.animation.numFrames')
				if lastFrame == nil then
					lastFrame = 0
				end
				knifeStart('idleKnife', lastFrame)
			end
		end
	elseif not getProperty('gf.specialAnim') then -- lowerKnife is over, the engine danced already
		animTrans = 0
	end
end

function onUpdate(elapsed)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
end

function onUpdatePost(elapsed)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if songName == "Blazin'" then
		return
	end
	transitionAnim()
end

function onBeatHit()
	beatCount = beatCount + 1
	-- Limul Engine: the KA-DE original replays the TV body on every beat; one pass is 5
	-- frames at 24 fps (0.21 s), so at 182 BPM (0.33 s/beat) it lands and rests until the
	-- next beat. That is the ABot's flicker.
	playAnim('abot', 'i');
end

function onStepHit()
	abotBeatRandom1 = getRandomInt(1,5);
	abotBeatRandom2 = getRandomInt(1,5);
	abotBeatRandom3 = getRandomInt(1,5);
	abotBeatRandom4 = getRandomInt(1,5);
	abotBeatRandom5 = getRandomInt(1,5);
	abotBeatRandom6 = getRandomInt(1,5);
	abotBeatRandom7 = getRandomInt(1,5);
	-- Limul Engine: up on a low roll, down otherwise, but never below 1 or
	-- above 6. The original decremented on abotBeatRandomN == 5 whatever the
	-- current level was, which walked the bars into viz0 / viz-1.
	if abotBeatRandom1 <= 2 and viz1Value < 6 then
		viz1Value = viz1Value + getRandomInt(1,2)
	elseif viz1Value > 1 then
		viz1Value = viz1Value - getRandomInt(1,2)
	end
	if abotBeatRandom2 <= 2 and viz2Value < 6 then
		viz2Value = viz2Value + getRandomInt(1,2)
	elseif viz2Value > 1 then
		viz2Value = viz2Value - getRandomInt(1,2)
	end
	if abotBeatRandom3 <= 2 and viz3Value < 6 then
		viz3Value = viz3Value + getRandomInt(1,2)
	elseif viz3Value > 1 then
		viz3Value = viz3Value - getRandomInt(1,2)
	end
	if abotBeatRandom4 <= 2 and viz4Value < 6 then
		viz4Value = viz4Value + getRandomInt(1,2)
	elseif viz4Value > 1 then
		viz4Value = viz4Value - getRandomInt(1,2)
	end
	if abotBeatRandom5 <= 2 and viz5Value < 6 then
		viz5Value = viz5Value + getRandomInt(1,2)
	elseif viz5Value > 1 then
		viz5Value = viz5Value - getRandomInt(1,2)
	end
	if abotBeatRandom6 <= 2 and viz6Value < 6 then
		viz6Value = viz6Value + getRandomInt(1,2)
	elseif viz6Value > 1 then
		viz6Value = viz6Value - getRandomInt(1,2)
	end
	if abotBeatRandom7 <= 2 and viz7Value < 6 then
		viz7Value = viz7Value + getRandomInt(1,2)
	elseif viz7Value > 1 then
		viz7Value = viz7Value - getRandomInt(1,2)
	end
	-- Apply the new bar heights once per step instead of once per frame.
	playAnim('abotViz1', 'viz'..viz1Value);
	playAnim('abotViz2', 'viz'..viz2Value);
	playAnim('abotViz3', 'viz'..viz3Value);
	playAnim('abotViz4', 'viz'..viz4Value);
	playAnim('abotViz5', 'viz'..viz5Value);
	playAnim('abotViz6', 'viz'..viz6Value);
	playAnim('abotViz7', 'viz'..viz7Value);
end

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == 'abotEyesLeft1' and abotEyes == 1 then
		abotEyes = 0
		playAnim('abotEyes', 'l');
		doTweenX("abotEyesX", 'abotEyes', getProperty('gf.x') -96, 0.1, 'cubeOut')
		doTweenY("abotEyesY", 'abotEyes', getProperty('gf.y') +552, 0.1, 'cubeOut')
	end
	if tag == 'abotEyesRight1' and abotEyes == 0 then
		abotEyes = 1
		playAnim('abotEyes', 'r');
		doTweenX("abotEyesX", 'abotEyes', getProperty('gf.x') -76, 0.1, 'cubeOut')
		doTweenY("abotEyesY", 'abotEyes', getProperty('gf.y') +549, 0.1, 'cubeOut')
	end
end

function onMoveCamera(focus)
	if focus == 'dad' then
		runTimer('abotEyesLeft1', 0.2);
	elseif focus == 'boyfriend' or focus == 'gf' then
		runTimer('abotEyesRight1', 0.2);
	end
end

function onEvent(name, value1, value2)
    if name == 'Focus Camera' then
        if value1 == '1' then
			runTimer('abotEyesLeft1', 0.2);
        elseif value1 == '2' or value1 == '3' then
			runTimer('abotEyesRight1', 0.2);
        end
    end
end
