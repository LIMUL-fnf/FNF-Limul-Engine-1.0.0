function onCreate()
	setPropertyFromClass('GameOverSubstate', 'characterName', 'pico-dead')
	setPropertyFromClass('GameOverSubstate', 'deathSoundName', 'fnf_loss_sfx-pico')
	setPropertyFromClass('GameOverSubstate', 'loopSoundName', 'gameplay/gameover/gameOver-pico')
	setPropertyFromClass('GameOverSubstate', 'endSoundName', 'gameplay/gameover/gameOverEnd-pico')
	setPropertyFromClass('PauseSubState', 'songName', 'breakfast-pico/breakfast-pico')
end

-- Step zooms from the GameBanana 565312 Lit Up Erect script, kept for Erect/Nightmare only;
-- the Easy/Normal/Hard/Fucked mixes are other songs' timing and would zoom at wrong beats.
local ZOOMS = {
	[256] = 0.75, [320] = 0.85, [384] = 0.58, [479] = 0.75, [511] = 0.58,
	[607] = 0.75, [639] = 0.6, [895] = 0.58, [991] = 0.75, [1024] = 0.58,
	[1120] = 0.75, [1152] = 0.6
}

function onStepHit()
	if difficultyName ~= 'Erect' and difficultyName ~= 'Nightmare' then return end
	local zoom = ZOOMS[curStep]
	if zoom then setProperty('defaultCamZoom', zoom) end
end

-- 0.6.3 has no native 'Play Sound' event; the Erect chart ends with Play Sound nene_laugh.
function onEvent(name, value1, value2)
	if name == 'Play Sound' and value1 == 'nene_laugh' then
		playSound('nene_laugh', tonumber(value2) or 1)
	end
end
