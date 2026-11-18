-- Limul Engine - darnell rain, ported 1:1 from Funkin' 0.8.6 (V-Slice).
--
-- 0.8.6 keeps Weekend 1 in HScript: assets/scripts/stages/phillyStreets.hxc and
-- phillyStreetsErect.hxc create RuntimeRainShader (graphics/shaders/RuntimeRainShader.hx,
-- assets/shaders/rain.frag) and attach it to the game camera with
-- FlxG.camera.filters = [new ShaderFilter(rainShader)]. Psych 0.6.3 Lua has no filter API,
-- so this file builds the same shader from assets/shaders/rain.frag and attaches the holding
-- sprite's shader instance to FlxG.camera through runHaxeCode.
--
-- 0.8.6 values (phillyStreets.hxc / phillyStreetsErect.hxc):
--   uScale     = FlxG.height / 200
--   uIntensity = FlxMath.remapToRange(songPosition, 0, music.length, start, end)
--   uRainColor = shader default #6680cc, Erect overrides it with #a8adb5
--   darnell: normal 0.0 -> 0.1, Erect/Nightmare 0.0 -> 0.01
--   onGameOver: FlxG.camera.filters = [] so the rain doesn't show over the game over screen

local TAG = 'limulRain104'
local SHADER = 'rain'

local START_INTENSITY = 0.0
local END_INTENSITY = 0.1

local RAIN_COLOR = {0.4, 0.501961, 0.8} -- 0xFF6680cc, RuntimeRainShader default
local ERECT_RAIN_COLOR = {0.658824, 0.678431, 0.709804} -- 0xFFa8adb5

local uScale = 3.6
local uTime = 1 -- RuntimeRainShader.time starts at 1
local shaderOn = false
local rainOff = false

local function camNum(path, fallback)
    local ok, value = pcall(getProperty, 'camGame.' .. path)
    if ok and type(value) == 'number' and value == value then
        return value
    end
    return fallback
end

local function pushRainBounds()
    -- RuntimeRainShader.updateViewInfo(FlxG.width, FlxG.height, FlxG.camera)
    setShaderFloatArray(TAG, 'uCameraBounds', {
        camNum('viewLeft', 0), camNum('viewTop', 0),
        camNum('viewRight', screenWidth), camNum('viewBottom', screenHeight)
    })
end

function onCreate()
    -- 0.8.6 always creates the shader; Psych gates it behind the shaders pref.
    if shadersEnabled == false or type(setSpriteShader) ~= 'function'
        or type(runHaxeCode) ~= 'function' then
        rainOff = true
        return
    end

    -- phillyStreetsErect.hxc uses much lighter intensities and a gray tint.
    local rainColor = RAIN_COLOR
    if difficultyPath == 'erect' or difficultyPath == 'nightmare' then
        START_INTENSITY, END_INTENSITY = 0.0, 0.01
        rainColor = ERECT_RAIN_COLOR
    end

    addHaxeLibrary('ShaderFilter', 'openfl.filters')
    uScale = screenHeight / 200

    -- The sprite only holds the shader instance; it is never drawn.
    makeLuaSprite(TAG, '', 0, 0)
    local okShader, hasShader = pcall(setSpriteShader, TAG, SHADER)
    if not (okShader and hasShader == true) then
        removeLuaSprite(TAG, true)
        rainOff = true
        return
    end

    setShaderFloat(TAG, 'uScale', uScale)
    setShaderFloat(TAG, 'uIntensity', START_INTENSITY)
    setShaderFloat(TAG, 'uTime', uTime)
    setShaderFloatArray(TAG, 'uRainColor', rainColor)
    pushRainBounds()

    -- phillyStreets.hxc: rainShaderFilter = new ShaderFilter(rainShader); FlxG.camera.filters = [rainShaderFilter];
    local okAttach, attached = pcall(runHaxeCode, [[
        var rainSprite:FlxSprite = game.getLuaObject('limulRain104');
        if (rainSprite == null || rainSprite.shader == null) return false;
        FlxG.camera.setFilters([new ShaderFilter(rainSprite.shader)]);
        FlxG.camera.filtersEnabled = true;
        return true;
    ]])
    shaderOn = (okAttach and attached == true)
    if not shaderOn then
        removeLuaSprite(TAG, true)
        rainOff = true
        debugPrint('Weekend 1 rain shader could not attach; see the Haxe error above.')
    end
end

function onGameOverStart()
    if rainOff or not shaderOn then return end
    -- phillyStreets.hxc: FlxG.camera.filters = [];
    pcall(runHaxeCode, 'FlxG.camera.filters = [];')
end

function onUpdate(elapsed)
    if rainOff or not shaderOn or inGameOver then return end

    -- phillyStreets.hxc: FlxMath.remapToRange(songPosition, 0, music.length, start, end)
    if type(songLength) == 'number' and songLength > 0 then
        setShaderFloat(TAG, 'uIntensity',
            START_INTENSITY + (END_INTENSITY - START_INTENSITY) * (getSongPosition() / songLength))
    else
        setShaderFloat(TAG, 'uIntensity', START_INTENSITY)
    end

    uTime = uTime + elapsed
    setShaderFloat(TAG, 'uTime', uTime)
    pushRainBounds()
end
