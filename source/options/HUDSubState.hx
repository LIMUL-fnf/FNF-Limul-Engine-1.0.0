package options;

class HUDSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'HUD';
		rpcTitle = 'HUD Settings Menu';

		var option:Option = new Option('Hide HUD',
			'If checked, hides most HUD elements.',
			'hideHud',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			'string',
			'Time Left',
			['Time Left', 'Time Elapsed', 'Song Name', 'Modern Time', 'Song Name + Time', 'Time Left (No Bar)', 'Time Elapsed (No Bar)', 'Modern Time (No Bar)', 'Disabled']);
		addOption(option);

		var option:Option = new Option('ScoreTxt Style',
			"How would you like your score text to look?",
			'scoreStyle',
			'string',
			'Psych Engine',
			['Psych Engine', 'VS Impostor', 'Kade Engine', 'Forever Engine', 'TGT V4', 'Dave Engine', 'Doki Doki+', 'Leather Engine', 'JS Engine', 'Vanilla']);
		addOption(option);

		var option:Option = new Option('Time Bar Style',
			"How would you like the Time Bar to look?",
			'timeBarStyle',
			'string',
			'Vanilla',
			['Vanilla', 'Kade Engine', 'VS Impostor', 'TGT V4', 'Dave Engine', 'Doki Doki+', 'Leather Engine', 'JS Engine']);
		addOption(option);

		var option:Option = new Option('Health Bar Style',
			"How would you like your Health Bar to look?",
			'healthBarStyle',
			'string',
			'Vanilla',
			['Vanilla', 'Dave Engine', 'Doki Doki+']);
		addOption(option);

		var option:Option = new Option('Watermark Style',
			"How would you like your watermark to look?",
			'watermarkStyle',
			'string',
			'Vanilla',
			['Vanilla', 'Dave Engine', 'JS Engine', 'Forever Engine', 'Hide']);
		addOption(option);

		var option:Option = new Option('Bot Txt Style',
			"How would you like the Botplay text to look?",
			'botTxtStyle',
			'string',
			'Vanilla',
			['Vanilla', 'JS Engine', 'Dave Engine', 'Doki Doki+', 'TGT V4', 'VS Impostor', 'Hide']);
		addOption(option);

		var option:Option = new Option('Botplay Watermark',
			"If unchecked, the '(Bot)' markers in the score and time text are hidden.",
			'botWatermark',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Strum Light Up Style',
			"How should the strums light up when hit?\n'BPM Based' holds the confirm animation for 1.5 steps.",
			'strumLitStyle',
			'string',
			'Full Anim',
			['Full Anim', 'BPM Based']);
		addOption(option);

		var option:Option = new Option('BF Icon Style',
			"How would you like your BF icon to look?",
			'bfIconStyle',
			'string',
			'Default',
			['Default', 'VS Nonsense V2', 'Leather Engine', 'Doki Doki+', "Mic'd Up", 'FPS Plus', "OS 'Engine'"]);
		addOption(option);

		var option:Option = new Option('Rating Style',
			"Which style for the rating popups would you like?",
			'ratingType',
			'string',
			'Default',
			['Default', 'Doki Doki+', 'FIRE IN THE HOLE', 'Kade', 'NMCW', 'TGT V4', 'VS Impostor', 'Yeahs']);
		addOption(option);

		var option:Option = new Option('Simple Rating Popups',
			"If checked, the rating popup becomes a text judge and the combo digits are hidden.",
			'simplePopups',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Show MS Popup',
			"If checked, every hit shows its millisecond offset near the score text.",
			'showMS',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Show Combo',
			"If checked, your current combo is shown in the score text.",
			'showComboInfo',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show NPS',
			"If checked, the score text shows your notes per second and the song's best value.",
			'showNPS',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Notes',
			"If unchecked, the notes will be invisible. You can still play them though!",
			'showNotes',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Ratings',
			"If unchecked, the rating sprite won't appear when you hit a note.",
			'ratingPopups',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Combo Numbers',
			"If unchecked, the combo counter won't pop up when you hit a note.",
			'comboPopups',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read",
			'comboStacking',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Score Text Zoom on Hit',
			"If unchecked, disables the Score text zooming\neverytime you hit a note.",
			'scoreZoom',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Health Bar Transparency',
			'How much transparent should the health bar and icons be.',
			'healthBarAlpha',
			'percent',
			1);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Botplay Text',
			'If unchecked, the BOTPLAY watermark is hidden even in botplay.',
			'botplayText',
			'bool',
			true);
		addOption(option);

		#if !mobile
		var option:Option = new Option('FPS Counter',
			'If unchecked, hides FPS Counter.',
			'showFPS',
			'bool',
			true);
		addOption(option);
		option.onChange = onChangeFPSCounter;

		var option:Option = new Option('Advanced FPS Info',
			'If checked, the FPS counter also shows the current state,\nsong data and conductor info.\nF3 in-game cycles: basic / advanced / hidden.',
			'advancedFPS',
			'bool',
			false);
		addOption(option);
		#end

		var option:Option = new Option('Show Combo Breaks',
			'If checked, the score text also shows how many\nrunning combos were broken by misses.',
			'showComboBreaks',
			'bool',
			false);
		addOption(option);

		super();
	}

	#if !mobile
	function onChangeFPSCounter()
	{
		if (Main.fpsVar != null)
			Main.fpsVar.visible = ClientPrefs.showFPS;
	}
	#end
}
