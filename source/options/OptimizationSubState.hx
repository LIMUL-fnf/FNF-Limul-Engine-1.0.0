package options;

// Port of JS Engine's Optimization tab, limited to the switches this engine honours.
class OptimizationSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Optimization';
		rpcTitle = 'Optimization Settings Menu';

		var option:Option = new Option('Chars & BG',
			'If unchecked, gameplay will only show the HUD.',
			'charsAndBG',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Enable GC',
			"If checked, the game will be allowed to garbage collect, reducing RAM usage.\nIf you experience memory leaks, turn this on,\nand if you experience lag with it on then turn it off.",
			'enableGC',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Max Notes On Screen',
			'Limits how many notes are visible on screen at once. Notes still spawn on time and remain hittable. Set to 0 for no limit.',
			'maxNotesOnScreen',
			'int',
			0);
		addOption(option);
		option.minValue = 0;
		option.maxValue = 99999;
		option.scrollSpeed = 2000;
		option.displayFormat = '%v Notes';

		var option:Option = new Option('Max Note Splashes Per Second',
			'Limits how many note splashes can appear each second. Set to 0 for no limit.',
			'maxNoteSplashesPerSecond',
			'int',
			16);
		addOption(option);
		option.minValue = 0;
		option.maxValue = 99999;
		option.scrollSpeed = 2000;
		option.displayFormat = '%v / sec';

		var option:Option = new Option('Light Opponent Strums',
			"If unchecked, the opponent's strums won't light up when he hits a note.",
			'opponentLightStrum',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Light Player Strums',
			"If unchecked, your strums won't light up when you hit a note.",
			'playerLightStrum',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Automatic Note Spawn Time',
			'If checked, notes spawn earlier on slower song speeds\ninstead of using the Note Spawn Time multiplier.',
			'dynamicSpawnTime',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Note Spawn Time',
			'How early notes are spawned, as a multiplier.\nHigher values spawn notes earlier (more on screen).',
			'noteSpawnTime',
			'float',
			1);
		addOption(option);
		option.scrollSpeed = 2;
		option.minValue = 0.01;
		option.maxValue = 10;
		option.changeValue = 0.1;
		option.decimals = 2;
		option.displayFormat = '%vX';

		var option:Option = new Option('Opponent Note Splashes',
			'If checked, the opponent also gets note splashes on hits.',
			'oppNoteSplashes',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Opponent Note Opacity',
			'How transparent the opponent notes are. 100% is fully opaque.',
			'oppNoteAlpha',
			'percent',
			0.65);
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.05;
		option.decimals = 2;

		var option:Option = new Option('Light Bot Strums',
			'If unchecked, strums stop lighting up while Botplay is active.',
			'botLightStrum',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Disable onSpawnNote Lua Calls',
			'If checked, the game will not call onSpawnNote when a note is spawned.\nCustom notetypes and scripts that rely on it will stop working.',
			'noSpawnFunc',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Disable Note Hit Lua Calls',
			'If checked, the game will not call goodNoteHit/opponentNoteHit.\nWeekend 1 mechanics (spray can, gun) stop working - leave this off unless you need the speed.',
			'noHitFuncs',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Disable Skip Lua Calls',
			'If checked, the game will not call goodNoteSkip/opponentNoteSkip\nfor notes that were auto-hit while loading.',
			'noSkipFuncs',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Even LESS Botplay Lag',
			'Reduce Botplay lag even further (no rating popups while the bot plays).',
			'lessBotLag',
			'bool',
			false);
		addOption(option);

		super();
	}
}
