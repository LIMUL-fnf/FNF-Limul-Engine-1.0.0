package options;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;

using StringTools;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;
	private var ranks:Array<Int> = [];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var boyfriend:Character = null;
	private var descBox:FlxSprite;
	private var descText:FlxText;
	var previousMouseVisible:Bool = false;
	private var mouseNavigationEnabled:Bool = false;
	private var lastMouseX:Float = 0;
	private var lastMouseY:Float = 0;

	public var title:String;
	public var rpcTitle:String;

	public function new()
	{
		super();

		if(title == null) title = 'Options';
		if(rpcTitle == null) rpcTitle = 'Options Menu';
		
		#if desktop
		DiscordClient.changePresence(rpcTitle, null);
		#end
		
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		// avoids lagspikes while scrolling through menus!
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		var titleText:Alphabet = new Alphabet(75, 40, title, true);
		titleText.scaleX = 0.6;
		titleText.scaleY = 0.6;
		titleText.alpha = 0.4;
		add(titleText);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(290, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			/*optionText.forceX = 300;
			optionText.yMult = 90;*/
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(optionsArray[i].type == 'bool') {
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, optionsArray[i].getValue() == true);
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
			} else {
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				//optionText.xAdd -= 80;
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 80);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].setChild(valueText);
			}
			//optionText.snapToPosition(); //Don't ignore me when i ask for not making a fucking pull request to uncomment this line ok

			if(optionsArray[i].showBoyfriend && boyfriend == null)
			{
				reloadBoyfriend();
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection();
		reloadCheckboxes();
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
	}

	override public function create():Void
	{
		previousMouseVisible = FlxG.mouse.visible;
		FlxG.mouse.visible = false;
		lastMouseX = FlxG.mouse.screenX;
		lastMouseY = FlxG.mouse.screenY;
		mouseNavigationEnabled = false;
		super.create();
	}

	override public function destroy():Void
	{
		FlxG.mouse.visible = previousMouseVisible;
		super.destroy();
	}

	public function cycleStringOption(name:String, change:Int):Void
	{
		if (optionsArray == null) return;
		for (option in optionsArray)
		{
			if (option.name != name || option.type != 'string' || option.options == null || option.options.length == 0)
				continue;

			var index:Int = option.options.indexOf(option.getValue());
			if (index < 0) index = 0;
			index = (index + change + option.options.length) % option.options.length;
			option.curOption = index;
			option.setValue(option.options[index]);
			updateTextFrom(option);
			option.change();
			FlxG.sound.play(Paths.sound('scrollMenu'));
			return;
		}
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;
	override function update(elapsed:Float)
	{
		var mouseUsed:Bool = FlxG.mouse.screenX != lastMouseX || FlxG.mouse.screenY != lastMouseY || FlxG.mouse.justPressed || FlxG.mouse.wheel != 0;
		if (mouseUsed)
		{
			mouseNavigationEnabled = true;
			FlxG.mouse.visible = true;
		}
		lastMouseX = FlxG.mouse.screenX;
		lastMouseY = FlxG.mouse.screenY;

		var keyboardUsed:Bool = controls.UI_UP_P || controls.UI_DOWN_P || controls.UI_LEFT_P || controls.UI_RIGHT_P
			|| controls.ACCEPT || controls.BACK || controls.RESET;
		if (keyboardUsed)
		{
			mouseNavigationEnabled = false;
			FlxG.mouse.visible = false;
		}

		if (nextAccept <= 0 && mouseNavigationEnabled)
			handleMouseInput();

		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK) {
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept <= 0)
		{
			var usesCheckbox = true;
			if(curOption.type != 'bool')
			{
				usesCheckbox = false;
			}

			if(curOption.allowTyping && curOption.type != 'string' && FlxG.keys.justPressed.ENTER)
			{
				openTypedInput(curOption);
			}

			if(usesCheckbox)
			{
				if(controls.ACCEPT)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					curOption.setValue((curOption.getValue() == true) ? false : true);
					curOption.change();
					reloadCheckboxes();
					refreshVisibility();
				}
			} else {
				if(controls.UI_LEFT || controls.UI_RIGHT) {
					var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
					if(holdTime > 0.5 || pressed) {
						if(pressed) {
							var add:Dynamic = null;
							if(curOption.type != 'string') {
								add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
							}

							switch(curOption.type)
							{
								case 'int' | 'float' | 'percent':
									holdValue = curOption.getValue() + add;
									if(holdValue < curOption.minValue) holdValue = curOption.minValue;
									else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

									switch(curOption.type)
									{
										case 'int':
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);

										case 'float' | 'percent':
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
									}

								case 'string':
									var num:Int = curOption.options.indexOf(curOption.getValue());
									if (num < 0) num = 0;
									if(controls.UI_LEFT_P) --num;
									else num++;

									if(num < 0) {
										num = curOption.options.length - 1;
									} else if(num >= curOption.options.length) {
										num = 0;
									}

									curOption.curOption = num;
									curOption.setValue(curOption.options[num]); //lol
									//trace(curOption.options[num]);
							}
							updateTextFrom(curOption);
							curOption.change();
							FlxG.sound.play(Paths.sound('scrollMenu'));
						} else if(curOption.type != 'string') {
							holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
							if(holdValue < curOption.minValue) holdValue = curOption.minValue;
							else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

							switch(curOption.type)
							{
								case 'int':
									curOption.setValue(Math.round(holdValue));
								
								case 'float' | 'percent':
									curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
							}
							updateTextFrom(curOption);
							curOption.change();
						}
					}

					if(curOption.type != 'string') {
						holdTime += elapsed;
					}
				} else if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					clearHold();
				}
			}

			if(controls.RESET)
			{
				for (i in 0...optionsArray.length)
				{
					var leOption:Option = optionsArray[i];
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != 'bool')
					{
						if(leOption.type == 'string')
						{
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						}
						updateTextFrom(leOption);
					}
					leOption.change();
				}
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
				refreshVisibility();
			}
		}

		if(boyfriend != null && boyfriend.animation.curAnim.finished) {
			boyfriend.dance();
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function handleMouseInput():Void
	{
		if (FlxG.mouse.wheel != 0)
		{
			changeSelection(FlxG.mouse.wheel > 0 ? -1 : 1);
			return;
		}

		for (i in 0...grpOptions.members.length)
		{
			var item:Alphabet = grpOptions.members[i];
			if (item == null || !item.visible || !FlxG.mouse.overlaps(item)) continue;

			if (curSelected != i) changeSelection(i - curSelected);
			if (FlxG.mouse.justPressed)
			{
				switch (curOption.type)
				{
					case 'bool':
						curOption.setValue(!(curOption.getValue() == true));
						curOption.change();
						reloadCheckboxes();
						refreshVisibility();
					case 'string':
						cycleStringOption(curOption.name, 1);
					default:
						adjustNumericOption(curOption, FlxG.mouse.x < item.x + item.width * 0.5 ? -1 : 1);
				}
			}
			break;
		}
	}

	function adjustNumericOption(option:Option, direction:Int):Void
	{
		var value:Float = option.getValue();
		value += option.changeValue * direction;
		if (value < option.minValue) value = option.minValue;
		if (value > option.maxValue) value = option.maxValue;
		if (option.type == 'int') value = Math.round(value);
		else value = FlxMath.roundDecimal(value, option.decimals);
		option.setValue(value);
		updateTextFrom(option);
		option.change();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function updateTextFrom(option:Option) {
		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == 'percent') val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}

	function clearHold()
	{
		if(holdTime > 0.5) {
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		holdTime = 0;
	}
	
	function changeSelection(change:Int = 0)
	{
		if (optionsArray.length < 1)
			return;

		curSelected += change;
		var forward:Int = change >= 0 ? 1 : -1;
		var guard:Int = 0;
		while (true)
		{
			while (curSelected < 0) curSelected += optionsArray.length;
			while (curSelected >= optionsArray.length) curSelected -= optionsArray.length;

			if (!optionsArray[curSelected].isHidden() || guard >= optionsArray.length) break;
			curSelected += forward;
			guard++;
		}

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		applyVisibility();

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		if(boyfriend != null)
		{
			boyfriend.visible = optionsArray[curSelected].showBoyfriend;
		}
		curOption = optionsArray[curSelected]; //shorter lol
		onOptionSelected(curOption);
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	// Options can hide themselves (hiddenIf), so rows are laid out by their visible rank
	// instead of their index -- otherwise a collapsed row would leave a gap in the menu.
	function applyVisibility():Void
	{
		var visibleRank:Int = -1;
		var selRank:Int = -1;
		for (i in 0...optionsArray.length)
		{
			if (optionsArray[i].isHidden())
			{
				ranks[i] = -1;
				continue;
			}
			visibleRank++;
			ranks[i] = visibleRank;
			if (i == curSelected) selRank = visibleRank;
		}
		if (selRank < 0) selRank = 0;

		var idx:Int = 0;
		for (item in grpOptions.members)
		{
			var vis:Bool = idx < ranks.length && ranks[idx] >= 0;
			item.visible = vis;
			if (vis)
			{
				item.targetY = ranks[idx] - selRank;
				item.alpha = (item.targetY == 0) ? 1 : 0.6;
			}
			idx++;
		}
		for (text in grpTexts)
		{
			var vis:Bool = text.ID < ranks.length && ranks[text.ID] >= 0;
			text.visible = vis;
			if (vis) text.alpha = (text.ID == curSelected) ? 1 : 0.6;
		}
		for (checkbox in checkboxGroup)
			checkbox.visible = checkbox.ID < ranks.length && ranks[checkbox.ID] >= 0;
	}

	function refreshVisibility():Void
	{
		if (optionsArray[curSelected].isHidden())
			changeSelection(1);
		else
			applyVisibility();
	}

	function openTypedInput(option:Option):Void
	{
		openSubState(new options.NumberInputSubState(option, function()
		{
			updateTextFrom(option);
			option.change();
		}));
	}

	public function onOptionSelected(option:Option):Void {}

	public function reloadBoyfriend()
	{
		var wasVisible:Bool = false;
		if(boyfriend != null) {
			wasVisible = boyfriend.visible;
			boyfriend.kill();
			remove(boyfriend);
			boyfriend.destroy();
		}

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		insert(1, boyfriend);
		boyfriend.visible = wasVisible;
	}

	function reloadCheckboxes() {
		for (checkbox in checkboxGroup) {
			checkbox.daValue = (optionsArray[checkbox.ID].getValue() == true);
		}
	}
}
