-- Limul Engine: difficulty RANK STAR -- global HUD script -- v3 2026-11-05
-- v3: the chart can set its own rank (Chart Editor -> Song tab -> "Difficulty Star").
--
-- WHAT THIS DRAWS
--   A star icon with the difficulty RANK number inside it, anchored to the bottom-right corner
--   for the first ~8 seconds of every song, exactly like MarkedEngine 3.8.1's
--   assets/data/<song>/DIFFICULTYRANK.lua:
--     star1 (ranks 1-3)   plain star, black number with a white outline
--     star2 + starFlame   (Erect / Nightmare / Fucked) flame-tier star, white number with a
--                         cyan outline, a looping fire sprite behind it and the 'light' whoosh
--   Timeline (Marked's numbers, unchanged): star fades in at 0.5 s over 0.5 s, the number
--   appears at 2 s (flame tier: number + flame snap in with the whoosh), the number fades at
--   7.5 s and the star/flame at 8 s. Downscroll moves the whole thing to the top-right corner
--   and turns the flame upside down (angle 190), same as Marked.
--   Replaces v1's bottom-left menudifficulties badge: the request was the corner star with the
--   number in it, not the story-menu icon.
--
-- WHY A GLOBAL SCRIPT AND A RANK *TABLE* INSTEAD OF MARKED'S PER-SONG FILE
--   Marked hand-writes the rank inside each song folder, and only 36 of its 41 folders carry the
--   file -- so five songs show no star at all. That gap is the "some songs have no difficulty
--   star" symptom, so the mechanic is keyed off the difficulty index instead: every song in every
--   week gets a star, and the RANKS table below is the one place to retune the numbers.
--   scripts/ under the preload library is read off the disk at PlayState.create()
--   (PlayState.hx:881-900), so this runs for every song and needs no rebuild to change.
--
-- GLOBALS THIS READS (all set per Lua state at FunkinLua.hx:136-206)
--   difficulty     PlayState.storyDifficulty, 0..5 = Easy, Normal, Hard, Erect, Nightmare, Fucked
--   songStarRank   the chart's own `starRank` key (Song.getStarRank), 0 when the chart has no
--                  override -- the Chart Editor's "Difficulty Star" box on the Song tab writes it,
--                  so a single song can outrank or under-rank its difficulty instead of inheriting
--                  the RANKS table below
--   hideHud        ClientPrefs.hideHud -- no HUD means no star either
--   difficultyStar ClientPrefs.difficultyStar -- Settings -> Visuals and UI -> "Difficulty star from
--                  Marked Engine"; false means onCreatePost builds nothing at all
--   downscroll     ClientPrefs.downScroll -- flips the corner
--   screenWidth    FlxG.width  / screenHeight FlxG.height (1280x720 logical game resolution)
--
-- ASSETS THIS NEEDS (installed 2026-11-04, md5 parity between the two trees)
--   images/star1.png  images/star2.png   plain 113x113 PNGs; Paths.returnGraphic (Paths.hx:478-501)
--                                        reads new keys straight off bin/assets/images, no rebuild
--   images/starFlame.png + .xml          sparrow atlas; the XML is only honoured from
--                                        bin/mods/images (getSparrowAtlas, Paths.hx:353-374), the
--                                        PNG may come from either -- both are there.
--   sounds/light.ogg                     flame-tier whoosh; returnSound also falls back to disk
--   fonts/combo.ttf                      Marked's number font; embedded only after the next
--                                        rebuild, so applyNumberFont() probes it and drops to
--                                        vcr.ttf (which is in the current build) when missing.
--
-- FAILURE MODES COVERED
--   Paths.image()/getSparrowAtlas() return null for a missing key and loadGraphic(null) throws
--   (Paths.hx:431-508). A throw inside a Lua callback cuts the rest of that callback off -- the
--   same way a missing sound used to kill whole stage functions here -- so flame, star and number
--   each run in their own pcall: a missing atlas costs the flame only, it never silences anyone
--   else's onCreatePost. Every shared tag (PlayState.modchartTimers / modchartTweens /
--   modchartSprites are one map for ALL scripts) carries the limulRank_ prefix, and
--   onTimerCompleted ignores tags that are not ours because callOnLuas broadcasts timers to
--   every script. camHUD owns the star, and limul-gameover-stage.lua switches camHUD off at
--   death, so the star disappears with the rest of the HUD and needs no cleanup of its own.
--
-- GEOMETRY (1280x720; the margins are the ones Marked's absolute coordinates imply)
--   star forced to 102x102 (= 113 * 0.9, via setGraphicSize so it is exact whatever the art is),
--   right margin 108, bottom margin 28 -> (1070, 590), Marked's coordinates to the pixel.
--   Downscroll: same x, y = 40. Number: a 200 px centre-aligned box over the star's centre,
--   y = star.y + 30 (the delta Marked uses in both scroll directions), size 37.
--   Flame: 109x199 frame box, scale 1.5, offset (-40, -150) from the star, (-45 when downscroll).
--   What shares that corner: healthBarBG/scoreTxt are centred (x 536..744) and timeTxt/timeBarBG
--   sit at the top in upscroll / bottom in downscroll, so the star never stacks on HUD text.
--   NOTE: at Marked's coordinates the star sits over the player's note columns for those 8
--   seconds -- that is how the reference looks. Nudge RIGHT_MARGIN / BOTTOM_MARGIN (or shrink
--   STAR_SIZE) to pull it into the true corner, or set STAR_ALPHA below 1 to keep it see-through.

local STAR_TAG   = 'limulRankStar'
local FLAME_TAG  = 'limulRankFlame'
local NUMBER_TAG = 'limulRankNumber'

local RIGHT_MARGIN   = 108
local BOTTOM_MARGIN  = 28
local TOP_MARGIN     = 40
local STAR_SIZE      = 102
local NUMBER_SIZE    = 37
local NUMBER_WIDTH   = 200
local NUMBER_Y_OFF   = 30
local STAR_ALPHA     = 1
local FLAME_SCALE    = 1.5
local FLAME_X_OFF    = -40
local FLAME_Y_UP     = -150
local FLAME_Y_DOWN   = -45
local FLAME_ANGLE_DN = 190

-- Rank shown per difficulty index (Easy, Normal, Hard, Erect, Nightmare, Fucked).
-- Anything FLAME_UPWARD or above gets star2 + flame, which is Marked's "rank > 10" rule.
-- A chart's own starRank (the Chart Editor's Difficulty Star box) replaces this number and
-- still goes through the same FLAME_UPWARD test, so overriding to 12+ gives the flame tier too.
local RANKS = {1, 2, 3, 12, 13, 14}
local FLAME_UPWARD = 11

local FONT_FIRST    = 'combo.ttf'
local FONT_FALLBACK = 'vcr.ttf'

local rank = 2
local flameTier = false
local haveFlame = false
local haveNumber = false

function onCreate()
	-- difficulty is set together with the other globals, right after this file is loaded
	-- (FunkinLua.hx:124-231), so it can only be read from a callback, never at file scope.
	local slot = 2
	if difficulty ~= nil then
		slot = math.floor(difficulty) + 1
	end
	if RANKS[slot] ~= nil then
		rank = RANKS[slot]
	else
		rank = 2 -- storyDifficulty outside CoolUtil.difficulties -> show 'normal' rather than nothing
	end
	-- LIMUL-STAR-RANK: the chart wins over the difficulty table when it says so. Compared as a
	-- number > 0 rather than `songStarRank ~= nil`, because an older executable never sets the
	-- global at all and a chart without an override reads back as 0 (Song.NO_STAR_RANK).
	if type(songStarRank) == 'number' and songStarRank > 0 then
		rank = math.floor(songStarRank)
	end
	flameTier = rank >= FLAME_UPWARD
end

-- combo.ttf is not in the built executable yet: FlxText.set_font (flixel 5.5.0,
-- flixel/text/FlxText.hx:655-676) keeps the untouched path in .font when the asset name cannot be
-- resolved, and swaps in the registered face name when it can. So a '/' coming back from
-- getTextFont means "the font is not embedded" and openfl would render a generic sans -- fall
-- back to vcr.ttf, the HUD font that is in every build. After the next rebuild combo.ttf
-- (assets/fonts/combo.ttf, embedded by project.xml:130) wins automatically.
local function applyNumberFont()
	setTextFont(NUMBER_TAG, FONT_FIRST)
	local applied = getTextFont(NUMBER_TAG)
	if applied == nil or string.find(tostring(applied), '/', 1, true) ~= nil then
		setTextFont(NUMBER_TAG, FONT_FALLBACK)
	end
end

function onCreatePost()
	-- Settings -> Visuals and UI -> "Difficulty star from Marked Engine". Compared against false
	-- rather than `not difficultyStar` on purpose: the global only exists from the build that adds
	-- the pref, and an older exe must still draw the star instead of silently going blank.
	if difficultyStar == false then
		return
	end

	if hideHud then
		return
	end

	local starX = screenWidth - RIGHT_MARGIN - STAR_SIZE
	local starY = screenHeight - BOTTOM_MARGIN - STAR_SIZE
	if downscroll then
		starY = TOP_MARGIN
	end

	-- The flame is added first so the star draws on top of it; Marked has to undo its own
	-- ordering with setObjectOrder, appending in the right order here needs no such call.
	if flameTier then
		haveFlame = pcall(function()
			makeAnimatedLuaSprite(FLAME_TAG, 'starFlame', starX + FLAME_X_OFF,
				starY + (downscroll and FLAME_Y_DOWN or FLAME_Y_UP))
			addAnimationByPrefix(FLAME_TAG, 'starFlame', 'fire loop full instance', 24, true)
			scaleObject(FLAME_TAG, FLAME_SCALE, FLAME_SCALE)
			setObjectCamera(FLAME_TAG, 'hud')
			setProperty(FLAME_TAG .. '.alpha', 0)
			if downscroll then
				setProperty(FLAME_TAG .. '.angle', FLAME_ANGLE_DN)
			end
			addLuaSprite(FLAME_TAG, true)
		end)
		if not haveFlame then
			debugPrint('limul-difficulty-star: no starFlame atlas, drawing the star without it')
		end
	end

	local haveStar = pcall(function()
		makeLuaSprite(STAR_TAG, flameTier and 'star2' or 'star1', starX, starY)
		-- Fixed box instead of scaleObject: the corner position stays exact even if the art
		-- is later swapped for a different size.
		setGraphicSize(STAR_TAG, STAR_SIZE, STAR_SIZE)
		setObjectCamera(STAR_TAG, 'hud')
		setProperty(STAR_TAG .. '.alpha', 0)
		addLuaSprite(STAR_TAG, true)
	end)
	if not haveStar then
		debugPrint('limul-difficulty-star: rank star art is missing, nothing drawn')
		return
	end

	haveNumber = pcall(function()
		makeLuaText(NUMBER_TAG, '' .. rank .. '', NUMBER_WIDTH,
			starX + (STAR_SIZE / 2) - (NUMBER_WIDTH / 2), starY + NUMBER_Y_OFF)
		setTextSize(NUMBER_TAG, NUMBER_SIZE)
		setTextAlignment(NUMBER_TAG, 'center')
		applyNumberFont()
		if flameTier then
			setTextColor(NUMBER_TAG, 'ffffff')
			setTextBorder(NUMBER_TAG, 2, '00AEFF')
		else
			setTextColor(NUMBER_TAG, '000000')
			setTextBorder(NUMBER_TAG, 3, 'FFFFFF')
		end
		setProperty(NUMBER_TAG .. '.alpha', 0)
		addLuaText(NUMBER_TAG)
	end)

	runTimer('limulRank_ready', 0.5)       -- star fades in
	runTimer('limulRank_wait2', 7.5)       -- number fades out
	runTimer('limulRank_wait', 8)          -- star + flame fade out
	if flameTier then
		runTimer('limulRank_pausefire', 2) -- number + flame snap in, whoosh
	else
		runTimer('limulRank_pause', 2)     -- number fades in
	end
end

-- onTimerCompleted is broadcast to every script in the song, so unknown tags stay out of the way.
function onTimerCompleted(tag, loops, loopsLeft)
	if hideHud or tag == nil or string.find(tag, 'limulRank_', 1, true) ~= 1 then
		return
	end

	if tag == 'limulRank_ready' then
		doTweenAlpha('limulRank_starIn', STAR_TAG, STAR_ALPHA, 0.5, 'linear')
	elseif tag == 'limulRank_pause' then
		if haveNumber then
			doTweenAlpha('limulRank_numIn', NUMBER_TAG, 1, 0.5, 'linear')
		end
	elseif tag == 'limulRank_pausefire' then
		if haveNumber then
			setProperty(NUMBER_TAG .. '.alpha', 1)
		end
		if haveFlame then
			setProperty(FLAME_TAG .. '.alpha', 1)
		end
		-- pcall: Paths.sound returns null when light.ogg is gone and FlxSound.loadEmbedded(null)
		-- throws, which is the failure that used to cut whole Lua functions off in this engine.
		pcall(function()
			playSound('light', 0.7)
		end)
	elseif tag == 'limulRank_wait2' then
		if haveNumber then
			doTweenAlpha('limulRank_numOut', NUMBER_TAG, 0, 0.5, 'linear')
		end
	elseif tag == 'limulRank_wait' then
		doTweenAlpha('limulRank_starOut', STAR_TAG, 0, 0.5, 'linear')
		if haveFlame then
			doTweenAlpha('limulRank_flameOut', FLAME_TAG, 0, 0.5, 'linear')
		end
	end
end
