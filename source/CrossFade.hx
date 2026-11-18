package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

// Ported from JS Engine 1.51.1 (Denpa Engine style character ghost)
class CrossFade extends FlxSprite
{
	public function new(character:Character, group:FlxTypedGroup<CrossFade>, ?isDad:Bool = true)
	{
		super();
		frames = character.frames;
		alpha = 0.3;
		setGraphicSize(Std.int(character.width), Std.int(character.height));
		scrollFactor.set(character.scrollFactor.x, character.scrollFactor.y);
		updateHitbox();
		flipX = character.flipX;
		flipY = character.flipY;

		var curCrossFadeMode:String = ClientPrefs.crossFadeMode;
		switch (curCrossFadeMode)
		{
			case 'Static':
				x = character.x + 60;
				y = character.y - 50;
			case 'Eccentric':
				x = character.x + FlxG.random.float(-20, 90);
				y = character.y + FlxG.random.float(-80, 80);
			default:
				x = character.x + FlxG.random.float(0, 60);
				y = character.y + FlxG.random.float(-50, 50);
		}
		offset.x = character.offset.x;
		offset.y = character.offset.y;
		animation.add('cur', character.animation.curAnim.frames, 24, false);
		animation.play('cur', true);
		animation.curAnim.curFrame = character.animation.curAnim.curFrame;

		switch (character.curCharacter)
		{
			case 'gf-pixel':
				color = 0xFFa5004d;
				antialiasing = false;
			case 'monster' | 'monster-christmas':
				color = 0xFF981b3a;
				antialiasing = ClientPrefs.globalAntialiasing;
			case 'pico' | 'pico-player':
				color = 0xff2c8c00;
				antialiasing = character.antialiasing;
			case 'bf' | 'bf-car' | 'bf-christmas':
				color = 0xFF1b008c;
				antialiasing = ClientPrefs.globalAntialiasing;
			case 'bf-holding-gf':
				color = FlxG.random.bool(50) ? 0xFF1b008c : 0xFFa5004d;
				antialiasing = ClientPrefs.globalAntialiasing;
			case 'parents-christmas':
				@:privateAccess
				var sectionIndex:Int = PlayState.instance.curSection;
				var isAlt:Bool = PlayState.SONG.notes[sectionIndex].altAnim;
				color = isAlt ? 0xff882952 : 0xff6a3381;
				antialiasing = character.antialiasing;
			case 'spooky':
				color = FlxG.random.bool(50) ? 0xff777777 : 0xff925500;
				antialiasing = character.antialiasing;
			case 'bf-pixel' | 'bf-pixel-opponent':
				color = 0xFF00368c;
				antialiasing = false;
			case 'senpai' | 'senpai-angry':
				color = 0xFFffaa6f;
				antialiasing = false;
			case 'tankman' | 'tankman-player':
				color = 0xff000000;
				antialiasing = ClientPrefs.globalAntialiasing;
			default:
				color = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
				color = FlxColor.subtract(color, 0x00333333);
				antialiasing = ClientPrefs.globalAntialiasing;
		}

		var dir:Bool = FlxG.random.bool(70);
		var velo:Float = 12 * 5;
		switch (curCrossFadeMode)
		{
			case 'Static':
				velocity.x = 0;
			case 'Eccentric':
				velo = 12 * 8;
				velocity.x = (isDad == dir) ? -velo : velo;
			default:
				velocity.x = (isDad == dir) ? -velo : velo;
		}

		FlxTween.tween(this, {alpha: 0}, 0.35, {
			onComplete: function(twn:FlxTween)
			{
				kill();
				destroy();
			}
		});

		group.add(this);
	}
}
