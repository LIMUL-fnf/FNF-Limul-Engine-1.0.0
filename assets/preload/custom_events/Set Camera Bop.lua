--
-- 'Set Camera Bop' - Limul Engine build (Psych Engine 0.6.3 API).
--
-- 1.0.4's version re-implements the whole zoom behaviour in Lua (zeroing camZoomingDecay and
-- camZoomingMult in onCreate, then writing camGame.zoom every frame) and shares that state with
-- the other camera events through setOnLuas()/isRunning(), which this engine does not have.
--
-- In 0.6.3 the default bop is already native: PlayState.sectionHit() adds
--     camGame.zoom += 0.015 * camZoomingMult
--     camHUD.zoom  += 0.03  * camZoomingMult
-- once per section (every 4 beats), and update() decays it back toward defaultCamZoom.
-- That is exactly the documented '4,0' default, so:
--   rate 4 / offset 0  -> just scale the native bop with camZoomingMult (intensity)
--   anything else      -> silence the native bop and bounce the zoom from onBeatHit() instead
--

local rate = 4
local rateOffset = 0
local intensity = 1
local customBop = false

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

function onEvent(eventName, value1, value2)
	if eventName ~= 'Set Camera Bop' then return end

	local rateData = trimList(value1)
	rate = num(rateData[1], 4)
	rateOffset = num(rateData[2], 0)
	intensity = num(value2, 1)

	if rate == 4 and rateOffset == 0 then
		customBop = false
		setProperty('camZoomingMult', intensity)
	else
		-- Non-default rhythm: take the bop away from the engine's section handler.
		customBop = true
		setProperty('camZoomingMult', 0)
	end
end

function onBeatHit()
	if not customBop then return end
	if rate <= 0 then return end
	if cameraZoomOnBeat ~= true then return end

	local gameZoom = num(getProperty('camGame.zoom'), 1)
	if ((curBeat + rateOffset) % rate) ~= 0 then return end
	if gameZoom >= 1.35 then return end

	-- Same bumps as the native section bop, just on the charted rhythm; update() decays them.
	setProperty('camGame.zoom', gameZoom + 0.015 * intensity)
	setProperty('camHUD.zoom', num(getProperty('camHUD.zoom'), 1) + 0.03 * intensity)
end
