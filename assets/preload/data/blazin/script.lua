function onCreate()
	setPropertyFromClass('GameOverSubstate', 'characterName', 'pico-blazin-dead')
	setPropertyFromClass('GameOverSubstate', 'deathSoundName', 'gameplay/gameover/fnf_loss_sfx-pico-gutpunch')
	setPropertyFromClass('GameOverSubstate', 'loopSoundName', 'gameplay/gameover/gameOver-pico')
	setPropertyFromClass('GameOverSubstate', 'endSoundName', 'gameplay/gameover/gameOverEnd-pico')
	setPropertyFromClass('PauseSubState', 'songName', 'breakfast-pico/breakfast-pico')

	for i = 0,3 do
		setPropertyFromGroup('strumLineNotes',i,'x', -830)
	end

	triggerEvent('Camera Follow Pos', 320, 300)
end

-- LIMUL-BLAZIN-HIDE-OPP: the opponent receptors are parked off-screen above, but their
-- arrows still spawned and drew over the fight. Hide those notes for good.
function onCreatePost()
	runHaxeCode([[
		var i:Int = 0;
		while (i < game.unspawnNotes.length) {
			var n = game.unspawnNotes[i];
			if (n.mustPress == false) n.visible = false;
			i++;
		}
	]])
end

-- Limul Engine: the KA-DE original re-created eight 0.01s noteTweenX tweens on
-- every single frame and passed a bare `cubeInOut` (an undefined global, so nil)
-- as the ease -- eight tween allocations plus eight "Unknown ease type" traces
-- per frame. A 0.01s tween is an instant snap anyway, so the receptor positions
-- are written directly now; same result, no garbage.
function onUpdate()
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	for i = 0,3 do
		setPropertyFromGroup('strumLineNotes', i, 'x', -150)
	end

	for i = 4,7 do
		setPropertyFromGroup('strumLineNotes', i, 'x', 412 + (i - 4) * 112)
	end
end
