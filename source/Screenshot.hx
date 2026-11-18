package;

import lime.app.Application;
import lime.graphics.Image;
import lime.graphics.ImageFileFormat;
import lime.ui.Window;

using StringTools;

// LIMUL-RENDER (JS Engine parity): window pixel capture used by F2 screenshots and by the
// classic rendering mode, which dumps one PNG/JPG per frame for a later ffmpeg pass.
class Screenshot
{
	public var target:String = 'screenshots';
	public static var slash:String = #if windows '\\' #else '/' #end;

	var window:Window = null;
	var image:Image;

	public function new() {}

	public function readPixels():Image
	{
		if (window == null) window = Application.current.window;
		image = window.readPixels();
		return image;
	}

	public function save(path:String = '', name:String = ''):Bool
	{
		#if sys
		readPixels();
		if (image == null) return false;

		var slash:String = #if windows '\\' #else '/' #end;
		var dir:String = target;
		if (path.length > 0)
		{
			if (!path.endsWith('/') && !path.endsWith('\\'))
				path += slash;
			dir = target + slash + path.substr(0, path.length - 1);
		}
		if (!sys.FileSystem.exists(dir))
			sys.FileSystem.createDirectory(dir);
		else if (!sys.FileSystem.isDirectory(dir))
		{
			sys.FileSystem.deleteFile(dir);
			sys.FileSystem.createDirectory(dir);
		}

		if (name.length == 0)
			name = 'Screenshot ' + Date.now().toString().split(':').join('-').split(' ').join('_');

		name += ClientPrefs.lossless ? '.png' : '.jpg';
		var fullPath:String = dir + slash + name;

		var byteData:haxe.io.Bytes = image.encode(ClientPrefs.lossless ? ImageFileFormat.PNG : ImageFileFormat.JPEG, ClientPrefs.quality);
		if (byteData == null) return false;
		var f = sys.io.File.write(fullPath, true);
		if (f == null) return false;
		f.write(byteData);
		f.close();
		return true;
		#else
		return false;
		#end
	}
}
