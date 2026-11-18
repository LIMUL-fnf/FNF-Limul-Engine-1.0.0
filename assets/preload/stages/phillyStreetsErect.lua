-- Limul Engine: erected version of the Philadelphia streets (Weekend 1 Erect / Nightmare).
-- Same layer script as phillyStreets.lua, only the recoloured P-Slice 'erect' art plus the
-- overcast gradient and three drifting fog sheets. phillySmog and the highway lightmap stay
-- on the base path because P-Slice does not ship erected variants of them.
function onCreatePost()
if not lowQuality then
	-- Limul Engine: 'shaders/street' to nakładka koloru generowana runtime shaderem,
	-- którego ta wersja silnika nie kompiluje (flixel-addons 2.11 nie ma FlxRuntimeShader).
	-- Kiedyś makeLuaSprite wywalił błąd i uciął całą funkcję; teraz warstwa jest po prostu
	-- pomijana, a po dodaniu wsparcia dla shaderów wróci sama (wystarczy wrzucić plik).
	if checkFileExists('images/shaders/street.png') then
		makeLuaSprite("overlay", "shaders/street", -1000, -1050)
		setProperty("overlay.alpha", 0.5)
		scaleObject('overlay', 1.5, 1.5);
		setBlendMode('overlay', 'normal')
		addLuaSprite("overlay", true)
	end
	end
end


function onCreate()
	-- Limul Engine: 'traffic.ogg' nie istnieje w tym buildzie (nie przyszedl z KA-DE),
	-- a Psych czyta dzwieki TYLKO z mods/<mod>/sounds/. Paths.returnSound na brakujacym
	-- pliku rzuca IOError (openfl Sound.fromFile), a wyjatek Lua ucina CALA funkcje --
	-- to bylo pierwsze zdanie onCreate(), wiec nie tworzyl sie ZADEN sprite mapy
	-- (stad calkowicie czarna mapa na 2Hot / Darnell). Teraz zamiennik, ktory jest w
	-- modzie (carAmbience.ogg), dodatkowo osloniony checkFileExists, zeby brak pliku
	-- nigdy wiecej nie mogl zabic stage'u.
	-- carAmbience.ogg is a 60 s broadband hiss; it played for the whole song
	-- and was reported as "still hissing". The street is silent now.
	-- Limul Engine: erected street layers (P-Slice 'phillyStreets/erect' art).
	-- greyGradient is the overcast backdrop, the three mist sheets are parallax fog.
	-- Positions and scroll factors are authored for this build: the art is 2048x1280,
	-- the camera sits at zoom 0.7 around x 300-1900, so each sheet is placed to cover
	-- the visible strip at its own depth and drift sideways on a 7 second loop.
	makeLuaSprite('greyGradient', 'phillyStreets/erect/greyGradient', -700, -480);
	setScrollFactor('greyGradient', 0.05, 0.05);
	setProperty('greyGradient.alpha', 1);

	makeLuaSprite('mistBack', 'phillyStreets/erect/mistBack', -150, -120);
	setScrollFactor('mistBack', 0.4, 0.4);
	setProperty('mistBack.alpha', 0.5);

	makeLuaSprite('mistMid', 'phillyStreets/erect/mistMid', -50, -100);
	setScrollFactor('mistMid', 0.7, 0.7);
	setProperty('mistMid.alpha', 0.45);

	makeLuaSprite('mistFront', 'phillyStreets/erect/mistFront', 60, -60);
	setScrollFactor('mistFront', 1, 1);
	setProperty('mistFront.alpha', 0.25);


	makeLuaSprite('phillySkybox', 'phillyStreets/erect/phillySkybox', -650, -375);
	setScrollFactor('phillySkybox', 0.1, 0.1);
	setProperty('phillySkybox.alpha', 1);

	makeLuaSprite('phillySkyline', 'phillyStreets/erect/phillySkyline', -545, -273);
	scaleObject('phillySkyline', 1, 1);
	setScrollFactor('phillySkyline', 0.2, 0.2);
	setProperty('phillySkyline.alpha', 1);

	makeLuaSprite('phillyForegroundCity', 'phillyStreets/erect/phillyForegroundCity', 625, 94);
	scaleObject('phillyForegroundCity', 1, 1);
	setScrollFactor('phillyForegroundCity', 0.3, 0.3);
	setProperty('phillyForegroundCity.alpha', 1);

	makeLuaSprite('phillyConstruction', 'phillyStreets/erect/phillyConstruction', 1800, 364);
	scaleObject('phillyConstruction', 1, 1);
	setScrollFactor('phillyConstruction', 0.7, 1);
	setProperty('phillyConstruction.alpha', 1);

	makeLuaSprite('phillyHighwayLights', 'phillyStreets/erect/phillyHighwayLights', 284, 305);
	scaleObject('phillyHighwayLights', 1, 1);
	setScrollFactor('phillyHighwayLights', 1, 1);
	setProperty('phillyHighwayLights.alpha', 1);

	makeLuaSprite('phillyHighwayLights_lightmap', 'phillyStreets/phillyHighwayLights_lightmap', 284, 305);
	scaleObject('phillyHighwayLights_lightmap', 1, 1);
	setScrollFactor('phillyHighwayLights_lightmap', 1, 1);
	setProperty('phillyHighwayLights_lightmap.alpha', 1);
	setBlendMode('phillyHighwayLights_lightmap','add')

	makeLuaSprite('phillyHighway', 'phillyStreets/erect/phillyHighway', 139, 209);
	scaleObject('phillyHighway', 1, 1);
	setScrollFactor('phillyHighway', 1, 1);
	setProperty('phillyHighway.alpha', 1);

	makeLuaSprite('phillySmog', 'phillyStreets/phillySmog', -6, 245);
	scaleObject('phillySmog', 1, 1);
	setScrollFactor('phillySmog', 1, 1);
	setProperty('phillySmog.alpha', 1);

	makeAnimatedLuaSprite('phillyCars1', 'phillyStreets/erect/phillyCars', 1748, 818);
	addAnimationByPrefix('phillyCars1', 'car1', 'car1', 24, false);
	addAnimationByPrefix('phillyCars1', 'car2', 'car2', 24, false);
	addAnimationByPrefix('phillyCars1', 'car3', 'car3', 24, false);
	addAnimationByPrefix('phillyCars1', 'car4', 'car4', 24, false);
	-- Erect's per-variant addOffset, so all four bodies put their wheels on the same line
	addOffset('phillyCars1', 'car1', 0, 0)
	addOffset('phillyCars1', 'car2', 20, -15)
	addOffset('phillyCars1', 'car3', 30, 50)
	addOffset('phillyCars1', 'car4', 10, 60)
	setProperty('phillyCars1.flipX', false);
	scaleObject('phillyCars1', 1, 1);
	setScrollFactor('phillyCars1', 1, 1);
	setProperty('phillyCars1.alpha', 1);

	makeAnimatedLuaSprite('phillyCars2', 'phillyStreets/erect/phillyCars', 1748, 818);
	addAnimationByPrefix('phillyCars2', 'car1', 'car1', 24, false);
	addAnimationByPrefix('phillyCars2', 'car2', 'car2', 24, false);
	addAnimationByPrefix('phillyCars2', 'car3', 'car3', 24, false);
	addAnimationByPrefix('phillyCars2', 'car4', 'car4', 24, false);
	addOffset('phillyCars2', 'car1', 0, 0)
	addOffset('phillyCars2', 'car2', 20, -15)
	addOffset('phillyCars2', 'car3', 30, 50)
	addOffset('phillyCars2', 'car4', 10, 60)
	setProperty('phillyCars2.flipX', true);
	scaleObject('phillyCars2', 1, 1);
	setScrollFactor('phillyCars2', 1, 1);
	setProperty('phillyCars2.alpha', 1);

	-- LIMUL-LIGHT-SHIFT: the lamp head sits at local x 114 of this frame, so the
	-- original 1840 parked it 165px right of the car queueing under it, out over the
	-- open road. -150 brings the head over that car, the way the reference art frames it.
	-- LIMUL-CARS: lamp x measured against 1200px-Weekend1Background.webp (the lens block sits
	-- 0.063 car bodies right of the car centre there); Erect's 1840 was ~140px too far right.
	makeAnimatedLuaSprite('phillyTraffic', 'phillyStreets/erect/phillyTraffic', 1704, 608);
	addAnimationByPrefix('phillyTraffic', 'tored', 'greentored', 24, false);
	addAnimationByPrefix('phillyTraffic', 'togreen', 'redtogreen', 24, false);
	setProperty('phillyTraffic.flipX', false);
	scaleObject('phillyTraffic', 1, 1);
	setScrollFactor('phillyTraffic', 1, 1); -- LIMUL-CARS: road furniture
	setProperty('phillyTraffic.alpha', 1);
	runTimer('greentoredTimer', 11);
	playAnim('phillyTraffic', 'togreen', false);

	makeLuaSprite('phillyTraffic_lightmap', 'phillyStreets/erect/phillyTraffic_lightmap', 1704, 608);
	scaleObject('phillyTraffic_lightmap', 1, 1);
	setScrollFactor('phillyTraffic_lightmap', 1, 1); -- LIMUL-CARS: road furniture
	setProperty('phillyTraffic_lightmap.alpha', 1);
	setBlendMode('phillyTraffic_lightmap','add')

	makeLuaSprite('phillyForeground', 'phillyStreets/erect/phillyForeground', 88, 317);
	scaleObject('phillyForeground', 1, 1);
	setScrollFactor('phillyForeground', 1, 1);
	setProperty('phillyForeground.alpha', 1);

	makeLuaSprite('spraycanPile', 'SpraycanPile', 920, 1045);
	scaleObject('spraycanPile', 1, 1);
	setScrollFactor('spraycanPile', 1, 1);
	setProperty('spraycanPile.alpha', 1);

	-- Limul Engine: flat sky backdrop pinned to the camera: at this stage zoom the camera
	-- sees more world than the painted skybox covers, so the corners went black. This is
	-- the backmost layer, only visible where the real art does not reach the screen edge.
	makeLuaSprite('limulSkyFill', 'empty', -500, -500);
	makeGraphic('limulSkyFill', 2600, 1800, '3A3A3A');
	setScrollFactor('limulSkyFill', 0, 0);
	addLuaSprite('limulSkyFill', false);

	addLuaSprite('greyGradient', false);
	addLuaSprite('phillySkybox', false);
	addLuaSprite('phillySkyline', false);
	addLuaSprite('phillyForegroundCity', false);
	addLuaSprite('mistBack', false);
	addLuaSprite('phillyConstruction', false);
	addLuaSprite('phillyHighwayLights', false);
	addLuaSprite('phillyHighwayLights_lightmap', false);
	addLuaSprite('phillyHighway', false);
	addLuaSprite('phillySmog', false);
	addLuaSprite('mistMid', false);
	addLuaSprite('phillyCars1', false);
	addLuaSprite('phillyCars2', false);
	addLuaSprite('phillyTraffic', false);
	addLuaSprite('phillyTraffic_lightmap', false);
	addLuaSprite('mistFront', false);
	addLuaSprite('phillyForeground', false);
	addLuaSprite('spraycanPile', true);

	-- LIMUL-WEEKEND1-CANS: JS Engine can port, 2hot only (same coords as PhillyStreets.hx:431).
	if weekend1CreateCan ~= nil and string.find(string.lower(songName), '2hot', 1, true) then
		weekend1CreateCan(1450, 805)
	end

	-- LIMUL-CARS: Erect parks both bodies at the head of their lane and sends them off
	-- from onBeatHit.  The (1800,480) placement and these two timers are the leftovers of
	-- its angle-only KA-DE port, which is why the cars hung in mid-air and rocked.
	limulInitCars()
	-- Limul Engine: slow sideways drift for the fog sheets; a looping timer instead of
	-- per-frame work, and every tween is written from a fixed base x so it cannot walk away.
	runTimer('mistDrift', 7, 0);
end

local Light = 0
local mistPhase = 0
local carWaiting = 0
local Car1variant = 0
local Car1speed = 1,3
local Car2variant = 0
local Car2speed = 1,3

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	if tag == 'mistDrift' then
		mistPhase = mistPhase + 1
		local dir = 1
		if mistPhase % 2 == 0 then
			dir = -1
		end
		doTweenX('mistBackDrift', 'mistBack', -150 + dir * 70, 7, 'sineInOut');
		doTweenX('mistMidDrift', 'mistMid', -50 - dir * 50, 7, 'sineInOut');
		doTweenX('mistFrontDrift', 'mistFront', 60 + dir * 30, 7, 'sineInOut');
	end
	if tag == 'redtogreenTimer' then
		Light = 0
		--playSound('test')
		playAnim('phillyTraffic', 'togreen', false);
		runTimer('greentoredTimer', 11);
	end
	if tag == 'greentoredTimer' then
		Light = 1
		--playSound('test1')
		playAnim('phillyTraffic', 'tored', false);
		runTimer('redtogreenTimer', 8);
	end
	--[[if tag == rainSound then
		playSound('raindrops/raindrop'..getRandomInt(1,16), 10)
		runTimer('rainSound', getRandomInt(1,5)*0.1);
	end]]
end


-- LIMUL-CARS BEGIN -- Erect's traffic, ported to this 0.6.3 build.
--
-- WHY THIS EXISTS. The KA-DE stage files this build inherited kept only the angle tweens
-- of Erect's car code, so nothing ever moved a car along the road: both bodies sat at
-- (1800,480), in mid-air left of the street, rocking. Everything below is Erect's
-- streetsErect.lua driveCarFromLeft / FromRight / ToLight / FromLight - same three-point
-- quadratic paths, same per-variant durations, same rotation sweeps, same 10%-per-beat
-- spawn chance, and the same rule that a left car pulls up at the light while it is red
-- and sets off when it turns green.
--
-- WHAT IS NOT VERBATIM. Erect moves a car with doTweenQuadMotion ->
-- runHaxeFunction('quadMotionTween') -> FlxTween.quadMotion, and this engine registers
-- neither runHaxeFunction nor doTweenQuadMotion, so that call does nothing here. The curve
-- is therefore integrated in Lua instead: each frame the car is placed at
-- bezier(ease(t / duration)) with the easing FlxTween would have applied
-- (FlxEase.linear / cubicOut / sineIn), which is what quadMotion itself does - it
-- evaluates the curve at the eased position. In all four Erect drives the angle tween and
-- the motion tween share one ease, so the rotation comes from the same eased value.
--
-- The light cycle is left to the stage's own greentoredTimer/redtogreenTimer (11 s green,
-- 8 s red), which already matches Erect's 30-beat / 20-beat cadence at this song's 155 BPM.

local LIMUL_OC_X, LIMUL_OC_Y = 306.6, 168.3

-- LIMUL-SLOW: Erect's crossing times, stretched for this build's tighter framing.
local LIMUL_CAR_SLOW = 2.6

local limulEase = {
    linear = function(t) return t end,
    cubeOut = function(t) local u = 1 - t return 1 - u * u * u end,
    sineIn = function(t) return 1 - math.cos(t * math.pi / 2) end
}

-- Road points as Erect authored them; the sprite is parked offsetCars up and left of them.
-- dur[variant] = {min, max} seconds for the whole crossing, per Erect's own spread.
local LIMUL_DRIVES = {
    fromLeft = {
        path = {{1570, 1049 - 30}, {2400, 980 - 50}, {3102, 1127 + 40}},
        angle = {-8, 18}, ease = 'linear',
        dur = {{1.0, 1.7}, {0.6, 1.2}, {1.5, 2.5}, {1.5, 2.5}}
    },
    fromRight = {
        path = {{3102, 1127 + 60}, {2400, 980 - 30}, {1570, 1049 - 10}},
        angle = {18, -8}, ease = 'linear',
        dur = {{1.0, 1.7}, {0.6, 1.2}, {1.5, 2.5}, {1.5, 2.5}}
    },
    toLight = {
        path = {{1500 - 20, 1049 - 20}, {1770 - 80, 994 + 10}, {1950 - 80, 980 + 15}},
        angle = {-7, -5}, ease = 'cubeOut',
        dur = {{1.0, 1.7}, {0.9, 1.5}, {1.5, 2.5}, {1.5, 2.5}}
    },
    fromLight = {
        path = {{1950 - 80, 980 + 15}, {2400, 980 - 50}, {3102, 1127 + 40}},
        angle = {-5, 18}, ease = 'sineIn',
        dur = {{1.8, 3.0}, {1.8, 3.0}, {1.8, 3.0}, {1.8, 3.0}}
    }
}

local limulCars = {
    {tag = 'phillyCars1', drive = nil, t = 0, dur = 1, free = true, waiting = false},
    {tag = 'phillyCars2', drive = nil, t = 0, dur = 1, free = true, waiting = false}
}

-- Called from the end of onCreate: park both bodies at the head of their lane, hidden
-- behind the retaining wall, and take over the angle the old timers used to tween.
function limulInitCars()
    local lanes = {'fromLeft', 'fromRight'}
    for i = 1, 2 do
        local car = limulCars[i]
        local head = LIMUL_DRIVES[lanes[i]].path[1]
        if luaSpriteExists(car.tag) then
            setProperty(car.tag .. '.x', head[1] - LIMUL_OC_X)
            setProperty(car.tag .. '.y', head[2] - LIMUL_OC_Y)
            setProperty(car.tag .. '.angle', LIMUL_DRIVES[lanes[i]].angle[1])
            setProperty(car.tag .. '.alpha', 0)
        end
    end
end

function limulStartDrive(car, name)
    if not luaSpriteExists(car.tag) then
        return
    end
    local d = LIMUL_DRIVES[name]
    local variant = getRandomInt(1, 4)
    local spread = d.dur[variant]
    car.drive = d
    car.t = 0
    car.dur = getRandomFloat(spread[1], spread[2]) * LIMUL_CAR_SLOW
    car.free = false
    car.waiting = false
    playAnim(car.tag, 'car' .. variant, false)
    setProperty(car.tag .. '.alpha', 1)
    limulPlaceCar(car, 0)
end

-- u is real time over the drive's duration; the curve is walked at the eased position.
function limulPlaceCar(car, u)
    local d = car.drive
    local e = limulEase[d.ease](u)
    local a = (1 - e) * (1 - e)
    local b = 2 * (1 - e) * e
    local c = e * e
    local p = d.path
    setProperty(car.tag .. '.x', p[1][1] * a + p[2][1] * b + p[3][1] * c - LIMUL_OC_X)
    setProperty(car.tag .. '.y', p[1][2] * a + p[2][2] * b + p[3][2] * c - LIMUL_OC_Y)
    setProperty(car.tag .. '.angle', d.angle[1] + (d.angle[2] - d.angle[1]) * e)
end

function onUpdate(elapsed)
    if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
    for i = 1, 2 do
        local car = limulCars[i]
        if car.drive ~= nil then
            car.t = car.t + elapsed
            if car.t >= car.dur then
                local d = car.drive
                limulPlaceCar(car, 1)
                car.drive = nil
                car.free = true
                -- Erect: a car that pulled up to a red light waits there until it turns green.
                if d == LIMUL_DRIVES.toLight then
                    car.waiting = true
                    if Light == 0 then
                        runTimer('limulStartDelay' .. i, getRandomFloat(0.2, 1.2))
                    end
                end
            else
                limulPlaceCar(car, car.t / car.dur)
            end
        end
    end
end

function onBeatHit()
    if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
    if getRandomBool(10) and limulCars[1].free then
        if Light == 0 then
            limulStartDrive(limulCars[1], 'fromLeft')
        else
            limulStartDrive(limulCars[1], 'toLight')
        end
    end
    if getRandomBool(10) and limulCars[2].free and Light == 0 then
        limulStartDrive(limulCars[2], 'fromRight')
    end
end

-- Extend the stage's own timer handler rather than replace it, so the fog drift and the
-- light cycle keep running.  The chunk has already defined onTimerCompleted above, so the
-- original is captured first and called from the new one.
local limulTimerBefore = onTimerCompleted

function onTimerCompleted(tag, loops, loopsLeft)
    if tag == 'redtogreenTimer' and Light == 0 then
        for i = 1, 2 do
            if limulCars[i].waiting then
                runTimer('limulStartDelay' .. i, getRandomFloat(0.2, 1.2))
            end
        end
    elseif tag == 'limulStartDelay1' then
        if limulCars[1].waiting then
            limulStartDrive(limulCars[1], 'fromLight')
        end
    elseif tag == 'limulStartDelay2' then
        if limulCars[2].waiting then
            limulStartDrive(limulCars[2], 'fromLight')
        end
    end
    if limulTimerBefore ~= nil then
        limulTimerBefore(tag, loops, loopsLeft)
    end
end

-- LIMUL-CARS END


-- LIMUL-NENE-COMBO (2026-11-04): Nene's combo cheer, ported from 1.0.4's
-- source/states/stages/PhillyStreets.hx:789-806 -- on every player note hit there is a 10%
-- roll, and if the combo is exactly 50 or 100 the matching animation plays. Lit Up, Darnell and
-- 2Hot run this stage with gf 'nene' (combo50 / combo100 are defined in characters/nene.json),
-- any other girlfriend simply does not have the animation and is left dancing.
local function limulCurrentAnim(obj)
	local ok, name = pcall(getProperty, obj..'.animation.curAnim.name')
	if ok and name ~= nil then return name end
	ok, name = pcall(getProperty, obj..'.atlas.anim.lastPlayedAnim')
	if ok then return name end
	return nil
end

function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
	-- The roll comes before the combo check, exactly like the original, so the dice are spent
	-- on every note and not only on the 50th and 100th.
	if getRandomBool(10) ~= true then return end

	-- combo is a PlayState field (PlayState.hx:188), not one of the globals this engine pushes
	-- into Lua -- FunkinLua.hx publishes score/misses/hits but never combo -- so it has to be
	-- read through getProperty.
	local ok, combo = pcall(getProperty, 'combo')
	if not ok or type(combo) ~= 'number' then return end
	combo = math.floor(combo)
	if combo ~= 50 and combo ~= 100 then return end

	local name = 'combo'..combo
	-- playAnim(obj, missingName) is a silent no-op here, and specialAnim is only cleared when an
	-- animation actually finishes (Character.hx:273-275) while dance() is skipped for as long as
	-- it is up (Character.hx:323): arming it blindly would freeze a girlfriend without the anim
	-- out of her dance loop for the rest of the song. Read the name back, then arm.
	playAnim('gf', name, false)
	if limulCurrentAnim('gf') == name then
		setProperty('gf.specialAnim', true)
	end
end
