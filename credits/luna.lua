local textplus = require("textplus")
local hudoverride = require("HUDOverride")
local outroimg = Graphics.loadImageResolved("credits/smbx13outro.png")

local timer1 = 0
local speed = 0
local numberup = 0
local time = 0
local time2 = 0
local time3 = 0

local characterdraw = true
local outroimageshow = true
local fadein2 = false

local credits = {
	"These credits are just an example you can",
	"replace with anything. Just like the",
	"original SMBX 1.3, the lines max is 5. But",
	"don't fret! You can customize this to add",
	"more lines, provided you adjust the timing and",
	"such. You can edit these lines with anything you",
	"want.",
}

local creditsLayouts = {}
local creditsScrollY = 0
local scrollOutroX = 0
function onStart()
	SaveData.hideCoinCounter = true
	for i = 1, #credits do
		local text = credits[i]
		local font = textplus.loadFont("textplus/font/6.ini")
		local color = white
		local scale = 2
		if text == "" then
			text = " "
		elseif text == "Levels" or text == "Music" or text == "Scripts" then
			font = textplus.loadFont("textplus/font/smb3-c.ini")
			--color = Color.fromHexRGBA(0x00D8F8FF)
			scale = 1
		end
		local layout = textplus.layout(text,nil,{font = font,color = color,xscale = scale,yscale = scale})

        table.insert(creditsLayouts,layout)
	end
end

function skipCredits()
	SFX.play(27)
	Routine.wait(0.4)
	Level.exit()
end

function onInputUpdate()
	player.upKeyPressing = false;
	player.downKeyPressing = false;
	player.leftKeyPressing = false;
	player.rightKeyPressing = false;
	player.altJumpKeyPressing = false;
	player.runKeyPressing = false;
	player.altRunKeyPressing = false;
	player.dropItemKeyPressing = false;
	player.jumpKeyPressing = false;
	if player.keys.pause == KEYS_PRESSED then
		Routine.run(skipCredits)
	end
	if pausepressed then
		player.pauseKeyPressing = false
	end
end

function onTick()
	creditsScrollY = creditsScrollY + 1
	scrollOutroX = scrollOutroX + 0.5
	--Text.print(creditsScrollY,120,120)
	if creditsScrollY == 900 then
		Audio.MusicFadeOut(player.section, 4000)
		fadein2 = true
	elseif creditsScrollY > 900 and creditsScrollY < 1200 then
		Graphics.drawScreen{color = Color.black .. (creditsScrollY - 2300) * 0.0042, priority = 6}
	elseif creditsScrollY >= 1200 then
		Graphics.drawScreen{color = Color.black .. 1, priority = 6}
		Level.exit()
		SaveData.hideCoinCounter = false
	end

	hudoverride.visible.itembox = false
	hudoverride.visible.keys = false
	hudoverride.visible.bombs = false
	hudoverride.visible.coins = false
	hudoverride.visible.score = false
	hudoverride.visible.lives = false
	hudoverride.visible.stars = false
end

walkCycles = {}

walkCycles[CHARACTER_MARIO]           = {[PLAYER_SMALL] = {1,2, framespeed = 4},[PLAYER_BIG] = {1,2,3,2, framespeed = 4}}
walkCycles[CHARACTER_LUIGI]           = walkCycles[CHARACTER_MARIO]
walkCycles[CHARACTER_PEACH]           = {[PLAYER_BIG] = {1,2,3,2, framespeed = 4}}
walkCycles[CHARACTER_TOAD]            = walkCycles[CHARACTER_PEACH]
walkCycles[CHARACTER_LINK]            = {[PLAYER_BIG] = {4,3,2,1, framespeed = 4}}
walkCycles[CHARACTER_MEGAMAN]         = {[PLAYER_BIG] = {2,3,2,4, framespeed = 12}}
walkCycles[CHARACTER_WARIO]           = walkCycles[CHARACTER_MARIO]
walkCycles[CHARACTER_BOWSER]          = walkCycles[CHARACTER_TOAD]
walkCycles[CHARACTER_KLONOA]          = walkCycles[CHARACTER_TOAD]
walkCycles[CHARACTER_NINJABOMBERMAN]  = walkCycles[CHARACTER_PEACH]
walkCycles[CHARACTER_ROSALINA]        = walkCycles[CHARACTER_PEACH]
walkCycles[CHARACTER_SNAKE]           = walkCycles[CHARACTER_LINK]
walkCycles[CHARACTER_ZELDA]           = walkCycles[CHARACTER_LUIGI]
walkCycles[CHARACTER_ULTIMATERINKA]   = walkCycles[CHARACTER_TOAD]
walkCycles[CHARACTER_UNCLEBROADSWORD] = walkCycles[CHARACTER_TOAD]
walkCycles[CHARACTER_SAMUS]           = walkCycles[CHARACTER_LINK]

walkCycles["SMW-MARIO"] = {[PLAYER_SMALL] = {1,2, framespeed = 8},[PLAYER_BIG] = {3,2,1, framespeed = 6}}
walkCycles["SMW-LUIGI"] = walkCycles["SMW-MARIO"]

walkCycles["ACCURATE-SMW-MARIO"] = walkCycles["SMW-MARIO"]
walkCycles["ACCURATE-SMW-LUIGI"] = walkCycles["SMW-MARIO"]
walkCycles["ACCURATE-SMW-TOAD"]  = walkCycles["SMW-MARIO"]

walkCycles["TWO"]            = {[PLAYER_BIG] = {4,3,2,1, framespeed = 4}}

local yoshiAnimationFrames = {
        {bodyFrame = 0,headFrame = 0,headOffsetX = 0 ,headOffsetY = 0,bodyOffsetX = 0,bodyOffsetY = 0,playerOffset = 0},
        {bodyFrame = 1,headFrame = 0,headOffsetX = -1,headOffsetY = 2,bodyOffsetX = 0,bodyOffsetY = 1,playerOffset = 1},
        {bodyFrame = 2,headFrame = 0,headOffsetX = -2,headOffsetY = 4,bodyOffsetX = 0,bodyOffsetY = 2,playerOffset = 2},
        {bodyFrame = 1,headFrame = 0,headOffsetX = -1,headOffsetY = 2,bodyOffsetX = 0,bodyOffsetY = 1,playerOffset = 1},
	}
	
local bootBounceData = {}

function onDraw()
	player.frame = -50 * player.direction
	local y = 0
    for _,layout in ipairs(creditsLayouts) do
        textplus.render{layout = layout,priority = -1,x = 400 - layout.width*0.5,y = y - creditsScrollY + 620}

        y = y + layout.height + 4
    end
	if fadein2 then
		time2 = time2 + 1
		Graphics.drawScreen{color = Color.black..math.max(0,time2/40),priority = 9}
	end
	if outroimageshow then
		time = time + 1
		Graphics.draw{type = RTYPE_IMAGE, x = scrollOutroX*1 + -3000, y = 0, image = outroimg, priority = -55, sceneCoords = false}
	end
	if characterdraw then
		for idx,p in ipairs(Player.get()) do
			local animation = walkCycles[p:getCostume()] or walkCycles[p.character]
			local animationTwo = walkCycles["TWO"]

			if animation ~= nil then
				local frame

				local x = 500
				local y = 10 - p.height

				if p.mount == MOUNT_BOOT then -- bouncing along in a boot
					bootBounceData[idx] = bootBounceData[idx] or {speed = 0,offset = 0}
					local bounceData = bootBounceData[idx]
							
					if not Misc.isPaused() then
						bounceData.speed = bounceData.speed + Defines.player_grav
						bounceData.offset = bounceData.offset + bounceData.speed

						if bounceData.offset >= 0 then
							bounceData.speed = -3.4
							bounceData.offset = 0
						end
					end

					y = y + bounceData.offset

					frame = 1
				elseif p.mount == MOUNT_CLOWNCAR then -- don't think this is even possible? but eh it's here
					frame = 1
				elseif p.mount == MOUNT_YOSHI then -- riding yoshi, yoshi's animation is a complete mess
					frame = 30

					local yoshiAnimationData = yoshiAnimationFrames[(math.floor(lunatime.tick() / 8) % #yoshiAnimationFrames) + 1]

					local xOffset = 4
					local yOffset = (72 - p.height)

					p:mem(0x72,FIELD_WORD,yoshiAnimationData.headFrame + 5)
					p:mem(0x7A,FIELD_WORD,yoshiAnimationData.bodyFrame + 7)

					p:mem(0x6E,FIELD_WORD,20 - xOffset + yoshiAnimationData.headOffsetX)
					p:mem(0x70,FIELD_WORD,10 - yOffset + yoshiAnimationData.headOffsetY)

					p:mem(0x76,FIELD_WORD,0  - xOffset + yoshiAnimationData.bodyOffsetX)
					p:mem(0x78,FIELD_WORD,42 - yOffset + yoshiAnimationData.bodyOffsetY)

					p:mem(0x10E,FIELD_WORD,yoshiAnimationData.playerOffset - yOffset)
				else -- just good ol' walking
					local walkCycle = animation[p.powerup] or animation[PLAYER_BIG]
					local walkCycleTwo = animationTwo[p.powerup] or animationTwo[PLAYER_BIG]

					frame = walkCycle[(math.floor(lunatime.tick() / walkCycle.framespeed) % #walkCycle) + 1]
					frame2 = walkCycleTwo[(math.floor(lunatime.tick() / walkCycleTwo.framespeed) % #walkCycleTwo) + 1]
				end

				p.direction = DIR_LEFT
				
				player:render{
					x = 220,y = 482,
					ignorestate = true, sceneCoords = false, character = 1, powerup = 4, priority = -5, color = (Defines.cheat_shadowmario and Color.black) or Color.white, frame = frame,
				}
				player:render{
					x = 295,y = 476,
					ignorestate = true, sceneCoords = false, character = 2, powerup = 7, priority = -5, color = (Defines.cheat_shadowmario and Color.black) or Color.white, frame = frame,
				}
				player:render{
					x = 375,y = 476,
					ignorestate = true, sceneCoords = false, character = 3, powerup = 5, priority = -5, color = (Defines.cheat_shadowmario and Color.black) or Color.white, frame = frame,
				}
				player:render{
					x = 450,y = 486,
					ignorestate = true, sceneCoords = false, character = 4, powerup = 2, priority = -5, color = (Defines.cheat_shadowmario and Color.black) or Color.white, frame = frame,
				}
				player:render{
					x = 525,y = 482,
					ignorestate = true, sceneCoords = false, character = 5, powerup = 6, priority = -5, color = (Defines.cheat_shadowmario and Color.black) or Color.white, frame = frame2,
				}


				if idx < Player.count() then
					xPosition = 485 + 65
				end
			end
		end
	end
end