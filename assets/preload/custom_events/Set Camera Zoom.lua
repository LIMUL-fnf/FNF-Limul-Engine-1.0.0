--
-- 'Set Camera Zoom' - Limul Engine build (Psych Engine 0.6.3 API).
--
-- The 1.0.4 version of this event takes the zoom away from the engine: its onCreate zeroes
-- camZoomingDecay / camZoomingMult and then re-writes camGame.zoom by hand every frame,
-- animating its own 'defaultCamZoom' variable through startTween() - which does not exist
-- here. Because that onCreate died half way through, the zoom got frozen instead of animated.
--
-- 0.6.3 already contains exactly that behaviour natively:
--   PlayState.update():  camGame.zoom = lerp(defaultCamZoom, camGame.zoom,
--                                             1 - elapsed * 3.125 * camZoomingDecay)
--                        camHUD.zoom  = lerp(1, camHUD.zoom, ...)
-- so this implementation just keeps defaultCamZoom as "the zoom the song sits at" and only
-- switches the pull-back off while a charted tween is running. The native bop and the native
-- 'Add Camera Zoom' event keep working untouched.
--
-- Chart-facing behaviour is unchanged from 1.0.4 (see Set Camera Zoom.txt):
--   Value1: Value,Mode    -> 'stage' multiplies by the stage's default zoom
--   Value2: Duration,Ease -> duration in steps, blank or 0 = instant
--

local stageZoom = 1
local baseDecay = 1
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

function onCreate()
	-- PlayState reads the stage's zoom long before custom event scripts get created, so
	-- defaultCamZoom is still the clean stage value at this point.
	stageZoom = num(getProperty('defaultCamZoom'), 1)
	baseDecay = num(getProperty('camZoomingDecay'), 1)
end

function onEvent(eventName, value1, value2)
	if eventName ~= 'Set Camera Zoom' then return end

	-- A cancelled tween never reports completion, so restore the pull-back before anything else.
	setProperty('camZoomingDecay', baseDecay)
	cancelTween('limulZoom')
	tweening = false

	local zoomData = trimList(value1)
	local value = num(zoomData[1], nil)
	if value == nil then return end

	local target = value
	if string.lower(zoomData[2] or '') == 'stage' then
		target = value * stageZoom
	end

	local tweenData = trimList(value2)
	local steps = num(tweenData[1], -1)

	-- Whatever happens, this is the zoom the song should now sit at.
	setProperty('defaultCamZoom', target)

	if steps <= 0 then
		-- Instant: put the camera on it directly. Because defaultCamZoom now equals it,
		-- the native pull-back holds the value instead of drifting.
		setProperty('camGame.zoom', target)
		return
	end

	local duration = num(stepCrochet, 200) * steps / 1000
	local ease = tweenData[2]
	if ease == nil or ease == '' then ease = 'linear' end

	-- decay 0 turns the per-frame pull-back into a no-op, which leaves the tween as the only
	-- thing writing the zoom. It is restored on completion / at the next event.
	setProperty('camZoomingDecay', 0)
	tweening = true
	doTweenZoom('limulZoom', 'camGame', target, duration, ease)
end

function onTweenCompleted(tag)
	if tag == 'limulZoom' then
		tweening = false
		setProperty('camZoomingDecay', baseDecay)
	end
end
