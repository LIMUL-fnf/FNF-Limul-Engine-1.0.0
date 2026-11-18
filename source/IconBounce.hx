package;

import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;

// Health-icon bounce styles, one implementation shared by PlayState and the Visuals preview.
// Only motions that actually look different are listed here. Styles that were the same motion
// with another amplitude, another recovery speed or another engine name fold into the closest
// survivor via normalize(), so the selector has no two entries that bounce alike.
class IconBounce
{
	public static var STYLES:Array<String> = [
		'Psych Engine',
		'Golden Apple',
		'Universe Engine',
		'JS Dave and Bambi',
		'JS Plank Engine',
		'Solar Engine',
		'V-Slice Horizontal',
		'V-Slice Vertical',
		'V-Slice Drill',
		'Elastic',
		'Tall Stretch'
	];

	// Old/removed style names that a save or the old style list may still hold.
	public static function normalize(name:String):String
	{
		if (name == null) return 'Psych Engine';
		return switch (name)
		{
			case 'Psych Engine (Original)' | 'Off' | 'Psych 1.0.4' | 'Old Psych' | 'Codename Engine'
				| 'Leather Engine' | 'Maru Funkin' | 'V-Slice Default' | 'Bouncy' | 'Strong' | 'Impact'
				| 'Heavy Bounce' | 'Big Pop' | 'Quick Pulse' | 'Pulse' | 'Tiny Bounce' | 'Subtle'
				| 'Minimal' | 'Soft Pop':
				'Psych Engine';
			case 'Golden Apple x Universe Engine' | 'Golden Apple (D&B)' | 'V-Slice HRK Style':
				'Golden Apple';
			case 'JS Strident Crisis':
				'Solar Engine';
			case 'Wide Stretch' | 'Student Crisis' | 'Side Bounce' | 'Wobble' | 'Rubber' | 'Squash & Stretch':
				'Elastic';
			default:
				STYLES.indexOf(name) >= 0 ? name : 'Psych Engine';
		}
	}

	// Scale multipliers for the two stretch presets; every other style computes its own.
	// LIMUL-MEM-OPT: shared arrays - the beat handler only reads them, and it used to allocate
	// a fresh pair on every beat of the song.
	private static var SCALE_ELASTIC:Array<Float> = [1.5, 1.1];
	private static var SCALE_TALL:Array<Float> = [1.15, 1.4];
	private static var SCALE_DEFAULT:Array<Float> = [1.2, 1.2];

	public static function getScale(style:String):Array<Float>
	{
		return switch (style)
		{
			case 'Elastic': SCALE_ELASTIC;
			case 'Tall Stretch': SCALE_TALL;
			default: SCALE_DEFAULT;
		}
	}

	var player:FlxSprite;
	var opponent:FlxSprite;
	var baseScale:Float;
	var style:String = 'Psych Engine';
	var requested:String = null;

	var startP:Array<Float> = [1, 1];
	var startO:Array<Float> = [1, 1];
	var startAP:Float = 0;
	var startAO:Float = 0;
	var timer:Float = 0;
	var timer2:Float = 0;
	var duration:Float = 0;
	var duration2:Float = 0;

	public function new(player:FlxSprite, opponent:FlxSprite, baseScale:Float = 1)
	{
		this.player = player;
		this.opponent = opponent;
		this.baseScale = baseScale;
	}

	public function setStyle(name:String):Void
	{
		requested = name;
		style = normalize(name);
		reset();
	}

	// PlayState reads the option once at creation, so a style picked in the pause menu
	// used to stick to the old motion until the song restarted. Called every frame.
	public function syncStyle(name:String):Void
	{
		if (name != requested) setStyle(name);
	}

	public function reset():Void
	{
		player.scale.set(baseScale, baseScale);
		opponent.scale.set(baseScale, baseScale);
		player.angle = 0;
		opponent.angle = 0;
		timer = 0;
		timer2 = 0;
		duration = 0;
		duration2 = 0;
	}

	// These two styles move the icons hard enough that PlayState re-anchors them to the bar line.
	public function anchorsToBar():Bool
	{
		return style == 'Golden Apple' || style == 'Universe Engine';
	}

	function captureStart():Void
	{
		startP[0] = player.scale.x;
		startP[1] = player.scale.y;
		startO[0] = opponent.scale.x;
		startO[1] = opponent.scale.y;
		startAP = player.angle;
		startAO = opponent.angle;
	}

	// Called on every beat. Applies the pop; update() eases it back.
	public function beat(healthPercent:Float, crochet:Float, bpm:Float, playbackRate:Float, beatCount:Int):Void
	{
		timer = 0;
		timer2 = 0;
		duration = 0;
		duration2 = 0;

		switch (style)
		{
			case 'Golden Apple':
				// JS Engine "Golden Apple": alternating squash/stretch plus a tilt.
				var even:Bool = beatCount % 2 == 0;
				player.scale.set(baseScale * 1.1, baseScale * (even ? 0.8 : 1.3));
				opponent.scale.set(baseScale * 1.1, baseScale * (even ? 1.3 : 0.8));
				player.angle = even ? -15 : 15;
				opponent.angle = even ? 15 : -15;
				duration = Math.max(0.05, crochet / 1300);
				captureStart();

			case 'Universe Engine':
				// Universe Engine "Icon Bop" (assets/uescript/OPTIONS/Icon Bop.lua): one icon
				// pulses up to 1.2 while the other drops to 0.7, both tilting 50 degrees the
				// same way. On even beats the player takes the big pulse and the tilt flips.
				var evenU:Bool = beatCount % 2 == 0;
				var big:Float = evenU ? 1.2 : 0.7;
				var small:Float = evenU ? 0.7 : 1.2;
				player.scale.set(baseScale * big, baseScale * big);
				opponent.scale.set(baseScale * small, baseScale * small);
				player.angle = evenU ? -50 : 50;
				opponent.angle = evenU ? -50 : 50;
				duration = 0.5;
				duration2 = 1.0;
				captureStart();

			case 'JS Dave and Bambi':
				// Width grows with health, height shrinks; recovers with a quartIn curve.
				var funny:Float = CoolUtil.boundTo(healthPercent / 100 * 2, 0.1, 1.9);
				player.scale.set(baseScale * (1 + 50 * (funny + 0.1) / 150), baseScale * (1 - 25 * funny / 150));
				opponent.scale.set(baseScale * (1 + 50 * ((2 - funny) + 0.1) / 150),
					baseScale * (1 - 25 * ((2 - funny) + 0.1) / 150));
				player.angle = 0;
				opponent.angle = 0;
				duration = 0.8;
				captureStart();

			case 'JS Plank Engine':
				player.scale.set(baseScale * 1.3, baseScale * 0.75);
				opponent.scale.set(baseScale * 1.3, baseScale * 0.75);
				player.angle = (beatCount % 4 == 0) ? -15 : 0;
				opponent.angle = (beatCount % 4 == 0) ? 15 : 0;
				duration = Math.max(0.05, crochet / 1000 / playbackRate);
				duration2 = duration;
				captureStart();

			case 'V-Slice Horizontal':
				vsliceBeat(0.2, -0.4, 0, 0);

			case 'V-Slice Vertical':
				vsliceBeat(-0.4, 0.2, 0, 0);

			case 'V-Slice Drill':
				vsliceBeat(0.6, 0, -25, 25);

			case 'Solar Engine':
				var evenS:Bool = beatCount % 2 == 0;
				player.scale.set(baseScale * 1.2, baseScale * 0.7);
				opponent.scale.set(baseScale * 1.2, baseScale * 0.7);
				player.angle = evenS ? -25 : 25;
				opponent.angle = evenS ? -25 : 25;
				duration = 0.5;
				duration2 = 1.0;
				captureStart();

			default:
				// Psych Engine and the plain scale presets: pop and lerp back.
				var s:Array<Float> = getScale(style);
				player.scale.set(baseScale * s[0], baseScale * s[1]);
				opponent.scale.set(baseScale * s[0], baseScale * s[1]);
				player.angle = 0;
				opponent.angle = 0;
		}

		player.updateHitbox();
		opponent.updateHitbox();
	}

	function vsliceBeat(plusX:Float, plusY:Float, playerAngle:Float, opponentAngle:Float):Void
	{
		player.scale.set(baseScale * (1 + plusX), baseScale * (1 + plusY));
		opponent.scale.set(baseScale * (1 + plusX), baseScale * (1 + plusY));
		player.angle = playerAngle;
		opponent.angle = opponentAngle;
	}

	// Called every frame; eases scale/angle back to rest.
	public function update(elapsed:Float, bpm:Float, playbackRate:Float, healthPercent:Float):Void
	{
		switch (style)
		{
			case 'Golden Apple':
				timer += elapsed * playbackRate;
				var p:Float = duration > 0 ? CoolUtil.boundTo(timer / duration, 0, 1) : 1;
				var e:Float = 1 - (1 - p) * (1 - p);
				player.scale.x = FlxMath.lerp(startP[0], baseScale, e);
				player.scale.y = FlxMath.lerp(startP[1], baseScale, e);
				opponent.scale.x = FlxMath.lerp(startO[0], baseScale, e);
				opponent.scale.y = FlxMath.lerp(startO[1], baseScale, e);
				player.angle = FlxMath.lerp(startAP, 0, e);
				opponent.angle = FlxMath.lerp(startAO, 0, e);

			case 'Universe Engine':
				// Both tweens in the original are expoOut and use fixed seconds, not the crochet.
				timer += elapsed;
				var pU:Float = duration > 0 ? CoolUtil.boundTo(timer / duration, 0, 1) : 1;
				var eU:Float = FlxEase.expoOut(pU);
				player.scale.x = FlxMath.lerp(startP[0], baseScale, eU);
				player.scale.y = FlxMath.lerp(startP[1], baseScale, eU);
				opponent.scale.x = FlxMath.lerp(startO[0], baseScale, eU);
				opponent.scale.y = FlxMath.lerp(startO[1], baseScale, eU);
				timer2 += elapsed;
				var aU:Float = duration2 > 0 ? CoolUtil.boundTo(timer2 / duration2, 0, 1) : 1;
				var eAU:Float = FlxEase.expoOut(aU);
				player.angle = FlxMath.lerp(startAP, 0, eAU);
				opponent.angle = FlxMath.lerp(startAO, 0, eAU);

			case 'JS Dave and Bambi':
				timer += elapsed / Math.max(0.01, playbackRate);
				var pD:Float = CoolUtil.boundTo(timer / 0.8, 0, 1);
				var kD:Float = FlxEase.quartIn(1 - pD);
				scaleFromStart(kD);
				player.angle = 0;
				opponent.angle = 0;

			case 'JS Plank Engine':
				timer += elapsed;
				var pP:Float = duration > 0 ? CoolUtil.boundTo(timer / duration, 0, 1) : 1;
				var kP:Float = FlxEase.backOut(pP);
				player.scale.x = FlxMath.lerp(startP[0], baseScale, kP);
				player.scale.y = FlxMath.lerp(startP[1], baseScale, kP);
				opponent.scale.x = FlxMath.lerp(startO[0], baseScale, kP);
				opponent.scale.y = FlxMath.lerp(startO[1], baseScale, kP);
				timer2 += elapsed;
				var aP:Float = duration2 > 0 ? CoolUtil.boundTo(timer2 / duration2, 0, 1) : 1;
				var eP:Float = FlxEase.expoOut(aP);
				player.angle = FlxMath.lerp(startAP, 0, eP);
				opponent.angle = FlxMath.lerp(startAO, 0, eP);

			case 'V-Slice Horizontal' | 'V-Slice Vertical' | 'V-Slice Drill':
				// H-Slice decays scale and angle exponentially, angle twice as fast.
				var sK:Float = Math.exp(-bpm / 24 * elapsed);
				var aK:Float = Math.exp(-bpm / 12 * elapsed);
				player.scale.x = baseScale + (player.scale.x - baseScale) * sK;
				player.scale.y = baseScale + (player.scale.y - baseScale) * sK;
				opponent.scale.x = baseScale + (opponent.scale.x - baseScale) * sK;
				opponent.scale.y = baseScale + (opponent.scale.y - baseScale) * sK;
				player.angle *= aK;
				opponent.angle *= aK;

			case 'Solar Engine':
				timer += elapsed;
				var pSc:Float = duration > 0 ? CoolUtil.boundTo(timer / duration, 0, 1) : 1;
				var eSc:Float = FlxEase.expoOut(pSc);
				player.scale.x = FlxMath.lerp(startP[0], baseScale, eSc);
				player.scale.y = FlxMath.lerp(startP[1], baseScale, eSc);
				opponent.scale.x = FlxMath.lerp(startO[0], baseScale, eSc);
				opponent.scale.y = FlxMath.lerp(startO[1], baseScale, eSc);
				timer2 += elapsed;
				var pAn:Float = duration2 > 0 ? CoolUtil.boundTo(timer2 / duration2, 0, 1) : 1;
				var eAn:Float = FlxEase.expoOut(pAn);
				player.angle = FlxMath.lerp(startAP, 0, eAn);
				opponent.angle = FlxMath.lerp(startAO, 0, eAn);

			default:
				// Psych Engine's recovery is lerp(1, scale, 1 - elapsed * 9), i.e. the icon
				// moves ~15% of the way home per 60 fps frame.
				var kDef:Float = CoolUtil.boundTo(elapsed * 9 * playbackRate, 0, 1);
				lerpToRest(kDef);
		}
	}

	inline function scaleFromStart(k:Float):Void
	{
		player.scale.x = baseScale + (startP[0] - baseScale) * k;
		player.scale.y = baseScale + (startP[1] - baseScale) * k;
		opponent.scale.x = baseScale + (startO[0] - baseScale) * k;
		opponent.scale.y = baseScale + (startO[1] - baseScale) * k;
	}

	inline function lerpToRest(k:Float):Void
	{
		player.scale.x = FlxMath.lerp(player.scale.x, baseScale, k);
		player.scale.y = FlxMath.lerp(player.scale.y, baseScale, k);
		opponent.scale.x = FlxMath.lerp(opponent.scale.x, baseScale, k);
		opponent.scale.y = FlxMath.lerp(opponent.scale.y, baseScale, k);
		player.angle = FlxMath.lerp(player.angle, 0, k);
		opponent.angle = FlxMath.lerp(opponent.angle, 0, k);
	}
}
