package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.utils.AssetType;

class NoteSplash extends FlxSprite
{
	/**
	 * LIMUL-SPLASH-CAP: splashes are the only hit effect that scales one-to-one with note density, and
	 * each one costs an animated atlas sprite (recycle + setup + its own update/kill cycle). This is a
	 * lazy token bucket: the configured per-second limit credits refill with
	 * wall time, so a burst spends what it has saved up and then drips at the cap instead.
	 * The clock is FlxG.game.ticks (ms since the app started), so no update() hook is needed and the
	 * budget survives pauses, substates and speedups.
	 */
	static var splashCredits:Float = 0;
	static var splashCreditClock:Int = 0;
	static var splashInitialized:Bool = false;

	public static function splashAllowed():Bool
	{
		var maxPerSecond:Int = ClientPrefs.maxNoteSplashesPerSecond;
		var now:Int = FlxG.game.ticks;
		if (maxPerSecond <= 0)
		{
			splashCreditClock = now;
			return true;
		}

		if (!splashInitialized)
		{
			splashCredits = maxPerSecond;
			splashCreditClock = now;
			splashInitialized = true;
		}

		var delta:Int = now - splashCreditClock;
		if (delta > 0)
		{
			splashCreditClock = now;
			splashCredits += delta * (maxPerSecond / 1000.0);
			if (splashCredits > maxPerSecond) splashCredits = maxPerSecond;
		}
		else if (delta < 0)
		{
			splashCreditClock = now; // clock went backwards, resync instead of freezing the bucket
		}
		if (splashCredits > maxPerSecond)
			splashCredits = maxPerSecond;

		if (splashCredits >= 1)
		{
			splashCredits -= 1;
			return true;
		}
		return false;
	}

	// Forever Engine parity: a per-song splashSkin still wins, then the global pref, then vanilla.
	// The pref is validated once per (mod, skin) pair so a deleted texture silently falls back
	// instead of crashing getSparrowAtlas() on every hit.
	static var lastCheckedSkinKey:String = null;
	static var lastCheckedSkinValid:Bool = false;

	public static function defaultSkin():String
	{
		if (PlayState.SONG != null && PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0)
			return PlayState.SONG.splashSkin;

		var pref:String = ClientPrefs.noteSplashSkin;
		if (pref != null && pref.length > 0 && pref != 'Default')
		{
			var cacheKey:String = Paths.currentModDirectory + '|' + pref;
			if (cacheKey == lastCheckedSkinKey) return lastCheckedSkinValid ? pref : 'noteSplashes';

			lastCheckedSkinKey = cacheKey;
			lastCheckedSkinValid = Paths.fileExists('images/' + pref + '.png', IMAGE);
			if (lastCheckedSkinValid) return pref;
		}
		return 'noteSplashes';
	}

	public var colorSwap:ColorSwap = null;
	private var idleAnim:String;
	private var textureLoaded:String = null;

	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0) {
		super(x, y);

		loadAnims(defaultSkin());
		
		colorSwap = new ColorSwap();
		updateColorSwapShader();

		setupNoteSplash(x, y, note);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	/**
	 * LIMUL-SPAM-OPT: same reasoning as Note.updateColorSwapShader() - a per-sprite shader forces its
	 * own GPU batch, and splashes are spawned on every good hit, so a neutral swap has to stay off.
	 */
	function updateColorSwapShader() {
		shader = (colorSwap != null && !colorSwap.isNeutral()) ? colorSwap.getShader() : null;
	}

	public function setupNoteSplash(x:Float, y:Float, note:Int = 0, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0) {
		setPosition(x - Note.swagWidth * 0.95, y - Note.swagWidth);
		alpha = ClientPrefs.noteSplashAlpha;

		if(texture == null || texture.length < 1) texture = defaultSkin();

		if(textureLoaded != texture) {
			loadAnims(texture);
		}
		colorSwap.hue = hueColor;
		colorSwap.saturation = satColor;
		colorSwap.brightness = brtColor;
		updateColorSwapShader();
		offset.set(10, 10);

		var animNum:Int = FlxG.random.int(1, 2);
		animation.play('note' + note + '-' + animNum, true);
		if(animation.curAnim != null)animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);
	}

	function loadAnims(skin:String) {
		frames = Paths.getSparrowAtlas(skin);
		for (i in 1...3) {
			animation.addByPrefix("note1-" + i, "note splash blue " + i, 24, false);
			animation.addByPrefix("note2-" + i, "note splash green " + i, 24, false);
			animation.addByPrefix("note0-" + i, "note splash purple " + i, 24, false);
			animation.addByPrefix("note3-" + i, "note splash red " + i, 24, false);
		}
	}

	override function update(elapsed:Float) {
		if(animation.curAnim != null)if(animation.curAnim.finished) kill();

		super.update(elapsed);
	}
}