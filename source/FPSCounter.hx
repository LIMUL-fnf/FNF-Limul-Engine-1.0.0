package;

import flixel.FlxG;
import flixel.util.FlxStringUtil;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * LIMUL-FPS-COUNTER: Psych 1.0.4's debug counter (FPS + GC memory) in place of openfl's bare FPS
 * field. Two differences matter: the text refresh is throttled to ~20 Hz instead of every frame,
 * and the memory line is the number that actually explains stutter on the C++ target.
 */
class FPSCounter extends TextField
{
	public var currentFPS(default, null):Int;

	/** GC memory in bytes (not total process RSS). */
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;
	// LIMUL-MEM-OPT: the 1 s window used to shift() one element off the front of the array on every
	// frame - an O(n) memmove per frame at 500-1000 fps. A read cursor skips the dead prefix and the
	// array is compacted only when that prefix grows past a small threshold.
	private var timesStart:Int = 0;
	var deltaTimeout:Float = 0.0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		var now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (timesStart < times.length && times[timesStart] < now - 1000)
			timesStart++;

		// Compact once the dead prefix is large enough that the extra array elements matter.
		if (timesStart > 256)
		{
			times = times.slice(timesStart);
			timesStart = 0;
		}

		if (deltaTimeout < 50)
		{
			deltaTimeout += deltaTime;
			return;
		}

		var frameCount:Int = times.length - timesStart;
		currentFPS = frameCount < FlxG.updateFramerate ? frameCount : FlxG.updateFramerate;
		updateText();
		deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void
	{
		text = 'FPS: ${currentFPS}';

		// Codename Engine parity: F3 expands the counter with state/song/conductor info.
		if (ClientPrefs.advancedFPS)
		{
			text += ' (draw ${FlxG.drawFramerate} / update ${FlxG.updateFramerate})';

			var stateName:String = FlxG.state != null ? Type.getClassName(Type.getClass(FlxG.state)) : 'none';
			text += '\nState: $stateName';

			if (PlayState.instance != null && FlxG.state == PlayState.instance && PlayState.SONG != null)
			{
				text += '\nSong: ${PlayState.SONG.song} [${CoolUtil.getDifficultyName(PlayState.storyDifficulty)}]';
				text += '\nBPM: ${Conductor.bpm} | Step: ${Std.int(Conductor.songPosition / Conductor.stepCrochet)}';
				text += '\nStage: ${PlayState.SONG.stage != null ? PlayState.SONG.stage : "?"}';
			}
		}

		text += '\nMemory: ${FlxStringUtil.formatBytes(memoryMegas)}';

		textColor = 0xFFFFFFFF;
		if (currentFPS < FlxG.drawFramerate * 0.5)
			textColor = 0xFFFF0000;
	}

	inline function get_memoryMegas():Float
	{
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#else
		return 0;
		#end
	}
}
