package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
#if desktop
import openfl.events.KeyboardEvent;
#end
#if cpp
import cpp.vm.Gc;
#end

// LIMUL-CRASH-HANDLER: Project.xml compiles CRASH_HANDLER / HXCPP_CHECK_POINTER / HXCPP_STACK_LINE
// for desktop release, but the handler itself was dropped at some point - a null deref only showed
// the bare hxcpp dialog and left nothing on disk. This is the 1.0.4 handler, so the next crash
// writes bin/crash/LimulEngine_<date>.txt with the Haxe call stack (file + line).
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import lime.app.Application;
import sys.io.File;
import sys.FileSystem;
#end

class Main extends Sprite
{
	var gameWidth:Int = 1280;
	var gameHeight:Int = 720;
	var initialState:Class<FlxState> = TitleState;
	var zoom:Float = -1;
	var framerate:Int = 60;
	var skipSplash:Bool = true;
	var startFullscreen:Bool = false;

	public static var fpsVar:FPSCounter; // Dodane pole dla ClientPrefs i ustawień wizualnych
	private static var f3Held:Bool = false;

	// LIMUL-MEMORY-CLEANER: the sweep runs every this many milliseconds, and only outside gameplay
	// (see isGameplayState). lastMemoryClean stays untouched while a song plays, so the frame that
	// lands back in Freeplay is already past the interval and reclaims the song's garbage at once.
	private static final MEMORY_CLEAN_INTERVAL:Int = 1000;
	// LIMUL-FREEPLAY-SCALE: how many 1-second sweeps may pass before the collector is forced back to a
	// whole-heap (major) walk. See onEnterFrame.
	private static final MAJOR_CLEAN_EVERY:Int = 8;
	private var lastMemoryClean:Int = 0;
	private var sweepsSinceMajor:Int = 0;
	private var leftGameplay:Bool = false;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();
		if (stage != null) init();
		else addEventListener(Event.ADDED_TO_STAGE, init);
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE)) removeEventListener(Event.ADDED_TO_STAGE, init);
		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Std.int(stageWidth / zoom);
			gameHeight = Std.int(stageHeight / zoom);
		}

		addChild(new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen));

		#if desktop
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent) {
			if (e.keyCode == 122) FlxG.fullscreen = !FlxG.fullscreen;
			else if (e.keyCode == 114 && !f3Held) {
				f3Held = true;
				// Codename parity: F3 cycles basic -> advanced -> hidden, instead of only
				// flipping the extra info on the counter.
				if (!ClientPrefs.showFPS) {
					ClientPrefs.showFPS = true;
					ClientPrefs.advancedFPS = false;
				} else if (!ClientPrefs.advancedFPS) {
					ClientPrefs.advancedFPS = true;
				} else {
					ClientPrefs.advancedFPS = false;
					ClientPrefs.showFPS = false;
				}
				if (fpsVar != null) fpsVar.visible = ClientPrefs.showFPS;
				ClientPrefs.saveSettings();
			}
		});
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, function(e:KeyboardEvent) {
			if (e.keyCode == 114) f3Held = false;
		});
		#end
		
		fpsVar = new FPSCounter(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		addEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	private function onEnterFrame(event:Event):Void
	{
		// LIMUL-MEMORY-CLEANER: gameplay is skipped outright - see isGameplayState().
		if (isGameplayState(FlxG.state))
		{
			leftGameplay = true;
			return;
		}

		var now:Int = Lib.getTimer();
		if (now - lastMemoryClean < MEMORY_CLEAN_INTERVAL) return;
		lastMemoryClean = now;

		// LIMUL-FREEPLAY-SCALE: the sweep that lands straight after a song is the one that has to
		// actually reclaim it, so it stays a major. Once the menu is idle, a major every second is a
		// whole-heap walk on top of a menu that is already holding tens of thousands of objects (a
		// 400-song Freeplay is ~5500 letter sprites plus their animation controllers), and it shows up
		// as a 1 Hz stutter while the rows are lerping. Minor collections are cheap and hxcpp still
		// schedules its own majors when the heap asks for them, so the idle sweep downgrades to minor
		// and the major happens every MAJOR_CLEAN_EVERY seconds at most.
		sweepsSinceMajor++;
		var major:Bool = leftGameplay || (sweepsSinceMajor >= MAJOR_CLEAN_EVERY);
		if (major) sweepsSinceMajor = 0;
		if (leftGameplay)
		{
			// LIMUL-MEM-OPT: the finished song's images and sounds are still flagged as local, so
			// the Paths sweep inside cleanMemory() would skip them and the song's textures would
			// sit in RAM until one of the menu states resets the flags. No PlayState is alive any
			// more, so drop the flags once here; menu sprites that are already drawing keep their
			// graphics through their use counts.
			Paths.clearStoredMemory(false, false);
		}
		leftGameplay = false;
		cleanMemory(major);
	}

	/**
	 * Is this state a song actually playing? PlayState covers story mode and the freeplay->song->
	 * game-over loop (GameOverSubState and PauseSubState sit on top of it, so FlxG.state is still a
	 * PlayState while they are open), and EditorPlayState is the chart editor's playtest.
	 * Everything else - title, both menus, options, the editors themselves, LoadingState - is fair
	 * game for the sweep.
	 */
	private static function isGameplayState(state:FlxState):Bool
	{
		return Std.instance(state, PlayState) != null
			|| Std.instance(state, editors.EditorPlayState) != null;
	}

	/**
	 * Drops cached graphics nothing references any more (the previous song's atlases survive a soft
	 * restart otherwise) and then asks hxcpp for a collection, so freed memory actually leaves the
	 * process instead of sitting in its free lists - the on-screen counter reads System.totalMemory.
	 * FlxG.bitmap.clearUnused() only removes entries with zero uses that are not marked persist, so a
	 * live stage never loses a sprite it is still drawing.
	 *
	 * LIMUL-SPAM-OPT: this used to run during gameplay too, as a minor-only half so a major walk of
	 * every live object would not cost 150-250 ms of CPU once a second on a spam chart. It is now off
	 * for the whole of a song instead: hxcpp still collects on its own when the heap grows past its
	 * thresholds, and a sweep that can evict an atlas the next frame needs is not something a song
	 * should be paying for. The garbage from the song goes the moment the menu is back.
	 *
	 * LIMUL-FREEPLAY-SCALE: `major` picks how hard the collector works (see onEnterFrame). The asset
	 * cache sweep is the same either way - that is the part that actually returns textures.
	 */
	public static function cleanMemory(?major:Bool = true):Void
	{
		FlxG.bitmap.clearUnused();
		// LIMUL-MEM-OPT: clearUnused() skips every graphic with persist set, and Paths marks all of
		// its images persist so they survive a soft restart. The previous song's atlases were
		// therefore only reclaimed by MusicBeatState's 15 s sweep - up to fifteen seconds of the
		// song's texture memory sitting around after coming back. The Paths sweep runs here too,
		// so leaving a song frees its textures within a second; anything the current menu is
		// drawing is in localTrackedAssets or still holds a use count, so it stays.
		Paths.clearUnusedMemory(false);
		#if cpp
		Gc.run(major);
		#end
	}

	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = StringTools.replace(dateNow, " ", "_");
		dateNow = StringTools.replace(dateNow, ":", "'");

		// macOS/Linux launchers may start the game with an arbitrary (or read-only) working
		// directory, so prefer a crash folder next to the executable and only then fall back
		// to ./crash/. The search is best-effort: the handler itself must never throw.
		var exeDir:String = null;
		try exeDir = Path.directory(Sys.programPath()) catch (e:Dynamic) {}
		var crashDirs:Array<String> = [];
		if (exeDir != null && exeDir.length > 0) crashDirs.push(exeDir + "/crash/");
		crashDirs.push("./crash/");

		var crashDir:String = crashDirs[crashDirs.length - 1];
		for (dir in crashDirs)
		{
			try
			{
				if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
				crashDir = dir;
				break;
			}
			catch (e:Dynamic) {}
		}

		var path:String = crashDir + "LimulEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;
		errMsg += "\n\n> Crash Handler written by: sqirra-rng";

		try File.saveContent(path, errMsg + "\n") catch (e:Dynamic) trace('Could not write crash dump: ' + e);

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		Sys.exit(1);
	}
	#end
}
