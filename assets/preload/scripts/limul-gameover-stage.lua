-- Limul Engine: ekran smierci (global script) -- v3 2026-11-02, CZARNE TLO
--
-- v3 CO SIE ZMIENILO: smierc ma byc CZARNA (czarne tlo + trup + RETRY + rekwizyty smierci z
-- Lua, jak w oryginale Weekend 1). Wczesniejsza naprawa v1/v2 ('widoczny stage',
-- persistentDraw=true) robila to, o co prosilem wowczas, ale to byl zly strzal -- user chcial
-- czern, nie ulice. persistentDraw wrocil do false (= stock), a czern robi jedna plansza
-- wlasciwie umieszczona w GameOverSubstate. Caly sens naprawy jest w 'GDZIE TRAFIA
-- ADDLUASPRITE' ponizej.
--
-- DLACZEGO WOGOLE ISTNIAL TEN PLIK (v1, historia):
-- PlayState.doDeathCheck() (PlayState.hx:3565) wlacza persistentUpdate=false i
-- persistentDraw=false, a flixel w FlxState.draw() ma 'if (persistentDraw || subState == null)
-- super.draw();' a dopiero pozniej 'if (subState != null) subState.draw();', wiec dopoki gra
-- trzyma substate, PlayState nie rysuje ZADNEGO ze swoich memberow: znika stage, dad, gf,
-- kreski dokladane przez Lua i HUD. Zostaje only substate, czyli trup na tle koloru kamery
-- -- stad 'szare tlo'. To nie jest regresja Limula - te same dwie linia sa w czystym
-- Psych 0.6.3, 1.0.4 i H-Slice.
--
-- GDZIE TRAFIA ADDLUASPRITE -- v3, TO TRZEBA ZROZUMIEC ZEBY TEGO NIE 'POPRAWIC' Z POWROTEM:
-- FunkinLua.hx:3311 `getInstance() = PlayState.instance.isDead ? GameOverSubstate.instance :
-- PlayState.instance`. A `isDead = true` (PlayState.hx:3594) wykonuje sie PRZED onGameOverStart,
-- bo flixel 5.5 nie otwiera substate'u synchronicznie: FlxState.openSubState() (FlxState.hx:104)
-- tylko stawia _requestSubStateReset, a tryUpdate() odpala resetSubState() ->
-- GameOverSubstate.create() -> callOnLuas('onGameOverStart') dopiero PO powrocie z
-- update(elapsed) -- w tej samej klatce, ale juz po line 3594, czyli gdy isDead == true.
-- W onGameOverStart kazdy addLuaSprite idzie wiec do GameOverSubstate, NIE do PlayState:
--   front=true  -> substate.add()                      -> plansza jest OSTATNIM memberem,
--                 przykrywa trup i wbudowany w niego napis RETRY. Czarno, ale bez ciala.
--   front=false -> substate.insert(indexOf(boyfriend))  -> plansza jest POD trupem i nad
--                 calym swiatem rozgrywki (PlayState i tak nie rysuje). Dokladnie o to chodzi.
-- Kolejnosc w substate'cie po tej naprawie: [czern, kreski piosenki, trup]. Globalne skrypty
-- laduja sie przed skryptami piosenki (PlayState.hx:871-899 vs 1262-1290), a
-- FileSystem.readDirectory na NTFS zwraca nazwy alfabetycznie, wiec 'limul-gameover-stage.lua'
-- idzie przed 'pico-death.lua'; '2hot death.lua' to skrypt piosenki, wiec jest dopiero za nimi.
-- Noz Nene (front=true -> add) i wybuch 2 Hot (front=false -> insert przed trupem) dolaczaja
-- sie PO naszej czarnej planszy, czyli rysuja sie nad nia.
--
-- KOLEJNOSC RYSOWANIA jest wiec dobra bez zadnych sztuczek: najpierw (niewidoczny) swiat
-- PlayState, potem subState.draw() = czern, potem rekwizyty smierci, potem trup z RETRY.
--
-- camHUD to CALY UI rozgrywki (PlayState wkłada na niego strumy, nody, health bar,
-- ikony, score, watermark, timebar), wiec jedna linia zdejmuje go z ekranu smierci.
--
-- Chowanie 'boyfriend' to ten zywy z rozgrywki, NIE trup: GameOverSubstate.new()
-- w tym buildzie zawsze buduje wlasnego Boyfriend'a (nie ma opcji przjejcia
-- playStateBoyfriend), wiec trup nigdy nie zniknie razem z nim.
--
-- Rekwizyty smierci dolozane przez Lua w onGameOverStart sa memberami SUBSTATE'u (patrz
-- wyzej), wiec sa widoczne nad czernia bez persistentDraw: noz Nene z pico-death.lua, wybuch i
-- wlasna czarna zarzosta z '2hot death.lua'. W oryginale Weekend 1 smierc to wlasnie czern +
-- rekwizyt + trup (2 Hot = cutscena na czarno, Satin Panties = noz).
--
-- onGameOverStart jest wolane z GameOverSubstate.create() PRZED super.create(),
-- czyli przed pierwszym drawem - nie ma jednej szarej klatki przejsciowej.
--
-- Po 'RETRY' PlayState laduje sie od nowa i flagi wracaja do domyslnych; po 'BACK'
-- idziemy do menu. Nic nie trzeba odwac.
--
-- v2 (2026-11-02), dwie rzeczy ktore zostaja jako pas (maja sens nawet przy persistentDraw=false
-- -- chroni, gdyby ktorys skrypt przywrocil rysowanie swiata):
-- 1) Zawodnicy umieraja w srodku kombo. Character.update() siedzi w zamrozonym PlayState,
--    wiec rama ciosu / bloku / obcia wisi na ekranie smierci do konca - w Blazin to wlasnie
--    wyglada jak "postacie obrywaja, atakuja i blokuja jednoczesnie". Dostaja z powrotem
--    klatke 0 'idle' (getByName chroni def-y bez tej animacji).
-- 2) FlxTimer kreci sie na FlxTimer.globalManager - to plugin flixla aktualizowany przez
--    FlxGame, NIE przez PlayState.update. Inaczej mowiac: runTimer() z Lua tyka rowniez
--    podczas substate'u smierci. Niepilnowana puszka/pocisk z notetype'ow Weekend 1
--    dolatuje wiec NA ekranie smierci: huk, dzwiek, zdrowie schodzi i oba zawodniki
--    dostaja animacje trafienia i ataku. Shimy weekend-1-{kickcan,kneecan,lightcan,
--    firegun,cockgun}.lua maja od teraz 'if inGameOver then return end' w
--    onTimerCompleted (to odcina caly lancuch), a ponizen cancelTimer + ukrycie spritow
--    to pas bezpieczeństwa dla tego, co juz leci.

function onGameOverStart()
	runHaxeCode([[
		// v3: stays false (stock). Death props are GameOverSubstate members now, so they draw
		// without it, and keeping the frozen world painted under an opaque black is pure cost.
		game.persistentDraw = false;
		if (game.camHUD != null) game.camHUD.visible = false;
		if (game.boyfriend != null) game.boyfriend.visible = false;

		// Fighters back to a neutral pose; see note (1) above.
		if (game.dad != null) {
			if (game.dad.animation.getByName('idle') != null) game.dad.playAnim('idle', true);
			game.dad.specialAnim = false;
		}
		if (game.gf != null) {
			if (game.gf.animation.getByName('idle') != null) game.gf.playAnim('idle', true);
			game.gf.specialAnim = false;
		}

		// One shared tag per projectile kind (custom_notetypes/weekend-1-kickcan.lua),
		// and they are PlayState members: with persistentDraw they would hang in the air.
		var limulCanSpr = game.modchartSprites.get('limulCan');
		if (limulCanSpr != null) limulCanSpr.visible = false;
		var limulBulletSpr = game.modchartSprites.get('limulBullet');
		if (limulBulletSpr != null) limulBulletSpr.visible = false;
		var limulSparkSpr = game.modchartSprites.get('limulSpark');
		if (limulSparkSpr != null) limulSparkSpr.visible = false;
		var limulBoomSpr = game.modchartSprites.get('limulBoom');
		if (limulBoomSpr != null) limulBoomSpr.visible = false;
		var limulMuzzleSpr = game.modchartSprites.get('limulMuzzle');
		if (limulMuzzleSpr != null) limulMuzzleSpr.visible = false;
	]])

	-- v3 (2026-11-02): EKRAN SMIERCI JEST CZARNY. Naglowek pliku ma calne uzasadnienie
	-- ('GDZIE TRAFIA ADDLUASPRITE'); tu tylko trzy rzeczy warte powtorzenia przy tej quadzie:
	-- 1) front=false, NIE true -- front=true wrzucilby czern na OSTATNIEGO membera substate'u,
	--    czyli NA trup i napis RETRY. front=false = insert(indexOf(boyfriend)) = pod trupem.
	-- 2) scrollFactor (0,0) przykleja plansze do ekranu: najazd kamery na trup i cameraShake
	--    nie odkryja jej krawedzi.
	-- 3) 512 px skalowane x30 = 15360 px, czyli pewne przykrycie 1280x720 przy kazdym zoomie
	--    >= 0.085 (kamera smierci ~1). Skala to tylko transform na jednej quadzie, bitmapa
	--    wciaz ma 512x512, więc koszt jest identyczny jak przy x11, a margines duzo wiekszy.
	makeLuaSprite('limulGameoverBlack', 'empty', -200, -200)
	makeGraphic('limulGameoverBlack', 512, 512, '000000')
	scaleObject('limulGameoverBlack', 30, 30)
	setScrollFactor('limulGameoverBlack', 0, 0)
	addLuaSprite('limulGameoverBlack', false)

	-- see note (2): belt to the shims' brace.
	cancelTimer('limulCan_drop')
	cancelTimer('limulCan_impact')
	cancelTimer('limulCan_gone')
	cancelTimer('limulBullet_land')
	cancelTimer('limulBullet_gone')
	cancelTimer('limulSpark_kill')
	cancelTimer('limulBoom_kill')
	cancelTimer('limulMuzzle_kill')

	-- DIAGNOSTYKA (do usuniecia po potwierdzeniu). Nie odpalam gry -- jedno twoje deda wystarcza,
	-- zeby bin/mods/limul-gameover.log powiedzial wiecej niz kazda analiza statyczna:
	--   black >= 0 i black < corpse ... czern jest w substate'cie POD trupem = czarny ekran,
	--                                    cialo i RETRY widoczne (to jest stan docelowy)
	--   black = -1 ..................... plansza nie wpadla do substate'u, mimo ze naglowek tak
	--                                    liczyl -- wtedy wgramy ja tam recznie, bez zgadywania
	--   corpse = -99 ................... game.subState byl null w tej klatce
	-- Limul Engine: this build has no getVar()/setVar() on the LUA side -- FunkinLua.hx only
	-- injects them into the hscript interpreter (FunkinLua.hx:3436), and setVar() writes into
	-- PlayState.instance.variables, not into Lua globals -- so the old getVar() reads threw
	-- "attempt to call a nil value (global 'getVar')" on every death and cut onGameOverStart
	-- off mid-function. runHaxeCode returns the value of the last hscript expression, and
	-- Strings are one of the types it marshals back (FunkinLua.hx:912), so the probe reports
	-- through its return value instead.
	local probe = runHaxeCode([[
		var blackSpr = game.modchartSprites.get('limulGameoverBlack');
		var bi = -1;
		var ci = -99;
		var sub = game.subState;
		if (sub != null) {
			var m = sub.members;
			var i = 0;
			while (i < m.length) {
				if (m[i] == blackSpr) bi = i;
				if (m[i] == sub.boyfriend) ci = i;
				i = i + 1;
			}
		}
		'black=' + bi + ' corpse=' + ci;
	]])
	saveFile('limul-gameover.log', 'song=' .. tostring(songName)
		.. ' ' .. tostring(probe)
		.. ' created=' .. tostring(luaSpriteExists('limulGameoverBlack'))
		.. ' persistentDraw=' .. tostring(getProperty('persistentDraw')))
end
