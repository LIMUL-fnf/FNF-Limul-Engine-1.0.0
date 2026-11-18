package flixel.graphics.tile;

#if FLX_DRAW_QUADS
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import openfl.display.ShaderParameter;
import openfl.geom.ColorTransform;
import openfl.Vector;

class FlxDrawQuadsItem extends FlxDrawBaseItem<FlxDrawQuadsItem>
{
	static inline var VERTICES_PER_QUAD = #if (openfl >= "8.5.0") 4 #else 6 #end;
	static var invalidBatchLogged:Bool = false;

	public var shader:FlxShader;

	var rects:Vector<Float>;
	var transforms:Vector<Float>;
	var alphas:Array<Float>;
	var colorMultipliers:Array<Float>;
	var colorOffsets:Array<Float>;
	var graphicPinned:Bool = false;

	public function new()
	{
		super();
		type = FlxDrawItemType.TILES;
		rects = new Vector<Float>();
		transforms = new Vector<Float>();
		alphas = [];
	}

	override public function reset():Void
	{
		releaseGraphic();
		super.reset();
		rects.length = 0;
		transforms.length = 0;
		alphas.splice(0, alphas.length);
		if (colorMultipliers != null)
			colorMultipliers.splice(0, colorMultipliers.length);
		if (colorOffsets != null)
			colorOffsets.splice(0, colorOffsets.length);
	}

	override public function dispose():Void
	{
		releaseGraphic();
		super.dispose();
		rects = null;
		transforms = null;
		alphas = null;
		colorMultipliers = null;
		colorOffsets = null;
	}

	override public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform):Void
	{
		if (rects.length == 0 && graphics != null)
		{
			graphics.persist = true;
			graphics.incrementUseCount();
			graphicPinned = true;
		}

		var rect = frame.frame;
		rects.push(rect.x);
		rects.push(rect.y);
		rects.push(rect.width);
		rects.push(rect.height);

		transforms.push(matrix.a);
		transforms.push(matrix.b);
		transforms.push(matrix.c);
		transforms.push(matrix.d);
		transforms.push(matrix.tx);
		transforms.push(matrix.ty);

		for (i in 0...VERTICES_PER_QUAD)
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);

		if (colored || hasColorOffsets)
		{
			if (colorMultipliers == null)
				colorMultipliers = [];
			if (colorOffsets == null)
				colorOffsets = [];

			for (i in 0...VERTICES_PER_QUAD)
			{
				if (transform != null)
				{
					colorMultipliers.push(transform.redMultiplier);
					colorMultipliers.push(transform.greenMultiplier);
					colorMultipliers.push(transform.blueMultiplier);
					colorOffsets.push(transform.redOffset);
					colorOffsets.push(transform.greenOffset);
					colorOffsets.push(transform.blueOffset);
					colorOffsets.push(transform.alphaOffset);
				}
				else
				{
					colorMultipliers.push(1);
					colorMultipliers.push(1);
					colorMultipliers.push(1);
					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
				}

				colorMultipliers.push(1);
			}
		}
	}

	#if !flash
	override public function render(camera:FlxCamera):Void
	{
		if (rects.length == 0)
			return;

		if (graphics == null || graphics.bitmap == null)
		{
			logInvalidBatch('quad batch references a missing or destroyed graphic');
			return;
		}

		var drawShader:FlxShader = shader != null ? shader : graphics.shader;
		if (drawShader == null || drawShader.bitmap == null)
		{
			logInvalidBatch('quad batch has no valid graphics shader');
			return;
		}

		drawShader.bitmap.input = graphics.bitmap;
		drawShader.bitmap.filter = (camera.antialiasing || antialiasing) ? LINEAR : NEAREST;
		drawShader.alpha.value = alphas;

		if (colored || hasColorOffsets)
		{
			drawShader.colorMultiplier.value = colorMultipliers;
			drawShader.colorOffset.value = colorOffsets;
		}

		setParameterValue(drawShader.hasTransform, true);
		setParameterValue(drawShader.hasColorTransform, colored || hasColorOffsets);

		#if (openfl > "8.7.0")
		camera.canvas.graphics.overrideBlendMode(blend);
		#end
		camera.canvas.graphics.beginShaderFill(drawShader);
		camera.canvas.graphics.drawQuads(rects, null, transforms);
		super.render(camera);
	}

	inline function logInvalidBatch(message:String):Void
	{
		if (!invalidBatchLogged)
		{
			invalidBatchLogged = true;
			FlxG.log.error('Skipped invalid render batch: ' + message);
		}
	}

	inline function releaseGraphic():Void
	{
		if (graphicPinned && graphics != null)
		{
			graphics.decrementUseCount();
			graphicPinned = false;
		}
	}

	inline function setParameterValue(parameter:ShaderParameter<Bool>, value:Bool):Void
	{
		if (parameter.value == null)
			parameter.value = [];
		parameter.value[0] = value;
	}
	#end
}
#end
