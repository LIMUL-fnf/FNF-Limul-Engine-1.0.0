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
import flixel.ui.FlxButton;
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
import openfl.utils.AssetType;

using StringTools;

class VisualsUISubState extends BaseOptionsMenu
{
	var previewGroup:FlxTypedGroup<FlxSprite>;
	var previewLabel:FlxText;
	var previewPlayer:HealthIcon;
	var previewOpponent:HealthIcon;
	var previewBounce:IconBounce;
	var stylePrevButton:FlxButton;
	var styleNextButton:FlxButton;
	var previewBeatTimer:Float = 0;
	var previewBeatCount:Int = 0;
	static inline var PREVIEW_HEALTH_BAR_X:Float = 855;
	static inline var PREVIEW_HEALTH_BAR_Y:Float = 480;
	static inline var PREVIEW_HEALTH_BAR_WIDTH:Float = 320;
	static inline var PREVIEW_HEALTH_PERCENT:Float = 50;

	public function new()
	{
		title = 'Visuals and UI';
		rpcTitle = 'Visuals & UI Settings Menu'; //for Discord Rich Presence

		var option:Option = new Option('Note Splashes',
			"If unchecked, hitting \"Sick!\" notes won't show particles.",
			'noteSplashes',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Note Splash Opacity',
			"How much transparent should the Note Splashes be.",
			'noteSplashAlpha',
			'percent',
			0.6);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Background Dim',
			"Darkens the stage and characters behind the notes.\n0% is off, 100% is pure black.",
			'bgDim',
			'percent',
			0);
		option.scrollSpeed = 1.6;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		// Forever Engine parity: pick a global note texture. Skins are data, so the option only
		// appears when the pack actually ships a noteSkins/list.txt; Name is stored in prefs and
		// resolved as a "-name" postfix in Note.reloadNote()/StrumNote.
		var noteSkins:Array<String> = ['Default'];
		try
		{
			if (Paths.fileExists('images/noteSkins/list.txt', TEXT))
			{
				for (line in Paths.getTextFromFile('images/noteSkins/list.txt').split('\n'))
				{
					var skinName:String = line.trim();
					if (skinName.length > 0 && !noteSkins.contains(skinName))
						noteSkins.push(skinName);
				}
			}
		}
		catch (e:Dynamic) {}

		if (noteSkins.length > 1)
		{
			if (!noteSkins.contains(ClientPrefs.noteSkin))
				ClientPrefs.noteSkin = 'Default';

			var option:Option = new Option('Note Skin',
				"Choose the arrow texture used in every song.\nSkins are listed in images/noteSkins/list.txt.",
				'noteSkin',
				'string',
				'Default',
				noteSkins);
			addOption(option);
		}

		// Forever Engine parity: a global splash texture for every song that does not override it
		// with its own SONG.splashSkin. Like note skins, the list is data-driven and the option
		// only shows up when images/noteSplashes/list.txt exists; missing textures fall back.
		var splashSkins:Array<String> = ['Default'];
		try
		{
			if (Paths.fileExists('images/noteSplashes/list.txt', TEXT))
			{
				for (line in Paths.getTextFromFile('images/noteSplashes/list.txt').split('\n'))
				{
					var skinName:String = line.trim();
					if (skinName.length > 0 && !splashSkins.contains(skinName))
						splashSkins.push(skinName);
				}
			}
		}
		catch (e:Dynamic) {}

		if (splashSkins.length > 1)
		{
			if (!splashSkins.contains(ClientPrefs.noteSplashSkin))
				ClientPrefs.noteSplashSkin = 'Default';

			var option:Option = new Option('Note Splash Skin',
				"Choose the splash texture used in every song.\nSkins are listed in images/noteSplashes/list.txt.",
				'noteSplashSkin',
				'string',
				'Default',
				splashSkins);
			addOption(option);
		}

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashing',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Smooth Health Bar Movement',
			"If checked, the health bar glides to the real value instead of jumping there instantly.",
			'smoothHealth',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Smooth Health Bar Speed',
			"How fast the health bar catches up to the real health value.\n1x = default speed.",
			'smoothHealthSpeed',
			'float',
			1);
		option.displayFormat = '%vx';
		option.minValue = 0.1;
		option.maxValue = 3;
		option.changeValue = 0.1;
		option.scrollSpeed = 0.2;
		option.hiddenIf = function() return !ClientPrefs.smoothHealth;
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			'bool',
			true);
		addOption(option);

		// FPS Plus parity: Camera Zooms is the master switch, this picks how strong the beat pulse is.
		var option:Option = new Option('Camera Bop',
			"How much the camera pulses on beat hits.\n'Reduced' halves it, 'Off' disables it.",
			'camBopAmount',
			'string',
			'On',
			['On', 'Reduced', 'Off']);
		option.hiddenIf = function() return !ClientPrefs.camZooms;
		addOption(option);

		var option:Option = new Option('Pause Screen Song:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			'string',
			'Tea Time',
			['None', 'Breakfast', 'Tea Time']);
		addOption(option);
		option.onChange = onChangePauseMusic;
		
		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			'bool',
			true);
		addOption(option);
		#end

		#if desktop
		var option:Option = new Option('Discord Rich Presence',
			'Uncheck this to hide what you are playing\nfrom your Discord "Playing" status.',
			'discordRPC',
			'bool',
			true);
		option.onChange = onChangeDiscordRPC;
		addOption(option);
		#end

		var option:Option = new Option('Song Intro Credits',
			'If unchecked, hides the title, music creator and charter shown when a song starts.',
			'songIntroCredits',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Difficulty star from Marked Engine',
			'If unchecked, hides the rank star shown in the corner for the first seconds of each song.',
			'difficultyStar',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Icon Bounce',
			'Use Left/Right to change the health icon bounce style. The preview updates with your selection.',
			'iconbouncestyle',
			'string',
			'Psych Engine',
			IconBounce.STYLES.copy());
		option.displayFormat = ': %v';
		option.onChange = onIconBounceStyleChange;
		addOption(option);

		super();

		previewGroup = new FlxTypedGroup<FlxSprite>();
		add(previewGroup);

		previewLabel = new FlxText(845, 340, 350, '', 18);
		previewLabel.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		previewGroup.add(previewLabel);
		updatePreviewLabel();
		stylePrevButton = new FlxButton(820, 405, '<', function() cycleIconStyle(-1));
		styleNextButton = new FlxButton(1190, 405, '>', function() cycleIconStyle(1));
		add(stylePrevButton);
		add(styleNextButton);

		previewGroup.add(new FlxSprite(855, 480).makeGraphic(320, 22, FlxColor.BLACK));
		previewGroup.add(new FlxSprite(859, 484).makeGraphic(156, 14, 0xFFFF0000));
		previewGroup.add(new FlxSprite(1015, 484).makeGraphic(156, 14, 0xFF66FF33));

		previewOpponent = new HealthIcon('dad');
		previewOpponent.scale.set(0.5, 0.5);
		previewOpponent.updateHitbox();
		previewOpponent.setPosition(880, 370);
		previewGroup.add(previewOpponent);

		previewPlayer = new HealthIcon('bf', true);
		previewPlayer.scale.set(0.5, 0.5);
		previewPlayer.updateHitbox();
		previewPlayer.setPosition(1045, 370);
		previewGroup.add(previewPlayer);
		previewBounce = new IconBounce(previewPlayer, previewOpponent, 0.5);
		previewBounce.setStyle(Std.string(ClientPrefs.getGameplaySetting('iconbouncestyle', 'Psych Engine')));
		updatePreviewIconLayout();
		previewGroup.visible = false;
		stylePrevButton.visible = false;
		styleNextButton.visible = false;
	}

	override public function onOptionSelected(option:Option):Void
	{
		if (previewGroup == null || previewPlayer == null || previewOpponent == null) return;
		previewGroup.visible = option.name == 'Icon Bounce';
		if (stylePrevButton != null) stylePrevButton.visible = previewGroup.visible;
		if (styleNextButton != null) styleNextButton.visible = previewGroup.visible;
		if (previewGroup.visible)
		{
			// Trigger the first preview beat immediately when this option is selected.
			previewBeatTimer = getPreviewBeatSeconds();
			previewBeatCount = 0;
			previewBounce.setStyle(Std.string(ClientPrefs.getGameplaySetting('iconbouncestyle', 'Psych Engine')));
			updatePreviewIconLayout();
			updatePreviewLabel();
		}
	}

	function cycleIconStyle(change:Int):Void
	{
		cycleStringOption('Icon Bounce', change);
	}

	function onIconBounceStyleChange():Void
	{
		previewBeatTimer = getPreviewBeatSeconds();
		previewBeatCount = 0;
		if (previewBounce != null)
			previewBounce.setStyle(Std.string(ClientPrefs.getGameplaySetting('iconbouncestyle', 'Psych Engine')));
		updatePreviewIconLayout();
		updatePreviewLabel();
	}

	function getPreviewBeatSeconds():Float
	{
		return Math.max(0.05, Conductor.crochet / 1000);
	}

	function updatePreviewLabel():Void
	{
		if (previewLabel != null)
			previewLabel.text = 'ICON BOUNCE: ' + ClientPrefs.getGameplaySetting('iconbouncestyle', 'Psych Engine');
	}

	function updatePreviewIconLayout():Void
	{
		if (previewPlayer == null || previewOpponent == null || previewPlayer.scale == null || previewOpponent.scale == null) return;

		// Keep the preview icons on opposite sides of the preview bar. Their
		// centres stay anchored while they scale, so they never overlap each other.
		var opponentCenterX:Float = PREVIEW_HEALTH_BAR_X + 80;
		var playerCenterX:Float = PREVIEW_HEALTH_BAR_X + PREVIEW_HEALTH_BAR_WIDTH - 80;
		var iconCenterY:Float = PREVIEW_HEALTH_BAR_Y - 72.5;
		previewOpponent.x = opponentCenterX - (150 * previewOpponent.scale.x) / 2;
		previewPlayer.x = playerCenterX - (150 * previewPlayer.scale.x) / 2;
		previewOpponent.y = iconCenterY - (150 * previewOpponent.scale.y) / 2;
		previewPlayer.y = iconCenterY - (150 * previewPlayer.scale.y) / 2;
	}

	override function update(elapsed:Float)
	{
		var closingMenu:Bool = controls.BACK;
		super.update(elapsed);
		// BaseOptionsMenu closes the substate inside super.update(). Do not touch
		// preview sprites again during that same frame.
		if (closingMenu || previewGroup == null || !previewGroup.visible
			|| previewPlayer == null || previewOpponent == null
			|| previewPlayer.scale == null || previewOpponent.scale == null) return;

		previewBeatTimer += elapsed;
		var previewBeatSeconds:Float = getPreviewBeatSeconds();
		if (previewBeatTimer >= previewBeatSeconds)
		{
			previewBeatTimer %= previewBeatSeconds;
			previewBounce.beat(PREVIEW_HEALTH_PERCENT, Conductor.crochet, Conductor.bpm, 1, previewBeatCount);
			previewBeatCount++;
		}
		previewBounce.update(elapsed, Conductor.bpm, 1, PREVIEW_HEALTH_PERCENT);
		previewPlayer.updateHitbox();
		previewOpponent.updateHitbox();
		updatePreviewIconLayout();
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.pauseMusic)));

		changedMusic = true;
	}

	override function destroy()
	{
		if(changedMusic) FlxG.sound.playMusic(Paths.music('freakyMenu'));
		super.destroy();
	}

	#if desktop
	function onChangeDiscordRPC()
	{
		if (ClientPrefs.discordRPC && !DiscordClient.isInitialized)
			DiscordClient.initialize();
	}
	#end
}
