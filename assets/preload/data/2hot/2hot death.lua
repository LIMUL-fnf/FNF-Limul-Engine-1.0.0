-- Limul Engine notes for this file (kept next to the code it describes):
--
-- * Death is a GameOverSubstate. While it is up, PlayState holds persistentDraw = false, so
--   none of the stage renders. As of limul-gameover-stage.lua v3 (2026-11-02) that is the
--   stock state everywhere: the global script no longer flips persistentDraw back on, it adds
--   one screen-pinned black overlay into the substate instead. 2 Hot therefore gets its black
--   twice - the global overlay plus this file's 'bgd' - which is fine: same colour, and the
--   belt survives if a later script re-enables the world draw. In the original the whole death
--   is a BLACK cutscene, and that is exactly what shows now.
-- * addLuaSprite(tag, false) during a death inserts the sprite into GameOverSubstate at
--   members.indexOf(boyfriend). The corpse is added in GameOverSubstate.new(), which runs
--   before create() calls onGameOverStart, so that index is 0 and never -1. Draw order
--   becomes: bgd (black) -> explosion -> corpse -> camFollowPos. Substate members draw on
--   top of the PlayState members, which is exactly what hides the street.
-- * THE BLACK STAYS. The 2026-11-02 build faded 'bgd' away with FlxTween(startDelay 1.8),
--   and that fade is what removed the black screen: about two seconds in, the stage was
--   visible again. Dropped - the original never fades and the RETRY prompt is baked into the
--   corpse atlas, so nothing needs the stage back.
-- * Cover: a 512x512 graphic scaled x8 = 4096x4096 world units anchored at (-1500,-1500).
--   GameOverSubstate.new() zeroes the camera scroll and then lerps it onto the corpse, so
--   the visible window for the whole death sits well inside (0,0)-(1400,1000); the box
--   covers it at any zoom down to ~0.3 without allocating a 4000px bitmap.
-- * Lua timers DO tick during a death: runTimer builds a FlxTimer, and FlxTimer defaults to
--   FlxTimer.globalManager, a flixel plugin updated by FlxGame - not by PlayState.update,
--   which is frozen (persistentUpdate = false). The previous version of this file assumed
--   the opposite and routed the fade through runHaxeCode/FlxTween for no reason; the tail
--   "function onUpdate() end / if inGameOver then return end" lines were dead code too -
--   they defined an empty onUpdate and left a floating if at chunk level.
-- * The KA-DE original ordered the backdrop with getObjectOrder('gfGroup'). gfGroup is a
--   PlayState member, and during a death that lookup only logged "Object gfGroup doesn't
--   exist!" and returned -1. Dropped; addLuaSprite(tag, false) does the right thing alone.
-- * The original blast sat at (-1600, -850), roughly 2500px outside the zeroed death camera,
--   so it was never once visible. It is now centred on the corpse instead, and its -90 angle
--   was dropped: TordBotBlowingUp is a radial smoke ring, so rotation only moved the pivot.
-- * Sounds are played last on purpose. A missing sound file throws inside the Lua pcall and
--   cuts the rest of the function, so nobody wants a playSound() above the visuals.

function onGameOverStart()
	-- 'BlackFlash' does not exist in this mod, so the black is a generated graphic.
	makeLuaSprite('bgd', 'empty', -1500, -1500)
	makeGraphic('bgd', 512, 512, '000000')
	scaleObject('bgd', 8, 8)
	addLuaSprite('bgd', false)

	makeAnimatedLuaSprite('explosion', 'explosionfrom_edd', 0, 0);
	addAnimationByPrefix('explosion', 'boom', 'TordBotBlowingUp', 18, false);
	setProperty('explosion.alpha', 0);
	addLuaSprite('explosion', false);
	scaleObject('explosion', 2.5, 2.5);

	-- pico-dead draws its 1314x774 canvas with animation offset [472, 295], so the middle
	-- of Pico's body sits at corpse + [472 + 657, 295 + 387].
	local bodyX = getProperty('boyfriend.x') + 1129
	local bodyY = getProperty('boyfriend.y') + 682
	setProperty('explosion.x', bodyX - (getProperty('explosion.width') / 2))
	setProperty('explosion.y', bodyY - (getProperty('explosion.height') / 2))
	cameraShake('camGame', 0.02, 0.5);

	setProperty('explosion.alpha', 1);
	playAnim('explosion', 'boom', true);

	playSound("explode", 0.8)
	playSound('shot1', 1)
	runTimer('picoded', 1.5)
end

function onTimerCompleted(tag, loops, loopsleft)
	if tag == 'picoded' then
		playSound('cutscene/nene_laugh', 1)
	end
end
