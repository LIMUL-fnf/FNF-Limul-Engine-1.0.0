--
-- 'Set Camera Target' - Limul Engine build (Psych Engine 0.6.3 API).
--
-- The Erect / V-Slice charts ship the Psych 1.0.4 version of this event. That version drives
-- the camera with runHaxeFunction('enableFollowPoint'), startTween() and getVar()/setVar(),
-- and none of those callbacks exist here, so the event died on its first line *after* already
-- setting isCameraOnForcedPos - which is why the camera stayed frozen for the rest of the song.
--
-- How the camera actually works in 0.6.3 (all verified in source/PlayState.hx):
--   camFollow             where the camera wants to be
--   camFollowPos          the object FlxG.camera follows; update() glides it toward camFollow
--                         using elapsed * 2.4 * cameraSpeed * playbackRate
--   isCameraOnForcedPos   the engine's own "stop moving the camera on section changes" flag
--   cameraSetTarget()     the Lua helper that runs the engine's own framing formulas
--
-- Chart-facing behaviour is unchanged from 1.0.4 (see Set Camera Target.txt):
--   Value1: Character,X,Y  -> BF / Dad / GF (or 0 / 1 / 2, or nothing), plus optional offsets
--   Value2: Duration,Ease  -> duration in steps, 0 = snap instantly, blank = normal glide
--   Blank Value1 hands the camera back to the engine so sections move it again.
--

local tweening = false

function trimList(value)
	local out = {}
	if value == nil then return out end
	local parts = stringSplit(tostring(value), ',')
	for i = 1, #parts do
		out[i] = stringTrim(parts[i])
	end
	return out
end

function num(value, fallback)
	local n = tonumber(value)
	if n == nil then return fallback end
	return n
end

-- haxe Arrays reach Lua as tables (1-based); used instead of the 'prop[0]' string form,
-- which 0.6.3's getProperty cannot resolve on an Array.
function elementAt(value, one, zero)
	if type(value) ~= 'table' then return 0 end
	return num(value[one], num(value[zero], 0))
end

function boyfriendPos()
	cameraSetTarget('boyfriend')
	return num(getProperty('camFollow.x'), 0), num(getProperty('camFollow.y'), 0)
end

function girlfriendPos()
	-- cameraSetTarget() only knows 'dad' versus everything-else in 0.6.3, so the girlfriend
	-- framing from PlayState.moveCameraSection() is rebuilt here (midpoint + both offsets).
	local gx = num(getMidpointX('gf'), 0)
	local gy = num(getMidpointY('gf'), 0)
	if gx == 0 and gy == 0 then
		-- No girlfriend on this stage: aim at boyfriend instead of at the corner of the world.
		return boyfriendPos()
	end
	local camOffset = elementAt(getProperty('gf.cameraPosition'), 1, 0)
		+ elementAt(getProperty('girlfriendCameraOffset'), 1, 0)
	local camOffsetY = elementAt(getProperty('gf.cameraPosition'), 2, 1)
		+ elementAt(getProperty('girlfriendCameraOffset'), 2, 1)
	return gx + camOffset, gy + camOffsetY
end

function onEvent(eventName, value1, value2)
	if eventName ~= 'Set Camera Target' then return end

	-- Blank Value1: unlock, i.e. let moveCameraSection() own the camera again.
	if value1 == nil or stringTrim(tostring(value1)) == '' then
		cancelTween('limulCamX')
		cancelTween('limulCamY')
		tweening = false
		setProperty('isCameraOnForcedPos', false)
		local x, y
		if gfSection == true then
			x, y = girlfriendPos()
			setProperty('camFollow.x', x)
			setProperty('camFollow.y', y)
		else
			-- The engine's own formulas do the work, including cameraPosition/offset.
			cameraSetTarget(mustHitSection == true and 'boyfriend' or 'dad')
		end
		return
	end

	local targetData = trimList(value1)
	local who = string.lower(targetData[1] or '')
	local offsetX = num(targetData[2], 0)
	local offsetY = num(targetData[3], 0)
	local targetX, targetY = 0, 0

	if who == '' or who == '0' or who == 'bf' or who == 'boyfriend' then
		targetX, targetY = boyfriendPos()
	elseif who == '1' or who == 'dad' or who == 'opponent' then
		cameraSetTarget('dad')
		targetX = num(getProperty('camFollow.x'), 0)
		targetY = num(getProperty('camFollow.y'), 0)
	elseif who == '2' or who == 'gf' or who == 'girlfriend' then
		targetX, targetY = girlfriendPos()
	else
		-- Unknown character name: same as 1.0.4, the offsets become an absolute position.
		targetX, targetY = 0, 0
	end
	targetX = targetX + offsetX
	targetY = targetY + offsetY

	-- Keep moveCameraSection() away while this event drives the camera.
	setProperty('isCameraOnForcedPos', true)
	cancelTween('limulCamX')
	cancelTween('limulCamY')
	tweening = false

	local tweenData = trimList(value2)
	local steps = num(tweenData[1], -1)

	if steps == 0 then
		-- Snap: move both the wanted position and the object the camera actually follows.
		setProperty('camFollow.x', targetX)
		setProperty('camFollow.y', targetY)
		setProperty('camFollowPos.x', targetX)
		setProperty('camFollowPos.y', targetY)
	elseif steps < 0 then
		-- No duration asked for: the engine glides camFollowPos there at cameraSpeed.
		setProperty('camFollow.x', targetX)
		setProperty('camFollow.y', targetY)
	else
		local duration = num(stepCrochet, 200) * steps / 1000
		local ease = tweenData[2]
		if ease == nil or ease == '' then ease = 'linear' end
		tweening = true
		doTweenX('limulCamX', 'camFollow', targetX, duration, ease)
		doTweenY('limulCamY', 'camFollow', targetY, duration, ease)
	end
end

function onTweenCompleted(tag)
	if tag == 'limulCamX' or tag == 'limulCamY' then
		tweening = false
	end
end

function onUpdate(elapsed)
	-- The tween writes camFollow; without this the followed object would keep lagging behind
	-- it and the camera would never quite land on the charted position.
	if tweening then
		setProperty('camFollowPos.x', getProperty('camFollow.x'))
		setProperty('camFollowPos.y', getProperty('camFollow.y'))
	end
end
