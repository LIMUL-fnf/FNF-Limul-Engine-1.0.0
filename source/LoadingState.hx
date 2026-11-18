package;

import lime.app.Promise;
import lime.app.Future;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;

import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;

import haxe.io.Path;

class LoadingState extends MusicBeatState
{
	inline static var MIN_TIME = 1.0;

	// Browsers will load create(), you can make your song load a custom directory there
	// If you're compiling to desktop (or something that doesn't use NO_PRELOAD_ALL), search for getNextState instead
	// I'd recommend doing it on both actually lol
	
	// TO DO: Make this easier
	
	var target:FlxState;
	var stopMusic = false;
	var directory:String;
	var callbacks:MultiCallback;
	var targetShit:Float = 0;

	// LIMUL-LOAD-WARMUP: atlases decoded before the song starts, one per loading-screen frame.
	var warmQueue:Array<String> = [];
	var warmDone:Void->Void = null;
	var warmFired:Bool = false;

	function new(target:FlxState, stopMusic:Bool, directory:String)
	{
		super();
		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;
	}

	var funkay:FlxSprite;
	var loadBar:FlxSprite;
	var normalFunkayWidth:Int = -1;
	var showingAcceptedFunkay:Bool = false;
	override function create()
	{
		var bg:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d);
		add(bg);
		funkay = new FlxSprite(0, 0).loadGraphic(Paths.getPath('images/funkay.png', IMAGE));
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		normalFunkayWidth = Std.int(funkay.width);
		funkay.antialiasing = ClientPrefs.globalAntialiasing;
		add(funkay);
		funkay.scrollFactor.set();
		funkay.screenCenter();

		loadBar = new FlxSprite(0, FlxG.height - 20).makeGraphic(FlxG.width, 10, 0xffff16d2);
		loadBar.screenCenter(X);
		loadBar.antialiasing = ClientPrefs.globalAntialiasing;
		add(loadBar);
		
		initSongsManifest().onComplete
		(
			function (lib)
			{
				callbacks = new MultiCallback(onLoad);
				var introComplete = callbacks.add("introComplete");
				/*if (PlayState.SONG != null) {
					checkLoadSong(getSongPath());
					if (PlayState.SONG.needsVoices)
						checkLoadSong(getVocalPath());
				}*/
				checkLibrary("songs");
				checkLibrary("shared");
				if(directory != null && directory.length > 0 && directory != 'shared') {
					checkLibrary(directory);
				}
				buildWarmQueue();

				var fadeTime = 0.5;
				FlxG.camera.fade(FlxG.camera.bgColor, fadeTime, true);
				new FlxTimer().start(fadeTime + MIN_TIME, function(_) introComplete());
			}
		);
	}
	
	function checkLoadSong(path:String)
	{
		if (!Assets.cache.hasSound(path))
		{
			var library = Assets.getLibrary("songs");
			final symbolPath = path.split(":").pop();
			// @:privateAccess
			// library.types.set(symbolPath, SOUND);
			// @:privateAccess
			// library.pathGroups.set(symbolPath, [library.__cacheBreak(symbolPath)]);
			var callback = callbacks.add("song:" + path);
			Assets.loadSound(path).onComplete(function (_) { callback(); });
		}
	}
	
	function checkLibrary(library:String) {
		trace(Assets.hasLibrary(library));
		if (Assets.getLibrary(library) == null)
		{
			@:privateAccess
			if (!LimeAssets.libraryPaths.exists(library))
			{
				// was: throw "Missing library: " + library - a stage json pointing at a directory
				// this build does not ship killed the entire song load. Skip and keep playing.
				Paths.logAssetIssue('asset library "' + library + '" is missing from this build, skipped');
				trace('[Limul][assets] skipping missing library ' + library);
				return;
			}

			var callback = callbacks.add("library:" + library);
			Assets.loadLibrary(library).onComplete(function (_) { callback(); });
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (controls.ACCEPT && !showingAcceptedFunkay)
		{
			funkay.setGraphicSize(normalFunkayWidth + 60);
			funkay.updateHitbox();
			showingAcceptedFunkay = true;
		}

		if(callbacks != null) {
			targetShit = FlxMath.remapToRange(callbacks.numRemaining / callbacks.length, 1, 0, 0, 1);
			loadBar.scale.x += 0.5 * (targetShit - loadBar.scale.x);
		}

		drainWarmQueue();
	}

	/**
	 * The assets PlayState is about to build its cast out of, tagged with how to load them
	 * ("img:", "snd:", "mus:"). Listed in the order the song needs them: the opponent and the player
	 * carry the week's art, girlfriend only when the stage shows her, then the note skin the
	 * strumline is made of, the splash skin every good hit spawns and the baseline sounds every song
	 * fires. Nothing is guessed -- every key comes from the same field or list the loader reads.
	 */
	function buildWarmQueue()
	{
		if (PlayState.SONG == null || warmQueue.length > 0)
			return;

		var push = function(kind:String, key:Null<String>)
		{
			if (key == null || key.length < 1)
				return;
			var entry:String = kind + ':' + key;
			if (warmQueue.indexOf(entry) >= 0)
				return;
			warmQueue.push(entry);
		}

		push('img', Character.atlasKeyFromJson(PlayState.SONG.player2));
		push('img', Character.atlasKeyFromJson(PlayState.SONG.player1));

		// read dynamically: the StageFile typedef lives inside StageData.hx and the compiler has
		// not resolved it at this point (same reason resolveLevelDirectory does it this way)
		var stageFile:Dynamic = null;
		try
			stageFile = StageData.getStageFile(PlayState.SONG.stage)
		catch (e:Dynamic)
			stageFile = null; // an unknown stage falls back to philly, which still shows a girlfriend
		if (stageFile == null || stageFile.hide_girlfriend != true)
			push('img', Character.atlasKeyFromJson(PlayState.SONG.gfVersion));

		var arrowSkin:String = PlayState.SONG.arrowSkin;
		push('img', arrowSkin != null && arrowSkin.length > 0 ? arrowSkin : 'NOTE_assets');

		if (ClientPrefs.noteSplashes) push('img', NoteSplash.defaultSkin());

		var baseline = new Map<String, String>();
		PlayState.baselinePrecache(baseline);
		for (key => type in baseline)
			push(type == 'music' ? 'mus' : (type == 'sound' ? 'snd' : 'img'), key);

		// Only hold the switch back if there is actually work to do, otherwise a song with no
		// readable character json would wait on a callback nothing fires.
		if (warmQueue.length > 0)
			warmDone = callbacks.add('warmUpAtlases');
	}

	/**
	 * One asset per frame. It has to wait for every other callback: Paths caches by the resolved
	 * path, so touching a week image before that library exists would find the png on disk, cache it
	 * under the disk path, and leave PlayState to decode the same 100 MB sheet a second time under
	 * the library path.
	 */
	function drainWarmQueue()
	{
		if (warmFired || warmDone == null)
			return;
		if (callbacks == null || callbacks.numRemaining > 1)
			return;

		if (warmQueue.length > 0) {
			var entry:String = warmQueue.shift();
			var sep:Int = entry.indexOf(':');
			var kind:String = entry.substr(0, sep);
			var key:String = entry.substr(sep + 1);
			switch (kind) {
				case 'img': Paths.image(key);
				case 'snd': Paths.sound(key);
				case 'mus': Paths.music(key);
			}
		}

		if (warmQueue.length == 0) {
			warmFired = true;
			warmDone();
		}
	}
	
	function onLoad()
	{
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		MusicBeatState.switchState(target);
	}
	
	static function getSongPath()
	{
		return Paths.inst(PlayState.SONG.song);
	}
	
	static function getVocalPath()
	{
		return Paths.voices(PlayState.SONG.song);
	}
	
	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false)
	{
		MusicBeatState.switchState(getNextState(target, stopMusic));
	}
	
	static function getNextState(target:FlxState, stopMusic = false):FlxState
	{
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;
		var directory:String = resolveLevelDirectory(weekDir);

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);

		#if NO_PRELOAD_ALL
		var loaded:Bool = false;
		if (PlayState.SONG != null) {
			loaded = isSoundLoaded(getSongPath()) && (!PlayState.SONG.needsVoices || isSoundLoaded(getVocalPath())) && isLibraryLoaded("songs") && isLibraryLoaded("shared") && isLibraryLoaded(directory);
		}
		
		if (!loaded)
			return new LoadingState(target, stopMusic, directory);
		#end
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		
		return target;
	}

	/**
	 * Which asset library the next song belongs to. forceNextDirectory is written by
	 * StageData.loadDirectory(), but that only runs when a *chart* json is read - an events-only
	 * load, a menu that never parsed the chart or a stage file that got its directory later all
	 * leave it empty, which used to silently drop the level to 'shared' and make every week-only
	 * atlas invisible. A directory that has no library in the build manifest is refused here
	 * instead of throwing "Missing library" halfway through the loading screen.
	 */
	static function resolveLevelDirectory(weekDir:String):String
	{
		var dir:String = (weekDir != null && weekDir.length > 0) ? weekDir : null;

		if (dir == null && PlayState.SONG != null && PlayState.SONG.stage != null)
		{
			// the StageFile typedef lives inside StageData.hx, so typing it here is not enough for
			// the compiler to have resolved it yet - read the field dynamically instead
			var stageFile:Dynamic = StageData.getStageFile(PlayState.SONG.stage);
			if (stageFile != null)
			{
				var stageDir:String = cast stageFile.directory; // getStageFile always normalises it
				if (stageDir != null && stageDir.length > 0)
					dir = stageDir;
			}
		}

		if (dir == null || dir.length == 0 || dir == 'shared' || dir == 'preload')
			return 'shared';

		var known:Bool = false;
		try known = libraryIsDeclared(dir)
		catch (e:Dynamic) known = false;

		if (!known)
		{
			Paths.logAssetIssue('asset library "' + dir + '" is not part of this build, loading from shared instead');
			trace('[Limul][assets] no library named ' + dir + ', falling back to shared');
			return 'shared';
		}
		return dir;
	}

	/** Already loaded, or merely declared in the build manifest (so it can still be loaded). */
	static function libraryIsDeclared(name:String):Bool
	{
		if (Assets.getLibrary(name) != null || Assets.hasLibrary(name))
			return true;

		@:privateAccess
		var libraryPaths = LimeAssets.libraryPaths;
		return libraryPaths.exists(name);
	}
	
	#if NO_PRELOAD_ALL
	static function isSoundLoaded(path:String):Bool
	{
		return Assets.cache.hasSound(path);
	}
	
	static function isLibraryLoaded(library:String):Bool
	{
		return Assets.getLibrary(library) != null;
	}
	#end
	
	override function destroy()
	{
		super.destroy();
		
		callbacks = null;
	}
	
	static function initSongsManifest()
	{
		var id = "songs";
		var promise = new Promise<AssetLibrary>();

		var library = LimeAssets.getLibrary(id);

		if (library != null)
		{
			return Future.withValue(library);
		}

		var path = id;
		var rootPath = null;

		@:privateAccess
		var libraryPaths = LimeAssets.libraryPaths;
		if (libraryPaths.exists(id))
		{
			path = libraryPaths[id];
			rootPath = Path.directory(path);
		}
		else
		{
			if (StringTools.endsWith(path, ".bundle"))
			{
				rootPath = path;
				path += "/library.json";
			}
			else
			{
				rootPath = Path.directory(path);
			}
			@:privateAccess
			path = LimeAssets.__cacheBreak(path);
		}

		AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest)
		{
			if (manifest == null)
			{
				promise.error("Cannot parse asset manifest for library \"" + id + "\"");
				return;
			}

			var library = AssetLibrary.fromManifest(manifest);

			if (library == null)
			{
				promise.error("Cannot open library \"" + id + "\"");
			}
			else
			{
				@:privateAccess
				LimeAssets.libraries.set(id, library);
				library.onChange.add(LimeAssets.onChange.dispatch);
				promise.completeWith(Future.withValue(library));
			}
		}).onError(function(_)
		{
			promise.error("There is no asset library with an ID of \"" + id + "\"");
		});

		return promise.future;
	}
}

class MultiCallback
{
	public var callback:Void->Void;
	public var logId:String = null;
	public var length(default, null) = 0;
	public var numRemaining(default, null) = 0;
	
	var unfired = new Map<String, Void->Void>();
	var fired = new Array<String>();
	
	public function new (callback:Void->Void, logId:String = null)
	{
		this.callback = callback;
		this.logId = logId;
	}
	
	public function add(id = "untitled")
	{
		id = '$length:$id';
		length++;
		numRemaining++;
		var func:Void->Void = null;
		func = function ()
		{
			if (unfired.exists(id))
			{
				unfired.remove(id);
				fired.push(id);
				numRemaining--;
				
				if (logId != null)
					log('fired $id, $numRemaining remaining');
				
				if (numRemaining == 0)
				{
					if (logId != null)
						log('all callbacks fired');
					callback();
				}
			}
			else
				log('already fired $id');
		}
		unfired[id] = func;
		return func;
	}
	
	inline function log(msg):Void
	{
		if (logId != null)
			trace('$logId: $msg');
	}
	
	public function getFired() return fired.copy();
	public function getUnfired() return [for (id in unfired.keys()) id];
}
