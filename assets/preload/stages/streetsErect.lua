-- [Limul 2026-11-02] deszcz ze shadera Erecta: odpetty na stale.
-- 'runHaxeFunction' jest w tym buildzie stubem (ponizej), wiec 'activateRainShader'
-- nigdy nie podlancza filtra do kamery - shader nie rysowal nic, a blok w onUpdate
-- palil ~7 wywolan do silnika co ramke. Deszcz widoczny robi pula kreszek z
-- data/<song>/rain.lua, z poziomem intensywnosci na utwor (weak/normal/strong/storm).
-- Flage przelaczy na true tylko ten, kto wczesnie podepnie aktywacje filtra przez
-- runHaxeCode.
LIMUL_RAIN_SHADER = false
-- [Limul 0.6.3 compatibility shim]
-- These Psych 1.0.4 Lua globals are not registered by this 0.6.3 engine, and a
-- nil call aborts the rest of the callback, so each one gets an explicit stub.
if runHaxeFunction == nil then
    function _G.runHaxeFunction(name, args) end
end
function onCreate()
    addHaxeLibrary('LuaUtils', 'psychlua')
    if lowQuality == false then
        for i = 0, 2 do
            makeLuaSprite('sky'..(i + 1), 'phillyStreets/erect/phillySkybox', -650, -375)
            scaleObject('sky'..(i + 1), 0.65, 0.65, false)
            setScrollFactor('sky'..(i + 1), 0.1, 0.1)
            addLuaSprite('sky'..(i + 1))
            setProperty('sky'..(i + 1)..'.x', getProperty('sky'..(i + 1)..'.x') + (getProperty('sky'..(i + 1)..'.width') * 0.65) * i)
        end
    else
        for i = 0, 1 do
            makeLuaSprite('sky'..(i + 1), 'phillyStreets/erect/phillySkybox', -450, -375)
            scaleObject('sky'..(i + 1), 0.65, 0.65, false)
            setScrollFactor('sky'..(i + 1), 0.1, 0.1)
            addLuaSprite('sky'..(i + 1))
            setProperty('sky'..(i + 1)..'.x', getProperty('sky'..(i + 1)..'.x') + (getProperty('sky'..(i + 1)..'.width') * 0.65) * i)
        end
    end

    makeLuaSprite('skyline', 'phillyStreets/erect/phillySkyline', -545, -273)
    setScrollFactor('skyline', 0.2, 0.2)
    addLuaSprite('skyline')

    makeLuaSprite('city', 'phillyStreets/erect/phillyForegroundCity', 625, 94)
    setScrollFactor('city', 0.3, 0.3)
    addLuaSprite('city')
    
    if lowQuality == false then
        makeLuaSprite('constructionSite', 'phillyStreets/erect/phillyConstruction', 1800, 364)
        setScrollFactor('constructionSite', 0.7, 1)
        addLuaSprite('constructionSite')

        makeLuaSprite('highwayLights', 'phillyStreets/erect/phillyHighwayLights', 284, 305)
        addLuaSprite('highwayLights')

        makeLuaSprite('highwayLightMap', 'phillyStreets/phillyHighwayLights_lightmap', 284, 305)
        setBlendMode('highwayLightMap', 'ADD')
        addLuaSprite('highwayLightMap')
        setProperty('highwayLightMap.alpha', 0.6)

        makeLuaSprite('highway', 'phillyStreets/erect/phillyHighway', 139, 209)
        addLuaSprite('highway')
    end

    makeAnimatedLuaSprite('cars1', 'phillyStreets/erect/phillyCars', 1200, 818)
    setScrollFactor('cars1', 0.9, 1)
    addAnimationByPrefix('cars1', 'normal', 'car1', 24, false)
    addOffset('cars1', 'normal', 0, 0)
    addAnimationByPrefix('cars1', 'sport', 'car2', 24, false)
    addOffset('cars1', 'sport', 20, -15)
    addAnimationByPrefix('cars1', 'van', 'car3', 24, false)
    addOffset('cars1', 'van', 30, 50)
    addAnimationByPrefix('cars1', 'suv', 'car4', 24, false)
    addOffset('cars1', 'suv', 10, 60)
    addLuaSprite('cars1')
    
    makeAnimatedLuaSprite('cars2', 'phillyStreets/erect/phillyCars', 1200, 818)
    setScrollFactor('cars2', 0.9, 1)
    addAnimationByPrefix('cars2', 'normal', 'car1', 24, false)
    addOffset('cars2', 'normal', 0, 0)
    addAnimationByPrefix('cars2', 'sport', 'car2', 24, false)
    addOffset('cars2', 'sport', 20, -15)
    addAnimationByPrefix('cars2', 'van', 'car3', 24, false)
    addOffset('cars2', 'van', 30, 50)
    addAnimationByPrefix('cars2', 'suv', 'car4', 24, false)
    addOffset('cars2', 'suv', 10, 60)
    setObjectOrder('cars2', getObjectOrder('cars1'))
    setProperty('cars2.flipX', true)
    addLuaSprite('cars2')

    -- LIMUL-LIGHT-SHIFT: the lamp head sits at local x 114 of this frame, so the
    -- original 1840 parked it 165px right of the car queueing under it, out over the
    -- open road. -150 brings the head over that car, the way the reference art frames it.
    makeAnimatedLuaSprite('trafficLight', 'phillyStreets/erect/phillyTraffic', 1690, 608)
    addAnimationByPrefix('trafficLight', 'redTrans', 'greentored', 24, false)
    addAnimationByPrefix('trafficLight', 'greenTrans', 'redtogreen', 24, false)
    setScrollFactor('trafficLight', 0.9, 1)
    addLuaSprite('trafficLight')
    
    if lowQuality == false then
        makeLuaSprite('trafficLightMap', 'phillyStreets/erect/phillyTraffic_lightmap', 1690, 608)
        setScrollFactor('trafficLightMap', 0.9, 1)
        setBlendMode('trafficLightMap', 'ADD')
        addLuaSprite('trafficLightMap')
        setProperty('trafficLightMap.alpha', 0.6)
    end

    makeLuaSprite('gradient1', 'phillyStreets/erect/greyGradient', 118, 167)
    setBlendMode('gradient1', 'ADD')
    addLuaSprite('gradient1')
    setProperty('gradient1.alpha', 0.3)

    makeLuaSprite('gradient2', 'phillyStreets/erect/greyGradient', 118, 167)
    setBlendMode('gradient2', 'MULTIPLY')
    setObjectOrder('gradient2', getObjectOrder('gradient1'))
    addLuaSprite('gradient2')
    setProperty('gradient2.alpha', 0.8)
    
    makeLuaSprite('street', 'phillyStreets/erect/phillyForeground', 88, 317)
    addLuaSprite('street')

    makeLuaSprite('sprayCans', 'phillyStreets/SpraycanPile', 920, 1045)
    addLuaSprite('sprayCans', true)

    -- LIMUL-WEEKEND1-CANS: JS Engine can port, 2hot nightmare only (this stage serves it).
    if weekend1CreateCan ~= nil and string.find(string.lower(songName), '2hot', 1, true) then
        weekend1CreateCan(1450, 805)
    end
    
    makeAnimatedLuaSprite('paper', 'phillyStreets/erect/paper', 350, 608)
    addAnimationByPrefix('paper', 'anim', 'Paper Blowing instance 1', 24, false)
    setScrollFactor('paper', 1.1, 1.1)
    addLuaSprite('paper', true)
    setProperty('paper.visible', false)
end

function onCreatePost()
    -- Sets up the haxe commands needed for the stage to work.
    runHaxeCode([[
        import psychlua.LuaUtils;
        function activateRainShader() FlxG.camera.setFilters([new ShaderFilter(game.getLuaObject('rainFilter').shader)]);
        function deactivateRainShader() FlxG.camera.setFilters([]);
        function quadMotionTween(object:String, fromX:Float, fromY:Float, controlX:Float, controlY:Float, toX:Float, toY:Float, duration:Float, ease:String) {
            FlxTween.quadMotion(game.getLuaObject(object), fromX, fromY, controlX, controlY, toX, toY, duration, true, {ease: LuaUtils.getTweenEaseByString(ease)});
        }
        // LIMUL-CAM-BOUNDS: chart camera events ('Dad,-250', zoom-outs) pushed the view
        // past the street art (foreground spans x 88..2729), leaving empty space around
        // the set. FlxCamera clamps scroll to these bounds on every update.
        FlxG.camera.setBounds(-120, -300, 2920, 1900);
    ]])

    if lowQuality == false then
        mistData = {
            {mistImage = 'mistMid', scrollFactor = 1.2, alpha = 0.6, velocity = 172, scale = 1, objectOrder = ''},
            {mistImage = 'mistMid', scrollFactor = 1.1, alpha = 0.6, velocity = 150, scale = 1, objectOrder = ''},
            {mistImage = 'mistBack', scrollFactor = 1.2, alpha = 0.8, velocity = -80, scale = 1, objectOrder = ''},
            {mistImage = 'mistMid', scrollFactor = 0.95, alpha = 0.5, velocity = -50, scale = 0.8, objectOrder = 'gradient1'},
            {mistImage = 'mistBack', scrollFactor = 0.8, alpha = 1, velocity = 40, scale = 0.7, objectOrder = 'cars1'},
            {mistImage = 'mistMid', scrollFactor = 0.5, alpha = 1, velocity = 20, scale = 1.1, objectOrder = 'city'}
        }
        for mistNum, data in ipairs(mistData) do
            for i = 0, 2 do
                makeLuaSprite('mist'..mistNum..''..(i + 1), 'phillyStreets/erect/'..data.mistImage, -650, -100)
                scaleObject('mist'..mistNum..''..(i + 1), data.scale, data.scale, false)
                setScrollFactor('mist'..mistNum..''..(i + 1), data.scrollFactor, data.scrollFactor)
                setBlendMode('mist'..mistNum..''..(i + 1), 'ADD')
                if data.objectOrder ~= '' then
                    setObjectOrder('mist'..mistNum..''..(i + 1), getObjectOrder(data.objectOrder) + 1)
                end
                addLuaSprite('mist'..mistNum..''..(i + 1), true)
                setProperty('mist'..mistNum..''..(i + 1)..'.alpha', data.alpha)
                setProperty('mist'..mistNum..''..(i + 1)..'.color', 0x5C5C5C)
                setProperty('mist'..mistNum..''..(i + 1)..'.velocity.x', data.velocity)
                local offsetMist = getProperty('mist'..mistNum..''..(i + 1)..'.x') + (getProperty('mist'..mistNum..''..(i + 1)..'.width') * data.scale) * i
                setProperty('mist'..mistNum..''..(i + 1)..'.x', offsetMist)
            end
        end
    end

    if LIMUL_RAIN_SHADER == true and shadersEnabled == true then
        initLuaShader('adjustColor')
        for i, object in ipairs({'boyfriend', 'dad', 'gf', 'sprayCans'}) do
            setSpriteShader(object, 'adjustColor')
            setShaderFloat(object, 'hue', -5)
            setShaderFloat(object, 'saturation', -40)
            setShaderFloat(object, 'contrast', -25)
            setShaderFloat(object, 'brightness', -20)
        end

        initLuaShader('rain')
        makeLuaSprite('rainFilter')
        setSpriteShader('rainFilter', 'rain')
        setShaderFloat('rainFilter', 'uScale', screenHeight / 200)
        if stringStartsWith(songName:gsub('-', ' '):lower(), 'darnell') then
            intensityStart = 0
            intensityEnd = 0.1
        elseif stringStartsWith(songName:gsub('-', ' '):lower(), 'lit up') then
            intensityStart = 0.1
            intensityEnd = 0.2
        elseif stringStartsWith(songName:gsub('-', ' '):lower(), '2hot') then
            intensityStart = 0.2
            intensityEnd = 0.4
        else
            intensityStart = 0.1
            intensityEnd = 0.15
        end
        setShaderFloat('rainFilter', 'uIntensity', intensityStart)
        setShaderFloatArray('rainFilter', 'uRainColor', {168 / 255, 173 / 255, 181 / 255})
        setShaderFloatArray('rainFilter', 'uFrameBounds', {0, 0, screenWidth, screenHeight})
        runHaxeFunction('activateRainShader')
    end
end

local elapsedTime = 0
function onUpdate(elapsed)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
    --[[
        This is to make the skyBox dynamic by using the 3 'sky' sprites,
        and move them right behind eachother. When one of them goes offscreen,
        it moves them behind the pack to make the skyBox seemless.
    ]]
    if lowQuality == false then
        for i = 1, 3 do
            if getProperty('sky'..i..'.x') < -(getProperty('sky'..i..'.width') * 0.65) * 2 then
                setProperty('sky'..i..'.x', getProperty('sky'..i..'.x') + (getProperty('sky'..i..'.width') * 0.65) * 3)
            end
            setProperty('sky'..i..'.x', getProperty('sky'..i..'.x') - elapsed * 22)
        end
    end
    
    -- Makes the rain active and increase its intensity from 'intensityStart' to 'intensityEnd'.
    if LIMUL_RAIN_SHADER == true and shadersEnabled == true then
        intensityValue = math.remapToRange(getSongPosition(), 0, songLength, intensityStart, intensityEnd)
        setShaderFloat('rainFilter', 'uIntensity', intensityValue)
        elapsedTime = elapsedTime + elapsed
        setShaderFloat('rainFilter', 'uTime', elapsedTime)
        setShaderFloatArray('rainFilter', 'uScreenResolution', {screenWidth, screenHeight})
        setShaderFloatArray('rainFilter', 'uCameraBounds', {getProperty('camGame.viewLeft'), getProperty('camGame.viewTop'), getProperty('camGame.viewRight'), getProperty('camGame.viewBottom')})
    end
end

function onUpdatePost(elapsed)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
    --[[
        Everything here controls the movement of the fog around the stage.
        3 'mist' sprites of the same placement follow along one another 
        until one of them gets too far to the left or right, and so then get behind the pack.
        Also, all of them do an up and down motion depending of their set values.
    ]]
    if lowQuality == false then
        for mistNum, mistScale in ipairs({1, 1, 1, 0.8, 0.7, 1.1}) do
            for i = 1, 3 do
                if getProperty('mist'..mistNum..''..i..'.velocity.x') > 0 then
                    if getProperty('mist'..mistNum..''..i..'.x') > (getProperty('mist'..mistNum..''..i..'.width') * mistScale) * 1.5 then
                        setProperty('mist'..mistNum..''..i..'.x', getProperty('mist'..mistNum..''..i..'.x') - (getProperty('mist'..mistNum..''..i..'.width') * mistScale) * 3)
                    end
                else
                    if getProperty('mist'..mistNum..''..i..'.x') < -(getProperty('mist'..mistNum..''..i..'.width') * mistScale) * 1.5 then
                        setProperty('mist'..mistNum..''..i..'.x', getProperty('mist'..mistNum..''..i..'.x') + (getProperty('mist'..mistNum..''..i..'.width') * mistScale) * 3)
                    end
                end
            end
        end
        for i = 1, 3 do
            setProperty('mist1'..i..'.y', 660 + (math.sin(elapsedTime * 0.35) * 70))
            setProperty('mist2'..i..'.y', 500 + (math.sin(elapsedTime * 0.3) * 80))
            setProperty('mist3'..i..'.y', 540 + (math.sin(elapsedTime * 0.4) * 60))
            setProperty('mist4'..i..'.y', 230 + (math.sin(elapsedTime * 0.3) * 70))
            setProperty('mist5'..i..'.y', 170 + (math.sin(elapsedTime * 0.35) * 50))
            setProperty('mist6'..i..'.y', -80 + (math.sin(elapsedTime * 0.08) * 100))
        end
    end
end

function onGameOver()
    -- Needed if we don't want the rain to affect the Game Over screen.
    if LIMUL_RAIN_SHADER == true and shadersEnabled == true then
        runHaxeFunction('deactivateRainShader')
    end
end

function math.remapToRange(value, start1, stop1, start2, stop2)
    return start2 + (value - start1) * ((stop2 - start2) / (stop1 - start1))
end

-- This part of the script is where you can see how the cars, traffic light and paper blow work.
isRedLight = false
lastChange = 0
changeInterval = 8

isCarWaiting = false
cars1CanBeReset = true
cars2CanBeReset = true
paperCanBeReset = true
function onBeatHit()
    if getRandomBool(10) and curBeat ~= lastChange + changeInterval and cars1CanBeReset == true then
        if isRedLight == false then
            driveCarFromLeft()
        else
            driveCarToLight()
        end
    end
    if getRandomBool(0.6) and paperCanBeReset == true then
        paperCanBeReset = false
        local offsetPaper = getRandomFloat(-150, 150)
        setProperty('paper.y', 608 + offsetPaper)
        setProperty('paper.visible', true)
        playAnim('paper', 'anim')
        runTimer('paperReset', 2)
    end
    if getRandomBool(10) and curBeat ~= lastChange + changeInterval and cars2CanBeReset == true then
        if isRedLight == false then
            driveCarFromRight()
        end
    end
    if curBeat == lastChange + changeInterval then
        changeLights()
    end
end

-- Changes the light from red to green, or vice-versa.
function changeLights()
    lastChange = curBeat
    isRedLight = not isRedLight
    if isRedLight == true then
        playAnim('trafficLight', 'redTrans')
        changeInterval = 20
    else
        playAnim('trafficLight', 'greenTrans')
        changeInterval = 30
        if isCarWaiting == true then
            driveCarFromLight()
        end
    end
end

--[[
    Moves 'cars1' from left to right.
    The car is randomized along with their respective speed.
    (Ex: The sports car will always move faster than the van or suv)
    All the 'driveCar' functions work the same, only their starting and end point change.
]]
carVariants = {'normal', 'sport', 'van', 'suv'}
offsetCars = {x = 306.6, y = 168.3}

-- LIMUL-SLOW: Erect's authored crossing times were written for a camera that frames the
-- whole block; every Weekend 1 shot here crops the road far tighter, so the same world
-- speed reads as a blur ("auta za szybko"). One multiplier, applied to the duration
-- after Erect's own per-variant spread is picked, so the ordering is kept.
LIMUL_CAR_SLOW = 2.6
function driveCarFromLeft()
    cars1CanBeReset = false
    selectedCars1 = getRandomInt(1, 4)
    playAnim('cars1', carVariants[selectedCars1])
    if selectedCars1 == 1 then
        durationCars1 = getRandomFloat(1, 1.7)
    elseif selectedCars1 == 2 then
        durationCars1 = getRandomFloat(0.6, 1.2)
    elseif selectedCars1 == 3 or selectedCars1 == 4 then
        durationCars1 = getRandomFloat(1.5, 2.5)
    end

    durationCars1 = durationCars1 * LIMUL_CAR_SLOW

    local rotation = {Start = -8, Finish = 18}
    local pathing = {
        {x = 1570 - offsetCars.x, y = 1049 - offsetCars.y - 30},
        {x = 2400 - offsetCars.x, y = 980 - offsetCars.y - 50},
        {x = 3102 - offsetCars.x, y = 1127 - offsetCars.y + 40}
    }
    setProperty('cars1.angle', rotation.Start)
    doTweenAngle('changeCars1Angle', 'cars1', rotation.Finish, durationCars1, 'linear') 
    doTweenQuadMotion('cars1', pathing, durationCars1, 'linear')
end

-- Moves 'cars2' from right to left.
function driveCarFromRight()
    cars2CanBeReset = false
    selectedCars2 = getRandomInt(1, 4)
    playAnim('cars2', carVariants[selectedCars2])
    if selectedCars2 == 1 then
        durationCars2 = getRandomFloat(1, 1.7)
    elseif selectedCars2 == 2 then
        durationCars2 = getRandomFloat(0.6, 1.2)
    elseif selectedCars2 == 3 or selectedCars2 == 4 then
        durationCars2 = getRandomFloat(1.5, 2.5)
    end

    durationCars2 = durationCars2 * LIMUL_CAR_SLOW

    local rotation = {Start = 18, Finish = -8}
    local pathing = {
        {x = 3102 - offsetCars.x, y = 1127 - offsetCars.y + 60},
        {x = 2400 - offsetCars.x, y = 980 - offsetCars.y - 30},
        {x = 1570 - offsetCars.x, y = 1049 - offsetCars.y - 10}
    }
    setProperty('cars2.angle', rotation.Start)
    doTweenAngle('changeCars2Angle', 'cars2', rotation.Finish, durationCars2, 'linear')
    doTweenQuadMotion('cars2', pathing, durationCars2, 'linear')
end

-- Moves 'cars1' from left and stops it at the traffic light.
function driveCarToLight()
    cars1CanBeReset = false
    selectedCars1 = getRandomInt(1, 4)
    playAnim('cars1', carVariants[selectedCars1])
    if selectedCars1 == 1 then
        durationCars1 = getRandomFloat(1, 1.7)
    elseif selectedCars1 == 2 then
        durationCars1 = getRandomFloat(0.9, 1.5)
    elseif selectedCars1 == 3 or selectedCars1 == 4 then
        durationCars1 = getRandomFloat(1.5, 2.5)
    end

    durationCars1 = durationCars1 * LIMUL_CAR_SLOW

    local rotation = {Start = -7, Finish = -5}
    local pathing = {
        {x = 1500 - offsetCars.x - 20, y = 1049 - offsetCars.y - 20},
        {x = 1770 - offsetCars.x - 80, y = 994 - offsetCars.y + 10},
        {x = 1950 - offsetCars.x - 80, y = 980 - offsetCars.y + 15}
    }
    setProperty('cars1.angle', rotation.Start)
    doTweenAngle('changeCarsLightAngle', 'cars1', rotation.Finish, durationCars1, 'cubeOut')
    doTweenQuadMotion('cars1', pathing, durationCars1, 'cubeOut')
end

-- Moves 'cars1' from the traffic light to the right.
function driveCarFromLight()
    isCarWaiting = false
    durationCars1 = getRandomFloat(1.8, 3) * LIMUL_CAR_SLOW
    
    local rotation = {Start = -5, Finish = 18}
    local pathing = {
        {x = 1950 - offsetCars.x - 80, y = 980 - offsetCars.y + 15},
        {x = 2400 - offsetCars.x, y = 980 - offsetCars.y - 50},
        {x = 3102 - offsetCars.x, y = 1127 - offsetCars.y + 40}
    }
    setProperty('cars1.angle', rotation.Start)
    doTweenAngle('changeCars1Angle', 'cars1', rotation.Finish, durationCars1, 'sineIn')
    doTweenQuadMotion('cars1', pathing, durationCars1, 'sineIn')
end

--[[
    Works the same as 'quadPath', but doesn't use FlxPoint.
    Apparently, using FlxPoint just crashes the game for some reason,
    so I had to find an alternative.
]]
function doTweenQuadMotion(vars, point, duration, ease)
    -- LIMUL-QUAD-LEGS: see limulQuadPoint below for why this is stepped instead of delegated.
    setProperty(vars .. '.x', point[1].x)
    setProperty(vars .. '.y', point[1].y)
    if duration <= 0 then
        setProperty(vars .. '.x', point[3].x)
        setProperty(vars .. '.y', point[3].y)
        return
    end
    limulQuadDrives[vars] = {point = point, ease = ease, leg = 1, time = duration / LIMUL_CAR_LEGS}
    limulQuadLeg(vars)
end

--[[
    FlxTween.quadMotion is not reachable from Lua in this build: Psych 1.0.4 exposes it
    through runHaxeFunction, which 0.6.3 does not define, so the stage's own Haxe helper is
    never registered.  Sampling the same quadratic Bezier into LIMUL_CAR_LEGS equal-time legs
    and chaining them gives back the arc and, because the ease is applied to the global
    parameter before sampling, FlxTween's speed profile too.
]]
LIMUL_CAR_LEGS = 6
limulQuadDrives = {}

local limulEases = {
    linear  = function(t) return t end,
    sineIn  = function(t) return 1 - math.cos(t * math.pi / 2) end,
    sineOut = function(t) return math.sin(t * math.pi / 2) end,
    quadIn  = function(t) return t * t end,
    quadOut = function(t) return t * (2 - t) end,
    cubeIn  = function(t) return t * t * t end,
    cubeOut = function(t) local u = t - 1 return u * u * u + 1 end
}

function limulQuadPoint(point, t, ease)
    local e = (limulEases[ease] or limulEases.linear)(t)
    local a = (1 - e) * (1 - e)
    local b = 2 * (1 - e) * e
    local c = e * e
    return {
        x = point[1].x * a + point[2].x * b + point[3].x * c,
        y = point[1].y * a + point[2].y * b + point[3].y * c
    }
end

function limulQuadLeg(vars)
    local drive = limulQuadDrives[vars]
    if drive == nil then return end
    local to = limulQuadPoint(drive.point, drive.leg / LIMUL_CAR_LEGS, drive.ease)
    drive.leg = drive.leg + 1
    doTweenX(vars .. 'LimulX', vars, to.x, drive.time, 'linear')
    doTweenY(vars .. 'LimulY', vars, to.y, drive.time, 'linear')
end

-- Each leg's x tween hands over to the next one; the y tween is only a companion.
function limulQuadStep(tag)
    local vars = string.match(tag, '^(.-)LimulX$')
    if vars == nil then return end
    local drive = limulQuadDrives[vars]
    if drive == nil then return end
    if drive.leg > LIMUL_CAR_LEGS then
        limulQuadDrives[vars] = nil
        return
    end
    limulQuadLeg(vars)
end

function onTweenCompleted(tag)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
    limulQuadStep(tag)
    for i = 1, 2 do
        if tag == 'changeCars'..i..'Angle' then
            _G['cars'..i..'CanBeReset'] = true
        end
    end
    if tag == 'changeCarsLightAngle' then
        isCarWaiting = true
        if isRedLight == false then
            local delay = getRandomFloat(0.2, 1.2)
            runTimer('startDelay', delay)
        end
    end
end

function onTimerCompleted(tag, loops, loopsLeft)
	if inGameOver then return end -- LIMUL-GAMEOVER-GUARD: PlayState is not updating or drawing while the game-over screen is up
    if tag == 'paperReset' then
        paperCanBeReset = true
        setProperty('paper.visible', false)
    end
    if tag == 'startDelay' then
        driveCarFromLight()
    end
end

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
