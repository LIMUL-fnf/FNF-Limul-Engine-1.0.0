-- Limul Engine / Psych 0.6.3 port - stage "Dbackground"
--
-- KA-DE original (kept in _backup-dropfix/stages/Dbackground.lua) only drew eight
-- parallax layers, and two of them were wrong there:
--   * phillyTraffic was created with makeLuaSprite, i.e. as a PLAIN graphic, while
--     phillyTraffic.png is a 3060x1808 Spritesheet (77 frames: redtogreen/greentored)
--     -> the whole atlas was painted as one giant picture instead of a traffic light;
--   * the highway light bar, both add-blend lightmaps and the two cars were missing
--     completely, so the street had no lights and no traffic at all.
--
-- HOW THE STREET LAYERS WERE RECOVERED
-- Dbackground is the same street as KA-DE's "phillyStreets" / Erect's "streetsErect",
-- just re-anchored. The one layer both stages agree on is the street itself:
--     phillyStreets / streetsErect -> phillyForeground at (  88, 317)
--     Dbackground                  -> phillyForeground at (-1100,-100)
-- so every street-space authoring number converts with the delta (-1188, -417).
-- Independent check of that delta: Erect's sprayCans (920,1045) + delta = (-268,628),
-- and Dbackground.lua already had SpraycanPile at (-270,630). Two objects, same answer.
--
-- Why the earlier attempts on this thread all looked broken:
--   * attempt 1 parked the cars at the raw phillyStreets numbers (1800,480) without the
--     delta, so they landed on top of the traffic light;
--   * attempts 2 and 3 gave up on the street and anchored the cars to phillyHighway.
--     That was wrong: phillyHighway is only the elevated flyover - a guard rail, a
--     barrier wall and pillars, with no painted road anywhere in it. Tracing its top
--     edge put the traffic in the upper third of the frame, i.e. right in the strumline
--     zone, which is exactly the "auta lataja / tak gdzie strzalki tam auta" report, and
--     shrinking the light to 0.55 of a 448px frame pushed its base off screen, which is
--     the "nie ma swiatel" report.
--
-- What the street art actually is (measured off phillyForeground.png, which sits at
-- (-1100,-100), so world = local + that offset): a brick retaining wall with a chain
-- fence on top runs across the left of the frame (local x 20..1745, y 216..660) and
-- ENDS at local x 1745. Right of the end of the wall the pavement drops to a kerb at
-- local y 665..750 and the road curves away to the right. That corner is where the
-- traffic light stands: its 336x448 frame at street (1840,608) puts the lamp head over
-- the road and the pole base at world y 639, on the kerb, 7px from the measured end of
-- the wall. The cars are authored at scale 1 (449..481 x 186..258 bodies), which is the
-- size the wall implies, and they are added BEFORE phillyForeground on purpose: the wall
-- hides a car as it enters, the near kerb hides its wheels, and it only stands fully
-- visible once it clears the end of the wall. That is Erect's own z-order.
--
-- The drive itself is Erect's quadratic path sampled into equal-time legs, because
-- 0.6.3's doTweenQuadMotion needs a Haxe helper that this port does not register.
--
-- Every layer is behind checkFileExists: in 0.6.3 Paths.image() throws on a missing
-- file and Lua lets the exception cut the whole function, which is how this stage
-- ended up with an empty map before.

local LIGHTS_X = -905
local LIGHTS_Y = -154

-- the row of eight street lamps along the far kerb. Off: with the traffic light in
-- the scene it read as "too many lights", and half of the row sits above the frame
-- at this stage's camera. Flip to true to bring the glow back.
local SHOW_STREET_LAMPS = false

-- street space (phillyStreets / streetsErect) -> Dbackground space
local STREET_DX = -1188
local STREET_DY = -417

function toStreet(x, y)
	return x + STREET_DX, y + STREET_DY
end

-- traffic light. Every phillyTraffic frame is 336x448 and untrimmed and Erect authored
-- the pair at scale 1, so the sprite position IS the top-left of the visible assembly
-- (lamp head at the top, pole down to the kerb). The lightmap is the same rect.
-- SIGNAL_SHIFT_X moves the whole assembly along the kerb: the pole sat too far right of
-- the corner where the retaining wall ends, so it read as floating in the road.
local SIGNAL_SHIFT_X = -150
local SIGNAL_X, SIGNAL_Y = toStreet(1840 + SIGNAL_SHIFT_X, 608)
local SIGNAL_SCALE = 1

-- Erect's offsetCars: its path points are road points, and the sprite is parked
-- offsetCars above/left of them.
local OC_X, OC_Y = 306.6, 168.3
-- Erect's per-variant addOffset, so all four bodies put their wheels on the same line
local CAR_OFFSET_X = {0, 20, 30, 10}
local CAR_OFFSET_Y = {0, -15, 50, 60}
-- Erect's two control polygons, in street space, already minus offsetCars
local PATH_L2R = {
	{1570 - OC_X, 1049 - OC_Y - 30},
	{2400 - OC_X,  980 - OC_Y - 50},
	{3102 - OC_X, 1127 - OC_Y + 40}
}
local PATH_R2L = {
	{3102 - OC_X, 1127 - OC_Y + 60},
	{2400 - OC_X,  980 - OC_Y - 30},
	{1570 - OC_X, 1049 - OC_Y - 10}
}
local CAR_LEGS = 6
local CAR_TAG1 = 'phillyCars1'
local CAR_TAG2 = 'phillyCars2'
local CAR_SCALE = 1

-- one record per car: lane, its sampled path and the drive picked for the current run
local car1 = {path = nil, leg = 1, variant = 1, duration = 3, angleFrom = -8, angleTo = 18}
local car2 = {path = nil, leg = 1, variant = 1, duration = 3, angleFrom = 18, angleTo = -8}

-- Quadratic Bezier through the three street-space control points, sampled at equal t.
-- FlxTween.quadMotion walks the same curve with the same non-uniform speed, so stepping
-- it in equal times reproduces Erect's motion without a Haxe helper.
function samplePath(ctrl)
	local out = {}
	for i = 0, CAR_LEGS do
		local t = i / CAR_LEGS
		local a = (1 - t) * (1 - t)
		local b = 2 * (1 - t) * t
		local c = t * t
		local p = {}
		p.x, p.y = toStreet(
			ctrl[1][1] * a + ctrl[2][1] * b + ctrl[3][1] * c,
			ctrl[1][2] * a + ctrl[2][2] * b + ctrl[3][2] * c)
		out[#out + 1] = p
	end
	return out
end

-- Sprite position is the path point itself: Erect's per-variant addOffset shifts the
-- drawn frame, so the wheels of all four bodies still land on the same line.

function onCreate()
	-- Street ambience: OFF. The KA-DE original played a 'traffic.ogg' that does not
	-- exist in this port; carAmbience.ogg (a 60 s broadband hiss) was substituted for
	-- it, but it sits on top of the whole song and was reported as "still hissing"
	-- twice, so the street is silent like the original files made it.

	if checkFileExists('images/phillyStreets/phillySkybox.png') then
		makeLuaSprite('phillySkybox', 'phillyStreets/phillySkybox', -700, -200)
		addLuaSprite('phillySkybox', false)
		setScrollFactor('phillySkybox', 0.3, 0.3)
	end

	if checkFileExists('images/phillyStreets/phillySkyline.png') then
		makeLuaSprite('phillySkyline', 'phillyStreets/phillySkyline', -700, -300)
		addLuaSprite('phillySkyline', false)
		setScrollFactor('phillySkyline', 0.3, 0.3)
	end

	if checkFileExists('images/phillyStreets/phillyForegroundCity.png') then
		makeLuaSprite('phillyForegroundCity', 'phillyStreets/phillyForegroundCity', 350, -20)
		addLuaSprite('phillyForegroundCity', false)
		setScrollFactor('phillyForegroundCity', 0.4, 0.4)
	end

	if checkFileExists('images/phillyStreets/phillyConstruction.png') then
		makeLuaSprite('phillyConstruction', 'phillyStreets/phillyConstruction', 1000, -150)
		addLuaSprite('phillyConstruction', false)
		setScrollFactor('phillyConstruction', 0.6, 0.6)
	end

	-- the neon strip that runs along the elevated highway, plus its add-blend glow
	if SHOW_STREET_LAMPS and checkFileExists('images/phillyStreets/phillyHighwayLights.png') then
		makeLuaSprite('phillyHighwayLights', 'phillyStreets/phillyHighwayLights', LIGHTS_X, LIGHTS_Y)
		addLuaSprite('phillyHighwayLights', false)
		setScrollFactor('phillyHighwayLights', 1, 1)
	end

	if SHOW_STREET_LAMPS and checkFileExists('images/phillyStreets/phillyHighwayLights_lightmap.png') then
		makeLuaSprite('phillyHighwayLights_lightmap', 'phillyStreets/phillyHighwayLights_lightmap', LIGHTS_X, LIGHTS_Y)
		addLuaSprite('phillyHighwayLights_lightmap', false)
		setScrollFactor('phillyHighwayLights_lightmap', 1, 1)
		setBlendMode('phillyHighwayLights_lightmap', 'add')
	end

	if checkFileExists('images/phillyStreets/phillyHighway.png') then
		makeLuaSprite('phillyHighway', 'phillyStreets/phillyHighway', -1050, -250)
		addLuaSprite('phillyHighway', false)
		setScrollFactor('phillyHighway', 1, 1)
	end

	if checkFileExists('images/phillyStreets/phillySmog.png') then
		makeLuaSprite('phillySmog', 'phillyStreets/phillySmog', -1000, -200)
		addLuaSprite('phillySmog', false)
		setScrollFactor('phillySmog', 0.8, 0.8)
	end

	-- Everything below is street-space furniture: it must move with the street, so all
	-- of it is scrollFactor 1,1. Erect used 0.9 on x, which slides the pole a few dozen
	-- pixels off the kerb corner every time the camera pans.

	-- the traffic light: an ANIMATED sprite (redtogreen / greentored), not a plain one.
	-- Added before phillyForeground so the near corner of the wall can overlap its base.
	car1.path = samplePath(PATH_L2R)
	car2.path = samplePath(PATH_R2L)

	if checkFileExists('images/phillyStreets/phillyTraffic.png') then
		makeAnimatedLuaSprite('phillyTraffic', 'phillyStreets/phillyTraffic', SIGNAL_X, SIGNAL_Y)
		addAnimationByPrefix('phillyTraffic', 'tored', 'greentored', 24, false)
		addAnimationByPrefix('phillyTraffic', 'togreen', 'redtogreen', 24, false)
		setProperty('phillyTraffic.flipX', false)
		scaleObject('phillyTraffic', SIGNAL_SCALE, SIGNAL_SCALE)
		addLuaSprite('phillyTraffic', false)
		setScrollFactor('phillyTraffic', 1, 1)
		playAnim('phillyTraffic', 'togreen', false)
		runTimer('limulGreentoredTimer', 11)
	end

	if checkFileExists('images/phillyStreets/phillyTraffic_lightmap.png') then
		makeLuaSprite('phillyTraffic_lightmap', 'phillyStreets/phillyTraffic_lightmap', SIGNAL_X, SIGNAL_Y)
		scaleObject('phillyTraffic_lightmap', SIGNAL_SCALE, SIGNAL_SCALE)
		addLuaSprite('phillyTraffic_lightmap', false)
		setScrollFactor('phillyTraffic_lightmap', 1, 1)
		setBlendMode('phillyTraffic_lightmap', 'add')
		setProperty('phillyTraffic_lightmap.alpha', 0.6)
	end

	-- two cars, one per direction: they enter behind the retaining wall, cross the
	-- street in front of the light and leave at the right edge of the frame
	if checkFileExists('images/phillyStreets/erect/phillyCars.png') then
		makeAnimatedLuaSprite(CAR_TAG1, 'phillyStreets/erect/phillyCars', car1.path[1].x, car1.path[1].y)
		addAnimationByPrefix(CAR_TAG1, 'car1', 'car1', 24, false)
		addAnimationByPrefix(CAR_TAG1, 'car2', 'car2', 24, false)
		addAnimationByPrefix(CAR_TAG1, 'car3', 'car3', 24, false)
		addAnimationByPrefix(CAR_TAG1, 'car4', 'car4', 24, false)
		addOffset(CAR_TAG1, 'car1', CAR_OFFSET_X[1], CAR_OFFSET_Y[1])
		addOffset(CAR_TAG1, 'car2', CAR_OFFSET_X[2], CAR_OFFSET_Y[2])
		addOffset(CAR_TAG1, 'car3', CAR_OFFSET_X[3], CAR_OFFSET_Y[3])
		addOffset(CAR_TAG1, 'car4', CAR_OFFSET_X[4], CAR_OFFSET_Y[4])
		setProperty(CAR_TAG1 .. '.flipX', false)
		scaleObject(CAR_TAG1, CAR_SCALE, CAR_SCALE)
		addLuaSprite(CAR_TAG1, false)
		setScrollFactor(CAR_TAG1, 1, 1)

		makeAnimatedLuaSprite(CAR_TAG2, 'phillyStreets/erect/phillyCars', car2.path[1].x, car2.path[1].y)
		addAnimationByPrefix(CAR_TAG2, 'car1', 'car1', 24, false)
		addAnimationByPrefix(CAR_TAG2, 'car2', 'car2', 24, false)
		addAnimationByPrefix(CAR_TAG2, 'car3', 'car3', 24, false)
		addAnimationByPrefix(CAR_TAG2, 'car4', 'car4', 24, false)
		addOffset(CAR_TAG2, 'car1', CAR_OFFSET_X[1], CAR_OFFSET_Y[1])
		addOffset(CAR_TAG2, 'car2', CAR_OFFSET_X[2], CAR_OFFSET_Y[2])
		addOffset(CAR_TAG2, 'car3', CAR_OFFSET_X[3], CAR_OFFSET_Y[3])
		addOffset(CAR_TAG2, 'car4', CAR_OFFSET_X[4], CAR_OFFSET_Y[4])
		setProperty(CAR_TAG2 .. '.flipX', true)
		scaleObject(CAR_TAG2, CAR_SCALE, CAR_SCALE)
		addLuaSprite(CAR_TAG2, false)
		setScrollFactor(CAR_TAG2, 1, 1)

		sendCar(CAR_TAG1, car1, 2.5)
		sendCar(CAR_TAG2, car2, 7.5)
	end

	-- the street, added last on purpose: it is what hides the wheels and the entering cars
	if checkFileExists('images/phillyStreets/phillyForeground.png') then
		makeLuaSprite('phillyForeground', 'phillyStreets/phillyForeground', -1100, -100)
		addLuaSprite('phillyForeground', false)
		setScrollFactor('phillyForeground', 1, 1)
	end

	if checkFileExists('images/SpraycanPile.png') then
		makeLuaSprite('SpraycanPile', 'SpraycanPile', -270, 630)
		addLuaSprite('SpraycanPile', true)
		setScrollFactor('SpraycanPile', 1, 1)
	end
end

-- Pick a body, park the car at the start of its path and send it off. `delay` only
-- staggers the very first two launches; every later run is queued by the tween.
function sendCar(tag, car, delay)
	if not luaSpriteExists(tag) then
		return
	end

	car.variant = getRandomInt(1, 4)
	-- Erect's own per-variant spread (normal 1..1.7, sport 0.6..1.2, van/suv 1.5..2.5 s
	-- for the whole crossing) stretched x2.6. The stretch is needed because this stage
	-- frames the street far tighter than streetsErect does, so the same world-space speed
	-- sweeps across much more of the visible screen per second.
	-- Lua 5.1 grammar: a table constructor is not a prefixexp, so `{...}[i]` is a
	-- syntax error (the engine reported `unexpected symbol near '['` and killed the
	-- whole stage script). Parenthesising the literal makes the index legal.
	local spread = ({[1] = {1.0, 1.7}, [2] = {0.6, 1.2}, [3] = {1.5, 2.5}, [4] = {1.5, 2.5}})[car.variant]
	car.duration = getRandomFloat(spread[1], spread[2]) * 2.6
	car.leg = 1

	playAnim(tag, 'car' .. car.variant, false)
	scaleObject(tag, CAR_SCALE, CAR_SCALE)
	setProperty(tag .. '.x', car.path[1].x)
	setProperty(tag .. '.y', car.path[1].y)
	setProperty(tag .. '.alpha', 0)
	doTweenAlpha(tag .. 'Fade', tag, 1, 0.6, 'linear')
	doTweenAngle(tag .. 'Tilt', tag, car.angleTo, car.duration, 'linear')

	if delay > 0 then
		runTimer(tag .. 'Launch', delay)
	else
		startLeg(tag, car)
	end
end

-- One tween per sampled pair, all of them equal time, which is what reproduces
-- FlxTween.quadMotion's speed profile.
function startLeg(tag, car)
	if not luaSpriteExists(tag) or car.leg >= #car.path then
		return
	end

	local from = car.path[car.leg]
	local to = car.path[car.leg + 1]
	local time = car.duration / CAR_LEGS

	doTweenX(tag .. 'DriveX', tag, to.x, time, 'linear')
	doTweenY(tag .. 'DriveY', tag, to.y, time, 'linear')

	-- last leg: dissolve before the frame edge so the car never pops out of existence
	if car.leg + 1 == #car.path then
		doTweenAlpha(tag .. 'FadeOut', tag, 0, time, 'linear')
	end
end

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == 'limulRedtogreenTimer' then
		if luaSpriteExists('phillyTraffic') then
			playAnim('phillyTraffic', 'togreen', false)
		end
		runTimer('limulGreentoredTimer', 11)
		return
	end

	if tag == 'limulGreentoredTimer' then
		if luaSpriteExists('phillyTraffic') then
			playAnim('phillyTraffic', 'tored', false)
		end
		runTimer('limulRedtogreenTimer', 8)
		return
	end

	if tag == CAR_TAG1 .. 'Launch' then
		startLeg(CAR_TAG1, car1)
		return
	end

	if tag == CAR_TAG2 .. 'Launch' then
		startLeg(CAR_TAG2, car2)
		return
	end

	if tag == 'limulCar1Again' then
		sendCar(CAR_TAG1, car1, 0)
		return
	end

	if tag == 'limulCar2Again' then
		sendCar(CAR_TAG2, car2, 0)
		return
	end
end

-- Only the X tween matters: the Y tween has the same duration and its own tag, so
-- it is ignored here to avoid advancing the car twice per leg.
function onTweenCompleted(tag)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == CAR_TAG1 .. 'DriveX' then
		car1.leg = car1.leg + 1
		if car1.leg >= #car1.path then
			runTimer('limulCar1Again', getRandomFloat(5, 12))
		else
			startLeg(CAR_TAG1, car1)
		end
		return
	end

	if tag == CAR_TAG2 .. 'DriveX' then
		car2.leg = car2.leg + 1
		if car2.leg >= #car2.path then
			runTimer('limulCar2Again', getRandomFloat(5, 12))
		else
			startLeg(CAR_TAG2, car2)
		end
		return
	end
end
