package;

import flixel.FlxG;
import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
#if sys
import sys.io.File;
import sys.FileSystem;
#else
import openfl.utils.Assets;
#end

using StringTools;

class CoolUtil
{
	public static var defaultDifficulties:Array<String> = [
		'Easy',
		'Normal',
		'Hard'
	];
	public static var defaultDifficulty:String = 'Normal'; //The chart that has no suffix and starting difficulty on Freeplay/Story Mode

	public static var difficulties:Array<String> = [];

	inline public static function quantize(f:Float, snap:Float){
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		trace(snap);
		return (m / snap);
	}

	/**
	 * Limul Engine: Psych 1.0.4's CoolUtil.colorFromString, ported verbatim.
	 *
	 * The Lua side of this 0.6.3 fork turns every colour string with
	 * Std.parseInt('0xff' + hex). On Windows hxcpp that is a 32-bit strtol call, and any
	 * 0xFFRRGGBB value is above LONG_MAX, so it comes back clamped to 0x7FFFFFFF: alpha 0x7F
	 * with white underneath. FlxTween.color's ColorTween writes sprite.alpha = color.alphaFloat
	 * every frame, so every doTweenColor faded its target to about half transparent instead of
	 * tweening a colour - that is the washed-out characters after Spookezone Erect's lightning.
	 *
	 * Parsing through FlxColor.fromString('#RRGGBB') never builds a string long enough to
	 * overflow, and flixel forces alphaFloat to 1 for a 6-digit hex. The leading '0x' branch
	 * keeps an '0xAARRGGBB' string working the way 1.0.4 reads it: keep the RGB, drop the
	 * caller's alpha byte.
	 */
	inline public static function colorFromString(color:String):FlxColor
	{
		var hideChars = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join('').trim();
		if (color.startsWith('0x'))
			color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if (colorNum == null)
			colorNum = FlxColor.fromString('#$color');
		return colorNum != null ? colorNum : FlxColor.WHITE;
	}
	
	public static function getDifficultyFilePath(num:Null<Int> = null)
	{
		if(num == null) num = PlayState.storyDifficulty;

		var fileSuffix:String = difficulties[num];
		if(fileSuffix != defaultDifficulty)
		{
			fileSuffix = '-' + fileSuffix;
		}
		else
		{
			fileSuffix = '';
		}
		return Paths.formatToSongPath(fileSuffix);
	}

	/**
	 * LIMUL-104-DIFF-NAME: null-safe difficulty label for anything the player reads.
	 *
	 * Psych 1.0.4 resolves the difficulty through Difficulty.getString(index, useDefault)
	 * (source/utils/.../Difficulty.hx), which falls back to the default difficulty when the index
	 * is past the end of the list. 0.6.3 indexes CoolUtil.difficulties raw, and in this fork that
	 * array is rebuilt per song (StoryMenuState drops the freeplayOnlyDifficulties, FreeplayState
	 * drops the extra difficulties whose chart file is missing), so an index that was valid on the
	 * previous song can dangle one slot over the edge. Raw indexing gave null -> an empty
	 * "song |  | L.E 1.0.0" strip during gameplay (PlayState.hx:1171-1174) and a null.toUpperCase()
	 * in the pause menu. Chart resolution is deliberately NOT routed through here:
	 * getDifficultyFilePath() keeps its raw indexing so a bad index still fails loudly on the chart
	 * load instead of silently playing the wrong difficulty.
	 */
	public static function getDifficultyName(num:Null<Int> = null):String
	{
		var index:Int = (num != null) ? num : PlayState.storyDifficulty;

		if (index >= 0 && index < difficulties.length)
		{
			var name:String = difficulties[index];
			if (name != null && name.length > 0) return name;
		}
		if (difficulties.contains(defaultDifficulty)) return defaultDifficulty;
		if (difficulties.length > 0 && difficulties[0] != null && difficulties[0].length > 0) return difficulties[0];
		return defaultDifficulty;
	}

	public static function difficultyString():String
	{
		return getDifficultyName(PlayState.storyDifficulty).toUpperCase();
	}

	public static function getHealthColors(char:Character):Array<Int>
	{
		if (char != null)
			return char.healthColorArray;
		return [255, 0, 0];
	}

	public static function getSongDuration(musicTime:Float, musicLength:Float, precision:Int = 0):String
	{
		var secondsMax:Int = Math.floor((musicLength - musicTime) / 1000);
		var secs:String = '' + Math.floor(secondsMax) % 60;
		var mins:String = '' + Math.floor(secondsMax / 60) % 60;
		var hour:String = '' + Math.floor(secondsMax / 3600) % 24;

		if (secs.length < 2)
			secs = '0' + secs;

		var shit:String = mins + ':' + secs;
		if (hour != '0')
			shit = hour + ':' + mins + ':' + secs;
		return shit;
	}

	public static function formatTime(musicTime:Float, precision:Int = 0):String
	{
		var secs:String = '' + Math.floor(musicTime / 1000) % 60;
		var mins:String = '' + Math.floor(musicTime / 1000 / 60) % 60;
		var hour:String = '' + Math.floor((musicTime / 1000 / 3600)) % 24;
		var days:String = '' + Math.floor((musicTime / 1000 / 86400)) % 7;
		var weeks:String = '' + Math.floor((musicTime / 1000 / (86400 * 7)));

		if (secs.length < 2 && Math.floor((musicTime / 1000 / 86400)) == 0)
			secs = '0' + secs;

		var shit:String = mins + ':' + secs;
		if (Math.floor((musicTime / 1000 / 3600)) != 0 && Math.floor((musicTime / 1000 / 86400)) == 0)
			shit = hour + ':' + mins + ':' + secs;
		else if (Math.floor((musicTime / 1000 / 86400)) != 0)
		{
			shit = (days.length < 2 ? '0' + days : days) + ':' + (hour.length < 2 ? '0' + hour : hour) + ':' + (mins.length < 2 ? '0' + mins : mins)
				+ ':' + secs;
			if (Math.floor((musicTime / 1000 / (86400 * 7))) != 0)
				shit = weeks + 'w, ' + shit;
		}
		return shit;
	}

	inline public static function boundTo(value:Float, min:Float, max:Float):Float {
		return Math.max(min, Math.min(max, value));
	}

	public static function coolTextFile(path:String):Array<String>
	{
		var daList:Array<String> = [];
		#if sys
		if(FileSystem.exists(path)) daList = File.getContent(path).trim().split('\n');
		#else
		if(Assets.exists(path)) daList = Assets.getText(path).trim().split('\n');
		#end

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}
	public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [];
		daList = string.trim().split('\n');

		for (i in 0...daList.length)
		{
			daList[i] = daList[i].trim();
		}

		return daList;
	}
	public static function dominantColor(sprite:flixel.FlxSprite):Int{
		var countByColor:Map<Int, Int> = [];
		for(col in 0...sprite.frameWidth){
			for(row in 0...sprite.frameHeight){
			  var colorOfThisPixel:Int = sprite.pixels.getPixel32(col, row);
			  if(colorOfThisPixel != 0){
				  if(countByColor.exists(colorOfThisPixel)){
				    countByColor[colorOfThisPixel] =  countByColor[colorOfThisPixel] + 1;
				  }else if(countByColor[colorOfThisPixel] != 13520687 - (2*13520687)){
					 countByColor[colorOfThisPixel] = 1;
				  }
			  }
			}
		 }
		var maxCount = 0;
		var maxKey:Int = 0;//after the loop this will store the max color
		countByColor[flixel.util.FlxColor.BLACK] = 0;
			for(key in countByColor.keys()){
			if(countByColor[key] >= maxCount){
				maxCount = countByColor[key];
				maxKey = key;
			}
		}
		return maxKey;
	}

	public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max)
		{
			dumbArray.push(i);
		}
		return dumbArray;
	}

	//uhhhh does this even work at all? i'm starting to doubt
	public static function precacheSound(sound:String, ?library:String = null):Void {
		Paths.sound(sound, library);
	}

	public static function precacheMusic(sound:String, ?library:String = null):Void {
		Paths.music(sound, library);
	}

	public static function browserLoad(site:String) {
		#if linux
		// Some distributions (and sandboxed installs) have no xdg-open on PATH; fall back to
		// Lime's opener instead of failing silently on the credits/menu links.
		var opened:Bool = false;
		try
		{
			opened = (Sys.command('xdg-open', [site]) == 0);
		}
		catch (e:Dynamic)
		{
			opened = false;
		}
		if (!opened) FlxG.openURL(site);
		#else
		FlxG.openURL(site);
		#end
	}
}
