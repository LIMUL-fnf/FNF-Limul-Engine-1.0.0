package;

import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import flixel.util.FlxSort;

/**
 * Port of P-Slice's `mikolka.vslice.freeplay.BGScrollingText` (P-Slice 3.4.2).
 *
 * One text texture is drawn several times side by side, so a marquee line never leaves a
 * hole on the Freeplay backing card; the copies scroll and wrap around at the ends.
 * `speed` is expressed in pixels per 1/60 s frame, exactly like the original class.
 */
class BGScrollingText extends FlxText
{
	var _textPositions:Array<FlxPoint> = [];
	var _positionCache:FlxPoint;
	var _clipRect:FlxRect;

	public var widthShit:Float = FlxG.width;
	public var placementOffset:Float = 20;
	public var speed:Float = 1;
	/** Screen-space x where the marquee stops (the backing card's right edge). 0 = no clip. */
	public var clipRight:Float = 0;

	public function new(x:Float, y:Float, text:String, widthShit:Float = 100, ?bold:Bool = false, ?size:Int = 48)
	{
		super(x, y, 0, text, size);
		_positionCache = FlxPoint.get(x, y);
		font = Paths.font('5by7.ttf');
		this.bold = bold;
		antialiasing = false;

		this.widthShit = widthShit;

		@:privateAccess
		regenGraphic();

		var copyWidth:Float = frameWidth + placementOffset;
		var needed:Int = Math.ceil(widthShit / Math.max(1, copyWidth)) + 1;
		for (i in 0...needed)
			_textPositions.push(FlxPoint.get(i * copyWidth, 0));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (txtPosition in _textPositions)
		{
			if (txtPosition == null) continue;
			txtPosition.x -= speed * (elapsed / (1 / 60));

			if (speed > 0) // going left
			{
				if (txtPosition.x < -frameWidth)
				{
					txtPosition.x = _textPositions[_textPositions.length - 1].x + frameWidth + placementOffset;
					sortText();
				}
			}
			else if (speed < 0) // going right
			{
				if (txtPosition.x > frameWidth * 2)
				{
					txtPosition.x = _textPositions[0].x - frameWidth - placementOffset;
					sortText();
				}
			}
		}
	}

	override public function draw():Void
	{
		_positionCache.set(x, y);
		for (position in _textPositions)
		{
			var screenX:Float = _positionCache.x + position.x;
			setPosition(screenX, _positionCache.y + position.y);
			if (clipRight > 0)
			{
				// P-Slice hides the marquee behind the card with a masked black overlay; we have no
				// shader there, so every copy is clipped to the card's right edge in screen space.
				var from:Float = -screenX;
				var to:Float = clipRight - screenX;
				if (from < 0) from = 0;
				if (to > frameWidth) to = frameWidth;
				if (to <= from) continue;
				if (_clipRect == null) _clipRect = FlxRect.get(0, 0, 0, 0);
				_clipRect.set(from, 0, to - from, frameHeight);
				clipRect = _clipRect;
			}
			super.draw();
		}
		setPosition(_positionCache.x, _positionCache.y);
		if (clipRight > 0) clipRect = null;
	}

	function sortText():Void
	{
		_textPositions.sort(function(a:FlxPoint, b:FlxPoint)
		{
			return FlxSort.byValues(FlxSort.ASCENDING, a.x, b.x);
		});
	}
}
