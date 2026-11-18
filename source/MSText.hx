import flixel.FlxG;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

typedef MSTextProperties =
{
	noteDiff:Float,
	combo:Float,
	rating:String,
	miss:Bool,
	cpuControlled:Bool,
	playbackRate:Float
};

class MSText extends FlxText
{
	public static var instance:MSText = null;

	public function new(camHUD:FlxCamera)
	{
		super(0, 0, 0, "");

		if (instance != null) throw "Cannot initiate another MSText with one already existing!";

		cameras = [camHUD != null ? camHUD : FlxG.camera];
		scrollFactor.set();
		active = false;
		visible = false;

		instance = this;

		applyStyle();
		applyPosition();
	}

	function applyStyle()
	{
		var font = switch (ClientPrefs.scoreStyle)
		{
			case 'TGT V4': Paths.font('calibri.ttf');
			case 'Dave Engine': Paths.font('comic.ttf');
			case 'Doki Doki+': Paths.font('Aller_rg.ttf');
			default: Paths.font('vcr.ttf');
		}

		setFormat(font, 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	}

	function applyPosition()
	{
		x = 408 + 250;
		y = 290 - 25;

		if (PlayState.isPixelStage)
		{
			x = 408 + 260;
			y = 290 + 20;
		}

		x += ClientPrefs.comboOffset[0];
		y -= ClientPrefs.comboOffset[1];
	}

	public function showHit(properties:MSTextProperties)
	{
		if (!ClientPrefs.showMS || ClientPrefs.hideHud) return;

		var noteDiff = properties.noteDiff;
		var combo = properties.combo;
		var rating = properties.rating;
		var miss = properties.miss;
		var cpuControlled = properties.cpuControlled;
		var playbackRate = properties.playbackRate;

		FlxTween.cancelTweensOf(this);

		visible = true;
		alpha = 1;

		text = cpuControlled ? "0 MS (Bot)" : FlxMath.roundDecimal(-noteDiff, 3) + " MS";

		screenCenter();
		x = (FlxG.width * 0.35) + 80;

		x += ClientPrefs.comboOffset[0];
		y -= ClientPrefs.comboOffset[1];

		if (combo >= 10000) x += 30 * (Std.string(combo).length - 4);

		applyColor(rating, miss);

		FlxTween.tween(this, {y: y + 8}, 0.1 / playbackRate, {
			onComplete: function(_) {
				FlxTween.tween(this, {alpha: 0}, 0.2 / playbackRate, {
					startDelay: 1.4 / playbackRate,
					onComplete: function(_) visible = false
				});
			}
		});
	}

	function applyColor(rating:String, miss:Bool)
	{
		if (miss)
		{
			color = FlxColor.fromRGB(204, 66, 66);
			return;
		}

		switch (rating)
		{
			case 'perfect':
				color = FlxColor.YELLOW;
			case 'sick':
				color = FlxColor.CYAN;
			case 'good':
				color = FlxColor.LIME;
			case 'bad':
				color = FlxColor.ORANGE;
			case 'shit', 'crap':
				color = FlxColor.RED;
			default:
				color = FlxColor.WHITE;
		}
	}

	override function destroy()
	{
		super.destroy();
		if (instance == this) instance = null;
	}
}
