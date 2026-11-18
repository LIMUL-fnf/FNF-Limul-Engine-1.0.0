package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class NumberInputSubState extends FlxSubState
{
	static inline var MAX_DIGITS:Int = 6;

	static var DIGIT_KEYS:Array<FlxKey> = [
		FlxKey.ZERO, FlxKey.ONE, FlxKey.TWO, FlxKey.THREE, FlxKey.FOUR,
		FlxKey.FIVE, FlxKey.SIX, FlxKey.SEVEN, FlxKey.EIGHT, FlxKey.NINE
	];
	static var NUMPAD_KEYS:Array<FlxKey> = [
		FlxKey.NUMPADZERO, FlxKey.NUMPADONE, FlxKey.NUMPADTWO, FlxKey.NUMPADTHREE, FlxKey.NUMPADFOUR,
		FlxKey.NUMPADFIVE, FlxKey.NUMPADSIX, FlxKey.NUMPADSEVEN, FlxKey.NUMPADEIGHT, FlxKey.NUMPADNINE
	];

	var option:Option;
	var onConfirm:Void->Void;
	var typed:String = '';
	var valueText:FlxText;
	var blinkTimer:Float = 0;
	var cursorOn:Bool = true;
	var acceptGuard:Bool = true;

	public function new(option:Option, onConfirm:Void->Void)
	{
		super(0x99000000);
		this.option = option;
		this.onConfirm = onConfirm;
		typed = Std.string(Std.int(option.getValue()));
	}

	override public function create():Void
	{
		var box:FlxSprite = new FlxSprite().makeGraphic(700, 280, FlxColor.BLACK);
		box.screenCenter();
		box.alpha = 0.9;
		add(box);

		var title:FlxText = new FlxText(0, box.y + 30, FlxG.width, option.name, 28);
		title.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		add(title);

		valueText = new FlxText(0, box.y + 105, FlxG.width, '', 56);
		valueText.setFormat(Paths.font('vcr.ttf'), 56, FlxColor.WHITE, CENTER);
		add(valueText);

		var hint:FlxText = new FlxText(0, box.y + 215, FlxG.width, 'ENTER = OK    BACKSPACE = delete    ESC = cancel', 18);
		hint.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.GRAY, CENTER);
		add(hint);

		updateValueText();
		super.create();
	}

	override public function update(elapsed:Float):Void
	{
		// The menu opens this substate on the same ENTER press that confirms it here.
		if (acceptGuard)
		{
			acceptGuard = false;
			super.update(elapsed);
			return;
		}

		blinkTimer += elapsed;
		if (blinkTimer >= 0.4)
		{
			blinkTimer = 0;
			cursorOn = !cursorOn;
			updateValueText();
		}

		for (i in 0...DIGIT_KEYS.length)
		{
			if (FlxG.keys.anyJustPressed([DIGIT_KEYS[i]]) || FlxG.keys.anyJustPressed([NUMPAD_KEYS[i]]))
				appendDigit(Std.string(i));
		}

		if (FlxG.keys.justPressed.BACKSPACE && typed.length > 0)
		{
			typed = typed.substr(0, typed.length - 1);
			updateValueText();
		}

		if (FlxG.keys.justPressed.ENTER)
			confirm();
		else if (FlxG.keys.justPressed.ESCAPE)
			cancel();

		super.update(elapsed);
	}

	function appendDigit(digit:String):Void
	{
		if (typed.length >= MAX_DIGITS) return;
		typed += digit;
		updateValueText();
	}

	function updateValueText():Void
	{
		if (valueText == null) return;
		valueText.text = typed + (cursorOn ? '|' : ' ');
	}

	function confirm():Void
	{
		var parsed:Null<Int> = Std.parseInt(typed);
		var value:Float = parsed == null ? option.getValue() : parsed;
		var min:Float = option.minValue == null ? -999999 : option.minValue;
		var max:Float = option.maxValue == null ? 999999 : option.maxValue;
		if (value < min) value = min;
		if (value > max) value = max;
		if (option.type == 'int') option.setValue(Math.round(value));
		else option.setValue(FlxMath.roundDecimal(value, option.decimals));
		FlxG.sound.play(Paths.sound('scrollMenu'));
		if (onConfirm != null) onConfirm();
		close();
	}

	function cancel():Void
	{
		FlxG.sound.play(Paths.sound('cancelMenu'));
		close();
	}
}
