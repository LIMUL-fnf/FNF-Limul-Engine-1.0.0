package;

import animateatlas.AtlasFrameMaker;
#if flxanimate
import flxanimate.FlxAnimate;
import flxanimate.frames.FlxAnimateFrames;
#end
import flixel.math.FlxPoint;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import openfl.geom.Rectangle;
import flixel.math.FlxRect;
import haxe.xml.Access;
import openfl.system.System;
import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import lime.utils.Assets;
import flixel.FlxSprite;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import haxe.Json;

import flash.media.Sound;

using StringTools;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> = [
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'scripts',
		'achievements'
	];
	#end

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> =
	[
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/breakfast.$SOUND_EXT',
		'assets/shared/music/tea-time.$SOUND_EXT',
	];
	/// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory(?collectGarbage:Bool = true) {
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys()) {
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.exists(key)
				&& !dumpExclusions.contains(key)) {
				// get rid of it
				var obj = currentTrackedAssets.get(key);
				@:privateAccess
				if (obj != null && obj.useCount <= 0) {
					openfl.Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
					currentTrackedAssets.remove(key);
				}
			}
		}
		// LIMUL-FREEPLAY-SCALE: some of the graphics above had sparrow atlases memoized from them.
		pruneSparrowMemos();
		if (collectGarbage)
			System.gc();
	}

	// define the locally tracked assets
	// LIMUL-SPAM-OPT: this used to be an Array that every Paths.image()/Paths.sound() call pushed to
	// with no deduplication, so it grew by the thousands during one song (popUpScore alone asks for
	// six images per hit). clearUnusedMemory() then ran contains() over it once per tracked asset,
	// i.e. a quadratic string scan every 15 s from MusicBeatState.update - the periodic multi-hundred
	// millisecond stall on long spam charts. A Map keeps the same semantics at O(1).
	public static var localTrackedAssets:Map<String, Bool> = new Map();
	inline static function trackLocalAsset(key:String):Void localTrackedAssets.set(key, true);
	public static function clearStoredMemory(?cleanUnused:Bool = false, ?clearGraphics:Bool = true) {
		// clear anything not in the tracked assets list
		if (clearGraphics)
		{
			@:privateAccess
			for (key in FlxG.bitmap._cache.keys())
			{
				var obj = FlxG.bitmap._cache.get(key);
				if (obj != null && obj.useCount <= 0 && !currentTrackedAssets.exists(key)) {
					openfl.Assets.cache.removeBitmapData(key);
					FlxG.bitmap._cache.remove(key);
					obj.destroy();
				}
			}
		}

		// clear all sounds that are cached
		for (key in currentTrackedSounds.keys()) {
			if (!localTrackedAssets.exists(key)
			&& !dumpExclusions.contains(key) && key != null) {
				//trace('test: ' + dumpExclusions, key);
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = new Map();
		openfl.Assets.cache.clear("songs");
		pruneSparrowMemos();
	}

	static public var currentModDirectory:String = '';
	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(file, currentLevel);
				if (OpenFlAssets.exists(levelPath, type))
					return levelPath;
			}

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		var returnPath = '$library:assets/$library/$file';
		return returnPath;
	}

	inline public static function getPreloadPath(file:String = '')
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	inline static public function shaderFragment(key:String, ?library:String)
	{
		return getPath('shaders/$key.frag', TEXT, library);
	}
	inline static public function shaderVertex(key:String, ?library:String)
	{
		return getPath('shaders/$key.vert', TEXT, library);
	}
	inline static public function lua(key:String, ?library:String)
	{
		return getPath('$key.lua', TEXT, library);
	}

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	static public function sound(key:String, ?library:String):Sound
	{
		var sound:Sound = returnSound('sounds', key, library);
		return sound;
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String):Sound
	{
		var file:Sound = returnSound('music', key, library);
		return file;
	}

	inline static public function voices(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		var voices = returnSound('songs', perDifficultyAudioKey(songKey));
		return voices;
	}

	inline static public function inst(song:String):Any
	{
		var songKey:String = '${formatToSongPath(song)}/Inst';
		var inst = returnSound('songs', perDifficultyAudioKey(songKey));
		return inst;
	}

	/**
	 * Per-difficulty audio (the official Erect/Nightmare mixes reuse the song name but
	 * ship their own instrumental and vocals).
	 *
	 * The suffix is the very string the chart file name is built from
	 * (CoolUtil.getDifficultyFilePath -> "-erect", "" for the default difficulty), so a
	 * mod only has to drop `songs/<song>/Inst-erect.ogg` and
	 * `Voices-erect.ogg` next to the plain ones. When the suffixed file is missing the
	 * plain one is used, which keeps every non-Erect song (and every Story Mode
	 * difficulty) on the normal mix instead of crashing.
	 */
	static public function perDifficultyAudioKey(songKey:String):String
	{
		var suffix:String = difficultyAudioSuffix();
		if (suffix == null || suffix.length < 1)
			return songKey;

		var daKey:String = songKey + suffix;
		if (soundExists('songs', daKey))
			return daKey;
		return songKey;
	}

	/** Same '-<difficulty>' the charts use, or '' when there is nothing usable selected. */
	static public function difficultyAudioSuffix():String
	{
		var diffs = CoolUtil.difficulties;
		var num:Int = PlayState.storyDifficulty;
		if (diffs == null || num < 0 || num >= diffs.length)
			return '';

		var name:String = diffs[num];
		if (name == null || name == CoolUtil.defaultDifficulty)
			return '';
		return formatToSongPath('-' + name);
	}

	/** Mirror of returnSound()'s lookup order, so a true answer means the sound can load. */
	static public function soundExists(path:String, key:String):Bool
	{
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if (file != null && FileSystem.exists(file))
			return true;
		#end

		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		#if sys
		if (FileSystem.exists('./' + gottenPath))
			return true;
		#else
		if (OpenFlAssets.exists(getPath('$path/$key.$SOUND_EXT', SOUND)))
			return true;
		#end
		return false;
	}

	inline static public function image(key:String, ?library:String):FlxGraphic
	{
		// streamlined the assets process more
		var returnAsset:FlxGraphic = returnGraphic(key, library);
		return returnAsset;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		#if MODS_ALLOWED
		if (!ignoreMods && FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end

		if (FileSystem.exists(getPreloadPath(key)))
			return File.getContent(getPreloadPath(key));

		if (currentLevel != null)
		{
			var levelPath:String = '';
			if(currentLevel != 'shared') {
				levelPath = getLibraryPathForce(key, currentLevel);
				if (FileSystem.exists(levelPath))
					return File.getContent(levelPath);
			}

			levelPath = getLibraryPathForce(key, 'shared');
			if (FileSystem.exists(levelPath))
				return File.getContent(levelPath);
		}
		#end
		return Assets.getText(getPath(key, TEXT));
	}

	inline static public function font(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsFont(key);
		if(FileSystem.exists(file)) {
			return file;
		}
		#end
		return 'assets/fonts/$key';
	}

	inline static public function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?library:String)
	{
		#if MODS_ALLOWED
		if(FileSystem.exists(mods(currentModDirectory + '/' + key)) || FileSystem.exists(mods(key))) {
			return true;
		}
		#end

		if(OpenFlAssets.exists(getPath(key, type))) {
			return true;
		}

		#if sys
		// Assets dropped into bin/assets after the last lime build are absent from the packed
		// manifest, yet returnGraphic()/getTextFromFile() happily read them from disk. Without
		// the same disk probe here, callers that gate on fileExists() (freeplay pixel icons,
		// optional week art) silently fall back even though the file can be loaded.
		var diskPath:String = getPath(key, type);
		var colon:Int = diskPath.indexOf(':');
		if (colon >= 0) diskPath = diskPath.substring(colon + 1);
		if (FileSystem.exists(diskPath) || FileSystem.exists('./' + diskPath)) return true;
		#end
		return false;
	}

	// LIMUL-FREEPLAY-SCALE: getSparrowAtlas() is what an Alphabet letter costs, and a letter asks for
	// the atlas every single time it is built. The body below resolves the PNG (returnGraphic: up to
	// three FileSystem.exists() probes through modFolders()) and the XML (one or two more probes)
	// before handing anything to flixel -- flixel itself memoizes the PARSED frame collection
	// (FlxAtlasFrames.findFrame), so every one of those disk stats was spent to arrive at an answer
	// already given the call before. A 400-song Freeplay menu builds ~5000 letters, i.e. ~25000
	// stat() calls for one atlas, and the same wall exists for every other sparrow atlas in the game.
	//
	// The memo maps (key, library, mod directory) to the finished FlxAtlasFrames -- the directory is
	// part of it because modFolders() puts Paths.currentModDirectory in front of every mods path, and
	// Freeplay swaps that directory row by row, so a week folder shipping its own alphabet atlas has to
	// stay separate from the packed one. An entry is only ever trusted while the graphic it was built
	// from is still the one Psych would return: clearUnusedMemory() destroys an asset AND removes it
	// from currentTrackedAssets in the same step, so "still tracked under its own key, same instance"
	// is a complete validity test -- a disposed or replaced graphic misses and is rebuilt. Anything
	// that throws graphics away (clearStoredMemory, clearUnusedMemory) prunes it too, so the map can
	// never hand out frames whose parent is dead.
	static var sparrowMemos:Map<String, FlxAtlasFrames> = new Map();

	/** Drops memo entries whose source graphic is no longer tracked (destroyed by a memory sweep). */
	static function pruneSparrowMemos():Void
	{
		var dead:Array<String> = null;
		for (memoKey => memo in sparrowMemos)
		{
			var graphic:FlxGraphic = memo.parent;
			if (graphic == null || currentTrackedAssets.get(graphic.key) != graphic)
			{
				if (dead == null) dead = [];
				dead.push(memoKey);
			}
		}
		if (dead != null)
		{
			for (memoKey in dead)
				sparrowMemos.remove(memoKey);
		}
	}

	static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		var memoKey:String = key + '|' + (library == null ? '' : library) + '|' + currentModDirectory;
		var memo:FlxAtlasFrames = sparrowMemos.get(memoKey);
		if (memo != null)
		{
			var memoGraphic:FlxGraphic = memo.parent;
			if (memoGraphic != null && currentTrackedAssets.get(memoGraphic.key) == memoGraphic)
			{
				// LIMUL-ATLAS-MEMO-KEEP: a memo hit skips returnGraphic(), so without this line the
				// graphic never lands in localTrackedAssets. clearUnusedMemory() destroys every tracked
				// graphic that is not local -- it runs at the end of every PlayState.create() and every
				// 15 s of MusicBeatState.update -- so on the second PlayState in the process (restart,
				// next song) the characters' and stage's atlases were disposed while their sprites were
				// still drawing them: the restart null-object.
				localTrackedAssets.set(memoGraphic.key, true);
				return memo;
			}
			sparrowMemos.remove(memoKey);
		}

		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var xmlExists:Bool = false;
		if(FileSystem.exists(modsXml(key))) {
			xmlExists = true;
		}
		#if sys
		// FlxAtlasFrames.fromSparrow() answers null for either half, and the sprite then dies on a
		// null animation -- record which side is missing so a black/absent sprite is traceable.
		// (Only on the FIRST call for this key now -- a missing atlas used to append one line to
		// logs/asset-issues.log per letter, which is a file open/write per letter.)
		if (imageLoaded == null)
			logAssetIssue('atlas PNG missing for "' + key + '"');
		else if (!xmlExists)
		{
			// The manifest does not know atlases dropped into bin/assets after the lime build, but
			// the disk fallback below loads them anyway - only report a genuinely absent XML.
			var xmlProbe:String = getPath('images/$key.xml', TEXT, library);
			var probeColon:Int = xmlProbe.indexOf(':');
			if (probeColon >= 0) xmlProbe = xmlProbe.substring(probeColon + 1);
			if (!OpenFlAssets.exists(getPath('images/$key.xml', TEXT, library), TEXT) && !FileSystem.exists(xmlProbe))
				logAssetIssue('atlas XML missing for "' + key + '"');
		}
		#end

		// FlxXmlAsset treats a String as a path only when Assets.exists() knows it (i.e. it is in
		// the packed manifest). An atlas dropped into bin/assets after the lime build is not, and
		// the path string is then parsed as XML -> firstElement() null -> null object crash. Hand
		// the disk file's text over directly in that case.
		var xmlData:Dynamic = null;
		if (xmlExists)
			xmlData = File.getContent(modsXml(key));
		else {
			var xmlPath:String = getPath('images/$key.xml', TEXT, library);
			if (OpenFlAssets.exists(xmlPath, TEXT))
				xmlData = file('images/$key.xml', library);
			else {
				var diskXml:String = xmlPath;
				var colon:Int = diskXml.indexOf(':');
				if (colon >= 0) diskXml = diskXml.substring(colon + 1);
				if (FileSystem.exists(diskXml)) xmlData = File.getContent(diskXml);
				else xmlData = file('images/$key.xml', library);
			}
		}
		var frames:FlxAtlasFrames = FlxAtlasFrames.fromSparrow((imageLoaded != null ? imageLoaded : image(key, library)), xmlData);
		// A null graphic means the atlas is simply absent -- caching that would hide a PNG the player
		// drops in later, and fromSparrow() itself returning null means the XML never parsed.
		if (imageLoaded != null && frames != null)
			sparrowMemos.set(memoKey, frames);
		return frames;
		#else
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', library));
		#end
	}

	// Psych 1.0.4 characters may list several sparrow sheets in one "image" field
	// ("characters/Pico_Playable, characters/Pico_Intro, ..."). Every frame keeps its own parent
	// graphic, so one collection can feed animations taken from any of the sheets.
	static public function getMultiAtlas(keys:Array<String>, ?library:String):FlxAtlasFrames
	{
		var merged:FlxAtlasFrames = null;
		for (key in keys)
		{
			var clean:String = key.trim();
			if (clean.length < 1) continue;
			var part:FlxAtlasFrames = getSparrowAtlas(clean, library);
			if (part == null) continue;
			if (merged == null)
				merged = new FlxAtlasFrames(part.parent);
			// pushFrame, not addAtlas: addAtlas increments each graphic's use count, which would
			// pin the sheet against clearUnusedMemory() for the rest of the process.
			for (frame in part.frames)
				merged.pushFrame(frame, true);
		}
		return merged;
	}


	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		#if MODS_ALLOWED
		var imageLoaded:FlxGraphic = returnGraphic(key);
		var txtExists:Bool = false;
		if(FileSystem.exists(modsTxt(key))) {
			txtExists = true;
		}

		return FlxAtlasFrames.fromSpriteSheetPacker((imageLoaded != null ? imageLoaded : image(key, library)), (txtExists ? File.getContent(modsTxt(key)) : file('images/$key.txt', library)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
		#end
	}

	#if (flxanimate && sys)
	/**
	 * Lodaded straight from bin/assets instead of the embedded manifest: the module was exported
	 * with Animate 2020 and lives in three files (`Animation.json`, `spritemap*.json`, `spritemap*.png`),
	 * loader needs as text + a FlxGraphic, not as an asset-library entry.
	 */
	static function animateAtlasText(key:String):String
	{
		#if MODS_ALLOWED
		if (FileSystem.exists(modFolders(key)))
			return File.getContent(modFolders(key));
		#end
		var preload:String = getPreloadPath(key);
		if (FileSystem.exists(preload))
			return File.getContent(preload);
		return null;
	}

	static public function loadAnimateAtlas(spr:FlxAnimate, folder:String):Void
	{
		var spriteJson:String = null;
		var atlasImage:FlxGraphic = null;
		for (i in 0...10)
		{
			var st:String = (i == 0) ? '' : '$i';
			if (spriteJson == null)
				spriteJson = animateAtlasText('images/$folder/spritemap$st.json');
			if (spriteJson != null && FileSystem.exists(getPreloadPath('images/$folder/spritemap$st.png')))
			{
				atlasImage = image('$folder/spritemap$st');
				break;
			}
		}
		if (atlasImage == null)
			atlasImage = image(folder);

		var animJson:String = animateAtlasText('images/$folder/Animation.json');
		if (spriteJson == null || animJson == null || atlasImage == null)
			return;

		// BOM left by Animate exports breaks Json.parse
		var bom = String.fromCharCode(0xFEFF);
		var spriteMap:Dynamic = Json.parse(spriteJson.split(bom).join(""));
		var frames = new FlxAtlasFrames(atlasImage);
		for (sprite in (spriteMap.ATLAS.SPRITES:Array<Dynamic>))
		{
			var limb:Dynamic = sprite.SPRITE;
			var rect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
			if (limb.rotated)
				rect.setSize(rect.height, rect.width);
			FlxAnimateFrames.sliceFrame(limb.name, limb.rotated, rect, null, null, frames);
		}

		spr.loadSeparateAtlas(animJson.split(bom).join(""), frames);
	}
	#end

	inline static public function formatToSongPath(path:String) {
		var invalidChars = ~/[~&\\;:<>#]/;
		var hideChars = ~/[.,'"%?!]/;

		var path = invalidChars.split(path.replace(' ', '-')).join("-");
		return hideChars.split(path).join("").toLowerCase();
	}

	// completely rewritten asset loading? fuck!
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	#if sys
	/**
	 * Lime decodes PNG and OGG inside lime.ndll, and a missing or half-written file there is a
	 * native access violation (c0000005), not a Haxe error: the game just dies with no trace.
	 * Every such read now goes through a guard that records what happened in logs/asset-issues.log
	 * so the next crash is attributable instead of mysterious.
	 */
	#end
	public static var assetIssues(default, null):Array<String> = [];

	/** Also used from LoadingState, so a skipped asset library shows up in bin/logs too. */
	public static function logAssetIssue(msg:String):Void
	{
		assetIssues.push(msg);
		trace('[Limul][assets] ' + msg);
		#if sys
		try
		{
			if (!FileSystem.exists('logs'))
				FileSystem.createDirectory('logs');
			var f = File.write('logs/asset-issues.log', true);
			f.writeString(msg + '\n');
			f.close();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function returnGraphic(key:String, ?library:String) {
		#if MODS_ALLOWED
		var modKey:String = modsImages(key);
		if(FileSystem.exists(modKey)) {
			if(!currentTrackedAssets.exists(modKey)) {
				// BitmapData.fromFile is a native call: a broken PNG throws (or worse) instead of
				// returning null, and a 0-sized bitmap would blow up later while drawing frames.
				var newBitmap:BitmapData = null;
				try
					newBitmap = BitmapData.fromFile(modKey)
				catch (e:Dynamic)
					logAssetIssue('PNG decode threw for ' + modKey + ': ' + e);

				if (newBitmap == null || newBitmap.width < 1 || newBitmap.height < 1)
					logAssetIssue('PNG unusable (' + modKey + '), falling back to the packed assets');
				else {
					cacheGraphicOnGPU(newBitmap);
					var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(newBitmap, false, modKey);
					newGraphic.persist = true;
					currentTrackedAssets.set(modKey, newGraphic);
				}
			}
			if (currentTrackedAssets.exists(modKey)) {
				localTrackedAssets.set(modKey, true);
				return currentTrackedAssets.get(modKey);
			}
		}
		#end

		var path = getPath('images/$key.png', IMAGE, library);
		//trace(path);
		if (OpenFlAssets.exists(path, IMAGE)) {
			if(!currentTrackedAssets.exists(path)) {
				var newGraphic:FlxGraphic = FlxG.bitmap.add(path, false, path);
				// the manifest can list a png that is broken or was deleted from bin/assets:
				// FlxG.bitmap.add returns null there and dereferencing it used to crash the load
				if (newGraphic == null)
					logAssetIssue('packed image listed but not decodable (' + path + ')');
				else {
					cacheGraphicOnGPU(newGraphic.bitmap);
					newGraphic.persist = true;
					currentTrackedAssets.set(path, newGraphic);
				}
			}
			if (currentTrackedAssets.exists(path)) {
				localTrackedAssets.set(path, true);
				return currentTrackedAssets.get(path);
			}
		}
		#if sys
		// Anything dropped into bin/assets (or bin/mods/images) after the last lime build is not in
		// the manifest, so read the physical file too - this is what returnSound already does.
		var diskPath:String = path;
		var colon:Int = diskPath.indexOf(':');
		if (colon >= 0)
			diskPath = diskPath.substring(colon + 1);
		for (cand in [diskPath, './' + diskPath, 'mods/images/' + key + '.png'])
		{
			if (!FileSystem.exists(cand))
				continue;
			var bmp:BitmapData = null;
			try
				bmp = BitmapData.fromFile(cand)
			catch (e:Dynamic)
				logAssetIssue('PNG decode threw for ' + cand + ': ' + e);
			if (bmp == null || bmp.width < 1 || bmp.height < 1)
				continue;
			cacheGraphicOnGPU(bmp);
			var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bmp, false, cand);
			graphic.persist = true;
			currentTrackedAssets.set(cand, graphic);
			localTrackedAssets.set(cand, true);
			return graphic;
		}
		logAssetIssue('no image for key "' + key + '" (looked in mods/images and library '
			+ (library != null ? library : (currentLevel != null ? currentLevel : 'preload')) + ', id ' + path + ')');
		#else
		trace('oh no its returning null NOOOO: ' + key);
		#end
		return null;
	}

	// LIMUL-GPU-CACHE (JS Engine parity): "GPU Caching" uploads the pixels once and drops the CPU
	// copy, so textures live in VRAM only. Readback (getSurface) is forced first so anything that
	// still wants pixels (Lua image reads) keeps working instead of returning a blank bitmap.
	@:access(openfl.display.BitmapData)
	public static function cacheGraphicOnGPU(bitmap:BitmapData):Void
	{
		if (!ClientPrefs.cacheOnGPU || bitmap == null || bitmap.image == null)
			return;
		try
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}
		catch (e:Dynamic) {}
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];

	#if sys
	/**
	 * Sound.fromFile() on a path that does not exist (or on a truncated ogg) faults inside
	 * lime.ndll and takes the process with it, so every sound read goes through here: it checks
	 * the file first, catches decode failures, and falls back to a guaranteed-silent wav so the
	 * caller always gets a playable Sound instead of null.
	 */
	static var cachedSilentSound:Sound = null;

	/** Folder the exe lives in - the only path that stays correct even if the game is launched
	 *  from a shortcut whose working directory is somewhere else entirely. */
	static function executableDirectory():String
	{
		var exe:String = null;
		try exe = Sys.executablePath() catch (e:Dynamic) return null;
		if (exe == null) return null;
		exe = exe.replace('\\', '/');
		var idx:Int = exe.lastIndexOf('/');
		if (idx < 0) return null;
		return exe.substring(0, idx);
	}

	/** Every place the shipped 1-frame silence wav can be, relative and absolute. */
	static function silentSoundPaths():Array<String>
	{
		var list:Array<String> = ['assets/sounds/limul-silent.wav', 'mods/sounds/limul-silent.wav'];
		var dir:String = executableDirectory();
		if (dir != null)
		{
			list.push(dir + '/assets/sounds/limul-silent.wav');
			list.push(dir + '/mods/sounds/limul-silent.wav');
		}
		return list;
	}

	/** A Sound whose decode failed still exists as an object but carries no buffer (length 0). */
	static function soundUsable(snd:Sound):Bool
	{
		if (snd == null) return false;
		var len:Float = 0;
		try len = snd.length catch (e:Dynamic) return false;
		return len > 0;
	}

	/** Writes a minimal valid 16-bit mono PCM wav (8 silent samples) so silence always exists. */
	static function writeSilentWav(path:String):Bool
	{
		try
		{
			var sampleRate:Int = 22050;
			var dataLen:Int = 8 * 2; // 8 frames, mono, 16 bit
			var out = new haxe.io.BytesOutput();
			out.bigEndian = false;
			out.writeString('RIFF');
			out.writeInt32(36 + dataLen);
			out.writeString('WAVEfmt ');
			out.writeInt32(16);
			out.writeInt16(1); // PCM
			out.writeInt16(1); // channels
			out.writeInt32(sampleRate);
			out.writeInt32(sampleRate * 2); // byte rate
			out.writeInt16(2); // block align
			out.writeInt16(16); // bits per sample
			out.writeString('data');
			out.writeInt32(dataLen);
			for (i in 0...dataLen) out.writeByte(0);

			var dir:String = haxe.io.Path.directory(path);
			if (dir != null && dir != '' && dir != '.' && !FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			File.saveBytes(path, out.getBytes());
			return FileSystem.exists(path);
		}
		catch (e:Dynamic)
		{
			logAssetIssue('could not synthesise silence at ' + path + ': ' + e);
			return false;
		}
	}

	/**
	 * A writable scratch path for the synthesised wav. Sys.tempDirectory() does not exist in the
	 * Haxe version this project pins, so read the environment the way Windows actually exposes it.
	 */
	static function tempSilentWavPath():String
	{
		for (varName in ['TEMP', 'TMP', 'TMPDIR'])
		{
			var dir:String = null;
			try dir = Sys.getEnv(varName) catch (e:Dynamic) dir = null;
			if (dir != null && dir != '')
				return dir.replace('\\', '/') + '/limul-silent.wav';
		}
		return null;
	}

	/** Never returns null. Order: the wav off disk (relative AND exe-absolute) -> the packed
	 * asset library -> a wav written on the fly -> an empty Sound. The last one still cannot
	 * crash anything: openfl hands back a null channel from play() and flixel then simply
	 * deactivates the FlxSound, which is exactly silence.
	 */
	static function silentSound():Sound
	{
		if (cachedSilentSound != null)
			return cachedSilentSound;

		var snd:Sound = null;

		for (candidate in silentSoundPaths())
		{
			if (!FileSystem.exists(candidate)) continue;
			try snd = Sound.fromFile(candidate)
			catch (e:Dynamic) logAssetIssue('silent fallback threw on ' + candidate + ': ' + e);
			if (soundUsable(snd)) break;
			snd = null;
		}

		if (snd == null)
		{
			for (id in ['assets/sounds/limul-silent.wav', 'shared:assets/shared/sounds/limul-silent.wav'])
			{
				try
				{
					if (OpenFlAssets.exists(id, SOUND))
						snd = OpenFlAssets.getSound(id);
				}
				catch (e:Dynamic) snd = null;
				if (soundUsable(snd)) break;
				snd = null;
			}
		}

		if (snd == null)
		{
			var targets:Array<String> = [];
			var dir:String = executableDirectory();
			if (dir != null) targets.push(dir + '/mods/sounds/limul-silent.wav');
			var tmp:String = tempSilentWavPath();
			if (tmp != null) targets.push(tmp);

			for (t in targets)
			{
				if (!writeSilentWav(t)) continue;
				try snd = Sound.fromFile(t)
				catch (e:Dynamic) logAssetIssue('synthesised silence would not decode (' + t + '): ' + e);
				if (soundUsable(snd)) break;
				snd = null;
			}
		}

		if (snd == null)
		{
			logAssetIssue('no silence asset available, using an empty Sound instead of null');
			try snd = new Sound() catch (e:Dynamic) snd = null;
		}

		// only cache a real buffer, so the empty-Sound case retries the disk next time
		if (soundUsable(snd))
			cachedSilentSound = snd;
		return snd;
	}

	static function loadSoundSafe(file:String, id:String):Sound
	{
		if (!FileSystem.exists(file))
		{
			logAssetIssue('missing sound "' + id + '" (' + file + ')');
			return silentSound();
		}
		var s:Sound = null;
		try
			s = Sound.fromFile(file)
		catch (e:Dynamic)
			logAssetIssue('decode threw for ' + file + ': ' + e);
		if (!soundUsable(s))
		{
			logAssetIssue('unreadable sound ' + file + ', using silence');
			return silentSound();
		}
		return s;
	}
	#end

	public static function returnSound(path:String, key:String, ?library:String) {
		#if MODS_ALLOWED
		var file:String = modsSounds(path, key);
		if(FileSystem.exists(file)) {
			if(!currentTrackedSounds.exists(file)) {
				#if sys
				currentTrackedSounds.set(file, loadSoundSafe(file, key));
				#else
				currentTrackedSounds.set(file, Sound.fromFile(file));
				#end
			}
			localTrackedAssets.set(key, true);
			return currentTrackedSounds.get(file);
		}
		#end
		// I hate this so god damn much
		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library);
		gottenPath = gottenPath.substring(gottenPath.indexOf(':') + 1, gottenPath.length);
		// trace(gottenPath);
		if(!currentTrackedSounds.exists(gottenPath))
		#if sys
		{
			var realFile:String = './' + gottenPath;
			if (FileSystem.exists(realFile))
				currentTrackedSounds.set(gottenPath, loadSoundSafe(realFile, gottenPath));
			else if (OpenFlAssets.exists(gottenPath, SOUND))
			{
				var packed:Sound = null;
				try packed = OpenFlAssets.getSound(gottenPath) catch (e:Dynamic) packed = null;
				// the manifest can list a sound whose file was replaced/removed on disk: getSound
				// returns null there, and caching that null is what crashed the song start
				currentTrackedSounds.set(gottenPath, packed != null ? packed : silentSound());
			}
			else
			{
				logAssetIssue('missing sound "' + key + '" (' + gottenPath + ')');
				currentTrackedSounds.set(gottenPath, silentSound());
			}
		}
		#elseif MODS_ALLOWED
			currentTrackedSounds.set(gottenPath, Sound.fromFile('./' + gottenPath));
		#else
		{
			var folder:String = '';
			if(path == 'songs') folder = 'songs:';

			currentTrackedSounds.set(gottenPath, OpenFlAssets.getSound(folder + getPath('$path/$key.$SOUND_EXT', SOUND, library)));
		}
		#end
		localTrackedAssets.set(gottenPath, true);
		var result:Sound = currentTrackedSounds.get(gottenPath);
		#if sys
		// nothing downstream has to null-check again: a missing voice/instrument is silence, not
		// a Null Object Reference inside FlxG.sound.play()
		if (result == null)
			result = silentSound();
		#end
		return result;
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '') {
		return 'mods/' + key;
	}

	inline static public function modsFont(key:String) {
		return modFolders('fonts/' + key);
	}

	inline static public function modsJson(key:String) {
		return modFolders('data/' + key + '.json');
	}

	inline static public function modsVideo(key:String) {
		return modFolders('videos/' + key + '.' + VIDEO_EXT);
	}

	inline static public function modsSounds(path:String, key:String) {
		return modFolders(path + '/' + key + '.' + SOUND_EXT);
	}

	inline static public function modsImages(key:String) {
		return modFolders('images/' + key + '.png');
	}

	inline static public function modsXml(key:String) {
		return modFolders('images/' + key + '.xml');
	}

	inline static public function modsTxt(key:String) {
		return modFolders('images/' + key + '.txt');
	}

	/* Goes unused for now

	inline static public function modsShaderFragment(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.frag');
	}
	inline static public function modsShaderVertex(key:String, ?library:String)
	{
		return modFolders('shaders/'+key+'.vert');
	}
	inline static public function modsAchievements(key:String) {
		return modFolders('achievements/' + key + '.json');
	}*/

	static public function modFolders(key:String) {
		if(currentModDirectory != null && currentModDirectory.length > 0) {
			var fileToCheck:String = mods(currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		for(mod in getGlobalMods()){
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;

		}
		return 'mods/' + key;
	}

	public static var globalMods:Array<String> = [];

	static public function getGlobalMods()
		return globalMods;

	static public function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		var path:String = 'modsList.txt';
		if(FileSystem.exists(path))
		{
			var list:Array<String> = CoolUtil.coolTextFile(path);
			for (i in list)
			{
				var dat = i.split("|");
				if (dat[1] == "1")
				{
					var folder = dat[0];
					var path = Paths.mods(folder + '/pack.json');
					if(FileSystem.exists(path)) {
						try{
							var rawJson:String = File.getContent(path);
							if(rawJson != null && rawJson.length > 0) {
								var stuff:Dynamic = Json.parse(rawJson);
								var global:Bool = Reflect.getProperty(stuff, "runsGlobally");
								if(global)globalMods.push(dat[0]);
							}
						} catch(e:Dynamic){
							trace(e);
						}
					}
				}
			}
		}
		return globalMods;
	}

	static public function getModDirectories():Array<String> {
		var list:Array<String> = [];
		var modsFolder:String = mods();
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				var path = haxe.io.Path.join([modsFolder, folder]);
				if (sys.FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder) && !list.contains(folder)) {
					list.push(folder);
				}
			}
		}
		return list;
	}
	#end
}
