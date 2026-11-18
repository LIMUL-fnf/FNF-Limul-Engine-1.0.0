package;

import flixel.FlxSprite;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		isOldIcon = (char == 'bf-old');
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	public function swapOldIcon() {
		if(isOldIcon = !isOldIcon) changeIcon('bf-old');
		else changeIcon('bf');
	}

	private var iconOffsets:Array<Float> = [0, 0];

	// LIMUL-FREEPLAY-SCALE: which of the three file names an icon actually resolves to is decided by
	// disk state that cannot change while the menu is open, but changeIcon() asked the disk every
	// time -- two Paths.fileExists() (each one up to two FileSystem.exists() probes plus a manifest
	// lookup) per icon, and a 400-song Freeplay asks for one per row. Cached per (week folder, char),
	// which is exactly the state the lookup depends on, so the answer stays honest when a row is
	// built from another week's directory.
	static var resolvedIcons:Map<String, String> = new Map();

	static function resolveIconName(char:String):String
	{
		var cacheKey:String = (Paths.currentModDirectory != null ? Paths.currentModDirectory : '') + '|' + char;
		var cached:String = resolvedIcons.get(cacheKey);
		if (cached != null) return cached;

		var name:String = 'icons/' + char;
		if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
		if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
		resolvedIcons.set(cacheKey, name);
		return name;
	}

	public function changeIcon(char:String) {
		if(this.char != char) {
			var name:String = resolveIconName(char);
			var file:Dynamic = Paths.image(name);

			loadGraphic(file); //Load stupidly first for getting the file size
			// JS Engine icon sheets are N square frames: 2 (normal/losing) or 3 (+winning). Splitting
			// by a hardcoded 2 sliced every 450px BF icon style in half.
			final iSize:Float = Math.round(width / height);
			loadGraphic(file, true, Math.floor(width / iSize), Math.floor(height)); //Then load it fr
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			antialiasing = ClientPrefs.globalAntialiasing;
			if(char.endsWith('-pixel')) {
				antialiasing = false;
			}
		}
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		offset.x = iconOffsets[0];
		offset.y = iconOffsets[1];
	}

	public function getCharacter():String {
		return char;
	}
}
