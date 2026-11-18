package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flxanimate.FlxAnimate;

/**
 * Darnell's spray can from Weekend 1, ported from FNF-JS-Engine 1.51.1
 * (source/stages/objects/SpraycanAtlasSprite.hx). The whole throw is baked into the
 * Animate 2020 module `spraycanAtlas`: 'Can Start' (0-18) arcs the can across the street,
 * 'Hit Pico' (19-25) lands it and the Sparrow sprite below draws the paint cloud,
 * 'Can Shot' (26-42) is the can being shot out of the air. No hitbox and no health loss:
 * the can is decoration in the original too.
 */
class SpraycanAtlasSprite extends FlxSpriteGroup
{
	public var canAtlas:FlxAnimate;
	public var explosion:FlxSprite;

	var playingAnim:String;

	public function new(x:Float = 0, y:Float = 0)
	{
		super();

		canAtlas = new FlxAnimate(x, y);
		Paths.loadAnimateAtlas(canAtlas, 'spraycanAtlas');
		canAtlas.anim.addBySymbolIndices('Can Start', 'Can with Labels', [for (i in 0...19) i], 24, false);
		canAtlas.anim.addBySymbolIndices('Hit Pico', 'Can with Labels', [19, 20, 21, 22, 23, 24, 25], 24, false);
		canAtlas.anim.addBySymbolIndices('Can Shot', 'Can with Labels', [26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42], 24, false);
		canAtlas.anim.onComplete = finishCanAnimation;
		canAtlas.visible = canAtlas.active = false;
		canAtlas.antialiasing = ClientPrefs.globalAntialiasing;
		add(canAtlas);

		explosion = new FlxSprite(x - 25, y - 450);
		explosion.frames = Paths.getSparrowAtlas('spraypaintExplosionEZ');
		explosion.animation.addByPrefix('idle', 'explosion round 1 short0', 24, false);
		explosion.animation.finishCallback = (name:String) -> explosion.visible = explosion.active = false;
		explosion.visible = explosion.active = false;
		explosion.antialiasing = ClientPrefs.globalAntialiasing;
		add(explosion);
	}

	function finishCanAnimation():Void
	{
		switch (playingAnim)
		{
			case 'Can Start':
				playHitPico();
			case 'Can Shot':
				canAtlas.visible = canAtlas.active = false;
			case 'Hit Pico':
				playHitExplosion();
				canAtlas.visible = canAtlas.active = false;
		}
	}

	public function playHitExplosion():Void
	{
		explosion.visible = explosion.active = true;
		explosion.animation.play('idle', true);
		// The JS original's paint cloud is mute; the boom is the Limul addition kept from the old
		// Lua can so the explosion does not go silent.
		FlxG.sound.play(Paths.sound('gameplay/gameover/fnf_loss_sfx-pico-explode'), 0.75);
	}

	public function playCanStart():Void
	{
		playAnimation('Can Start');
		canAtlas.visible = canAtlas.active = true;
	}

	public function playCanShot():Void
	{
		playAnimation('Can Shot');
	}

	public function playHitPico():Void
	{
		playAnimation('Hit Pico');
	}

	function playAnimation(name:String):Void
	{
		canAtlas.anim.play(name, true);
		playingAnim = name;
	}
}
