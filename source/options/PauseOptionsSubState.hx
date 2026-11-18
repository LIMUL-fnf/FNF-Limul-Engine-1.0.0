package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class PauseOptionsSubState extends MusicBeatSubstate
{
	var optionNames:Array<String> = [
		'Graphics',
		'Optimization',
		'Visuals and UI',
		'Gameplay',
		'Controls',
		'Note Colors',
		'Back'
	];
	var optionGroup:FlxTypedGroup<Alphabet>;
	var curSelected:Int = 0;

	public function new()
	{
		super();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.92;
		add(bg);

		var title:FlxText = new FlxText(0, 52, FlxG.width, 'OPTIONS', 32);
		title.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
		add(title);

		optionGroup = new FlxTypedGroup<Alphabet>();
		add(optionGroup);
		for (i in 0...optionNames.length)
		{
			var item:Alphabet = new Alphabet(0, 0, optionNames[i], true);
			item.screenCenter();
			item.isMenuItem = true;
			item.changeX = false;
			item.distancePerItem.y = 100;
			item.startPosition.set(item.x, FlxG.height / 2 - 30);
			item.y = item.startPosition.y;
			item.targetY = i - curSelected;
			optionGroup.add(item);
		}
		changeSelection();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	override function update(elapsed:Float):Void
	{
		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		if (controls.BACK)
		{
			close();
			return;
		}

		if (controls.ACCEPT)
			openOption(optionNames[curSelected]);

		super.update(elapsed);
	}

	function openOption(name:String):Void
	{
		switch (name)
		{
			case 'Graphics': openSettingsSubState(new GraphicsSettingsSubState());
			case 'Optimization': openSettingsSubState(new OptimizationSubState());
			case 'Visuals and UI': openSettingsSubState(new VisualsUISubState());
			case 'Gameplay': openSettingsSubState(new GameplaySettingsSubState());
			case 'Controls': openSettingsSubState(new ControlsSubState());
			case 'Note Colors': openSettingsSubState(new NotesSubState());
			case 'Back': close();
		}
	}

	function openSettingsSubState(subState:MusicBeatSubstate):Void
	{
		subState.cameras = cameras;
		openSubState(subState);
	}

	override function closeSubState():Void
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = (curSelected + change + optionNames.length) % optionNames.length;
		for (i in 0...optionGroup.members.length)
		{
			var item:Alphabet = optionGroup.members[i];
			item.targetY = i - curSelected;
			item.alpha = i == curSelected ? 1 : 0.6;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
}