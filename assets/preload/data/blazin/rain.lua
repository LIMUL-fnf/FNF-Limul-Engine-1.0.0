-- Limul Engine - blazin rain, ported 1:1 from Funkin' 0.8.6 (V-Slice).
--
-- 0.8.6 keeps Weekend 1 in HScript: assets/scripts/stages/phillyBlazin.hxc creates
-- RuntimeRainShader (graphics/shaders/RuntimeRainShader.hx, assets/shaders/rain.frag) and
-- attaches it to the game camera with FlxG.camera.filters = [new ShaderFilter(rainShader)].
-- Psych 0.6.3 Lua has no filter API, so this file builds the same shader from
-- assets/shaders/rain.frag and attaches the holding sprite's shader instance to FlxG.camera
-- through runHaxeCode.
--
-- 0.8.6 values (phillyBlazin.hxc):
--   uScale       = FlxG.height / 200
--   uIntensity   = 0.5 (fixed, no song-length remap)
--   uRainColor   = shader default #6680cc
--   rainTimeScale starts at 1 and gets +0.7 on EVERY note hit (both sides), then decays towards
--   0.02 with MathUtil.smoothLerpPrecision(rainTimeScale, 0.02, elapsed, 1.535)
--   onGameOver: FlxG.camera.filters = [] so the rain doesn't show over the game over screen
--   (a retry re-creates PlayState, so onCreate attaches the shader again)

local TAG = 'limulRain104'
local SHADER = 'rain'

local INTENSITY = 0.5
local RAIN_COLOR = {0.4, 0.501961, 0.8} -- 0xFF6680cc, RuntimeRainShader default

local uScale = 3.6
local uTime = 1 -- RuntimeRainShader.time starts at 1
local rainTimeScale = 1.0 -- phillyBlazin.hxc: rainTimeScale:Float = 1.0
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

local function smoothLerpPrecision(base, target, elapsed, duration)
    -- MathUtil.smoothLerpPrecision: lerp(target, base, pow(0.01, elapsed / duration))
    if elapsed == 0 or base == target then return base end
    return target + (base - target) * (0.01 ^ (elapsed / duration))
end

function onCreate()
    -- 0.8.6 always creates the shader; Psych gates it behind the shaders pref.
    if shadersEnabled == false or type(setSpriteShader) ~= 'function'
        or type(runHaxeCode) ~= 'function' then
        rainOff = true
        return
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
    setShaderFloat(TAG, 'uIntensity', INTENSITY)
    setShaderFloat(TAG, 'uTime', uTime)
    setShaderFloatArray(TAG, 'uRainColor', RAIN_COLOR)
    pushRainBounds()

    -- phillyBlazin.hxc: rainShaderFilter = new ShaderFilter(rainShader); FlxG.camera.filters = [rainShaderFilter];
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

local function rainSurge()
    if rainOff then return end
    -- phillyBlazin.hxc onNoteHit: rainTimeScale += 0.7 (both sides, not just the player's)
    rainTimeScale = rainTimeScale + 0.7
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    rainSurge()
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    rainSurge()
end

function onGameOverStart()
    if rainOff or not shaderOn then return end
    -- phillyBlazin.hxc: FlxG.camera.filters = [];
    pcall(runHaxeCode, 'FlxG.camera.filters = [];')
end

function onUpdate(elapsed)
    if rainOff or not shaderOn or inGameOver then return end

    -- phillyBlazin.hxc: update(event.elapsed * rainTimeScale), then decay towards 0.02
    uTime = uTime + elapsed * rainTimeScale
    rainTimeScale = smoothLerpPrecision(rainTimeScale, 0.02, elapsed, 1.535)
    setShaderFloat(TAG, 'uTime', uTime)
    pushRainBounds()
end
