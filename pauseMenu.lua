--[[
	pauseMenu.lua by Marioman2007, version 1.2
	Credits to Rednaxela for the base of this script:
	https://discord.com/channels/215661302692052992/215662742520987649/931091424756240384
]]

local textplus = require("textplus")
local pauseMenu = {}

local pauseOpacity = 0
local confirmOpacity = 0
local lastVolume = 64
local screenOpa = 0
local screenOpa2 = 0
local isOpen = false
local prevMusic
local prevPos

local function preventJumps()
	if isOverworld then
		player:mem(0x17A, FIELD_BOOL, false)
	else
		player:mem(0x11E, FIELD_BOOL, false)
	end
end

local function changePower(p, x)
	p.powerup = x
	p.forcedState = 0
end

local function manageForcedState(p) -- try restarting/exiting without this while in a forcedState
	if p.forcedState == FORCEDSTATE_POWERUP_BIG or p.forcedState == FORCEDSTATE_POWERDOWN_FIRE or p.forcedState == FORCEDSTATE_POWERDOWN_ICE then
		changePower(p, PLAYER_BIG)
	elseif p.forcedState == FORCEDSTATE_POWERDOWN_SMALL then
		changePower(p, PLAYER_SMALL)
	elseif p.forcedState == FORCEDSTATE_POWERUP_FIRE then
		changePower(p, PLAYER_FIREFLOWER)
	elseif p.forcedState == FORCEDSTATE_POWERUP_LEAF then
		changePower(p, PLAYER_LEAF)
	elseif p.forcedState == FORCEDSTATE_POWERUP_TANOOKI then
		changePower(p, PLAYER_TANOOKIE)
	elseif p.forcedState == FORCEDSTATE_POWERUP_HAMMER then
		changePower(p, PLAYER_HAMMER)
	elseif p.forcedState == FORCEDSTATE_POWERUP_ICE then
		changePower(p, PLAYER_ICE)
	end
end

local function getSuitableOptions()
    if isOverworld or Level.filename() == pauseMenu.mapLevelFilename then
        return pauseMenu.mapOptions
    else
        return pauseMenu.options
    end
end

local function getSuitableBox()
    if isOverworld or Level.filename() == pauseMenu.mapLevelFilename then
        return pauseMenu.mapBoxSettings
    else
        return pauseMenu.levelBoxSettings
    end
end

function pauseMenu.onPause(eventToken)
	if not eventToken.cancelled then -- Just in case make sure this event isn't already flagged as cancelled
		eventToken.cancelled = true -- Prevent normal pausing
		SFX.play(pauseMenu.openCloseSFX)
		pauseMenu.pauseActive = true -- Set your own pause state
		Misc.pause() -- Pause the game via Lua
		if not isOverworld then
			prevPos = Audio.MusicGetPos()
			prevMusic = Section(player.section).music
			Audio.MusicFadeOut(player.section, 5)
		end
		lastVolume = Audio.MusicVolume()
	end
end

function pauseMenu.onDraw()
	if pauseMenu.pauseActive and not Misc.isPausedByLua() then
		pauseMenu.pauseActive = false -- If other code unpaused us, well, clear our pause state I guess
	end

	if pauseMenu.pauseActive and pauseOpacity >= 1 and not isOpen then
		if not isOverworld then
			Audio.MusicChange(player.section, pauseMenu.pausedMusic, -1)
		end
		isOpen = true
	end

	local formattedText = textplus.parse(getSuitableOptions()[pauseMenu.pauseSelection].text, {font = pauseMenu.pauseFont})
	local confirmText = textplus.layout(formattedText, 568)

	-- If our pause state is active, draw accordingly
	if pauseMenu.pauseActive then
		pauseOpacity = math.min(pauseOpacity + pauseMenu.fadeSpeed, 1)
		screenOpa = math.min(screenOpa + pauseMenu.fadeSpeed, 0.5)
	else
		pauseOpacity = math.max(pauseOpacity - pauseMenu.fadeSpeed, 0)
		screenOpa = math.max(screenOpa - pauseMenu.fadeSpeed, 0)
	end

	if pauseOpacity > 0 then
		Graphics.drawScreen{color=Color.black..screenOpa, priority = pauseMenu.leastPriority}
		Graphics.drawBox{texture = getSuitableBox().boxImg, x = 400 + getSuitableBox().boxOffsets.x, y = 300 + getSuitableBox().boxOffsets.y, centered = true, color = Color.white..pauseOpacity, priority = pauseMenu.leastPriority + 0.1}

		local sinMov = math.sin(lunatime.drawtick() * 0.2) * 4

		Graphics.drawImageWP(
			pauseMenu.selectorImg, 320 + getSuitableBox().selOffsets.x + sinMov, 228 + 32 + 32 * (pauseMenu.pauseSelection - 1) + getSuitableBox().selOffsets.y, 0, 0,
			pauseMenu.selectorImg.width, pauseMenu.selectorImg.height, pauseOpacity, pauseMenu.leastPriority + 0.3
		)

		for i = 1 , #getSuitableOptions() do
			textplus.print{text = getSuitableOptions()[i].name, x = 320 + getSuitableBox().textOffsets.x, y = 228 + 32 + 32 * (i - 1) + getSuitableBox().textOffsets.y, font = pauseMenu.pauseFont, priority = pauseMenu.leastPriority + 0.2, color = Color(pauseOpacity,pauseOpacity,pauseOpacity,pauseOpacity)}
		end

		if pauseMenu.confirmActive then
			confirmOpacity = math.min(confirmOpacity + pauseMenu.fadeSpeed, 1)
			screenOpa2 = math.min(screenOpa2 + pauseMenu.fadeSpeed, 0.5)
		else
			confirmOpacity = math.max(confirmOpacity - pauseMenu.fadeSpeed, 0)
			screenOpa2 = math.max(screenOpa2 - pauseMenu.fadeSpeed, 0)
		end

		if confirmOpacity > 0 then
			Graphics.drawScreen{color=Color.black..screenOpa2, priority = pauseMenu.leastPriority+0.499}
			Graphics.drawBox{texture = getSuitableBox().confirmImg, x = 400 + getSuitableBox().confirmOffsets.x, y = 300 + getSuitableBox().confirmOffsets.y, centered = true, color = Color.white..confirmOpacity, priority = pauseMenu.leastPriority + 0.5}
			textplus.render{x = getSuitableBox().cTextOffsets.x, y = getSuitableBox().cTextOffsets.y, layout = confirmText, color = Color(confirmOpacity,confirmOpacity,confirmOpacity,confirmOpacity), priority = pauseMenu.leastPriority + 0.6}

			for i = 1, 2 do
				textplus.print{text = pauseMenu.YesNoStuff[i].name, x = pauseMenu.YesNoStuff[i].x, y = pauseMenu.YesNoStuff[i].y, font = pauseMenu.pauseFont, priority = pauseMenu.leastPriority + 0.7, color = Color(confirmOpacity,confirmOpacity,confirmOpacity,confirmOpacity)}
			end

			Graphics.drawImageWP(
				pauseMenu.selectorImg, pauseMenu.YesNoStuff[pauseMenu.confirmSelection].x - 24 + sinMov, pauseMenu.YesNoStuff[pauseMenu.confirmSelection].y, 0, 0,
				pauseMenu.selectorImg.width, pauseMenu.selectorImg.height, confirmOpacity, pauseMenu.leastPriority + 0.9
			)
		end
	end
end

function pauseMenu.onInputUpdate()
	if pauseMenu.pauseActive and not Misc.isPausedByLua() then
		pauseMenu.pauseActive = false -- If other code unpaused us, well, clear our pause state I guess
	end

	if not pauseMenu.pauseActive and pauseOpacity <= 0 then
		pauseMenu.pauseSelection = 1
	elseif pauseMenu.pauseActive and pauseOpacity >= 0 then
		Audio.MusicVolume(pauseMenu.pausedMusicVolume)
	end

	if not pauseMenu.confirmActive and confirmOpacity <= 0 then
		pauseMenu.confirmSelection = 1
	end

	-- If our pause state is active, handle input
	if pauseMenu.pauseActive then
		if not pauseMenu.confirmActive then
			if player.rawKeys.up == KEYS_PRESSED then
				pauseMenu.pauseSelection = pauseMenu.pauseSelection - 1
				SFX.play(pauseMenu.chooseSFX)
			elseif player.rawKeys.down == KEYS_PRESSED then
				pauseMenu.pauseSelection = pauseMenu.pauseSelection + 1
				SFX.play(pauseMenu.chooseSFX)
			elseif player.rawKeys.run == KEYS_PRESSED or player.rawKeys.pause == KEYS_PRESSED then
				pauseMenu.Resume()
			end
		elseif pauseMenu.confirmActive then
			if player.rawKeys.left == KEYS_PRESSED then
				pauseMenu.confirmSelection = pauseMenu.confirmSelection - 1
				SFX.play(pauseMenu.chooseSFX)
			elseif player.rawKeys.right == KEYS_PRESSED then
				pauseMenu.confirmSelection = pauseMenu.confirmSelection + 1
				SFX.play(pauseMenu.chooseSFX)
			elseif player.rawKeys.run == KEYS_PRESSED then
				pauseMenu.removeConfirm()
			end
		end

		if player.rawKeys.jump == KEYS_PRESSED then
			if not pauseMenu.confirmActive then
				pauseMenu.ConfirmBox()
			elseif pauseMenu.confirmActive then
				if pauseMenu.confirmSelection == 1 then
					getSuitableOptions()[pauseMenu.pauseSelection].action()
					pauseMenu.confirmSelection = 1
				elseif pauseMenu.confirmSelection == 2 then
					pauseMenu.removeConfirm()
				end
			end
		end
	end

	-- loop the selections
	if pauseMenu.pauseSelection < 1 then
		pauseMenu.pauseSelection = #getSuitableOptions()
	elseif pauseMenu.pauseSelection > #getSuitableOptions() then
		pauseMenu.pauseSelection = 1
	end

	if pauseMenu.confirmSelection < 1 then
		pauseMenu.confirmSelection = 2
	elseif pauseMenu.confirmSelection > 2 then
		pauseMenu.confirmSelection = 1
	end
end

-- This function is for testing in editor, press ctrl key of the keyboard
function pauseMenu.onKeyboardPressDirect(keyCode, repeated, char)
    if Misc.inEditor() and keyCode == VK_CONTROL and not repeated then
		if not pauseMenu.confirmActive then
			if not pauseMenu.pauseActive then
				SFX.play(pauseMenu.openCloseSFX)
				pauseMenu.pauseActive = true -- Set your own pause state
				Misc.pause() -- Pause the game via Lua
				if not isOverworld then
					prevPos = Audio.MusicGetPos()
					prevMusic = Section(player.section).music
					Audio.MusicFadeOut(player.section, 5)
				end
				lastVolume = Audio.MusicVolume()
			elseif pauseMenu.pauseActive then
				pauseMenu.Resume()
			end
		end
    end
end

-- Register events
function pauseMenu.onInitAPI()
	registerEvent(pauseMenu, "onPause")
	registerEvent(pauseMenu, "onDraw")
	registerEvent(pauseMenu, "onInputUpdate")
	registerEvent(pauseMenu, "onKeyboardPressDirect")
end

function pauseMenu.ConfirmBox()
	if getSuitableOptions()[pauseMenu.pauseSelection].confirm then
		if not pauseMenu.confirmActive then
			pauseMenu.confirmActive = true
			SFX.play(pauseMenu.confirmationSFX)
		end

		confirmText = getSuitableOptions()[pauseMenu.pauseSelection].text
	else
		getSuitableOptions()[pauseMenu.pauseSelection].action()
	end
end

function pauseMenu.removePause()
	Misc.unpause()
	isOpen = false
	pauseMenu.pauseActive = false -- Close the menu
	Audio.MusicVolume(lastVolume)
	if not isOverworld then 
		Audio.MusicChange(player.section, prevMusic, -1)
		Audio.MusicSetPos(prevPos)
		prevMusic = nil
		prevPos = nil
	end
end

function pauseMenu.Resume()
	pauseMenu.removePause()
	preventJumps()
	SFX.play(pauseMenu.openCloseSFX)
end

function pauseMenu.Restart()
	Graphics.drawScreen{color=Color.black, priority = 100}
	pauseMenu.removePause()
	preventJumps()
	for _, p in ipairs(Player.get()) do
		manageForcedState(p)
	end
	Level.load(Level.filename())
end

function pauseMenu.ExitLevel()
	Graphics.drawScreen{color=Color.black, priority = 100}
	pauseMenu.removePause()
	preventJumps()
	for _, p in ipairs(Player.get()) do
		manageForcedState(p)
	end
	Level.exit()
end

function pauseMenu.Save()
	pauseMenu.removePause()
	Misc.saveGame()
	preventJumps()
	SFX.play(pauseMenu.saveSFX)
end

function pauseMenu.Quit()
	Graphics.drawScreen{color=Color.black, priority = 100}
	for _, p in ipairs(Player.get()) do
		manageForcedState(p)
	end
	Misc.saveGame()
	Misc.exitEngine()
end

function pauseMenu.removeConfirm()
	pauseMenu.confirmActive = false
	SFX.play(pauseMenu.openCloseSFX)
end

pauseMenu.leastPriority = 6 -- least priority of the pause menu, the menu will be drawn at priority between (pauseMenu.leastPriority) and (pauseMenu.leastPriority + 0.9)
pauseMenu.mapLevelFilename = "map.lvlx" -- filename of the level that is used for smwMap
pauseMenu.pauseFont = textplus.loadFont("pauseFont.ini")
pauseMenu.fadeSpeed = 0.075
pauseMenu.pausedMusicVolume = 32
pauseMenu.pausedMusic = "" -- not for vanilla world maps

-- SFXs can be a number for basegame SFX or a string filename
pauseMenu.openCloseSFX = 30
pauseMenu.chooseSFX = 26
pauseMenu.confirmationSFX = 47
pauseMenu.saveSFX = 58

pauseMenu.selectorImg = Graphics.loadImageResolved("pauseMenu/selector.png")
pauseMenu.pauseActive = false
pauseMenu.pauseSelection = 1
pauseMenu.confirmActive = false
pauseMenu.confirmSelection = 1

pauseMenu.YesNoStuff = {
	{name = "Yes", x = 290, y = 321},
	{name = "No",  x = 476, y = 321}
}

pauseMenu.options = {
	{name = "Resume",     action = pauseMenu.Resume,    confirm = false, text = "lol"},
	{name = "Restart",    action = pauseMenu.Restart,   confirm = true,  text = "This will reload the level and progress will be lost."},
	{name = "Exit Level", action = pauseMenu.ExitLevel, confirm = true,  text = "This will exit the level and progress will be lost."},
	{name = "Quit Game",  action = pauseMenu.Quit,      confirm = true,  text = "This will quit the game and progress will be lost."}
}

pauseMenu.mapOptions = {
	{name = "Resume",    action = pauseMenu.Resume, confirm = false, text = "lol"},
	{name = "Save Game", action = pauseMenu.Save,   confirm = false, text = "lol"},
	{name = "Quit Game", action = pauseMenu.Quit,   confirm = true,  text = "This will quit the game and progress will be saved."}
}

pauseMenu.levelBoxSettings = {
	boxImg         = Graphics.loadImageResolved("pauseMenu/boxLevel.png"),
	confirmImg     = Graphics.loadImageResolved("pauseMenu/boxConfirm.png"),
	boxOffsets     = {x = 0, y = 0},
	confirmOffsets = {x = 0, y = 0},
	textOffsets    = {x = 0, y = -16},
	cTextOffsets   = {x = 116, y = 278},
	selOffsets     = {x = -24, y = -16},
}

pauseMenu.mapBoxSettings = {
	boxImg         = Graphics.loadImageResolved("pauseMenu/boxMap.png"),
	confirmImg     = Graphics.loadImageResolved("pauseMenu/boxConfirm.png"),
	boxOffsets     = {x = 0, y = 0},
	confirmOffsets = {x = 0, y = 0},
	textOffsets    = {x = 0, y = 0},
	cTextOffsets   = {x = 116, y = 278},
	selOffsets     = {x = -24, y = 0},
}

pauseMenu.TYPE_MAP = 0
pauseMenu.TYPE_LVL = 1

function pauseMenu.addOption(type, config)
	config = config or {}
	config.name = config.name or "Un-Defined"
	config.action = config.action or function() end
	if config.confirm == nil then config.confirm = false end
	config.text = config.text or "Hi lol how u doin"

	if type == pauseMenu.TYPE_MAP then
		table.insert(pauseMenu.mapOptions, config)
	elseif type == pauseMenu.TYPE_LVL then
		table.insert(pauseMenu.options, config)
	end
end

return pauseMenu