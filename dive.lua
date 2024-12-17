local dive = {}
--v1.3

local textplus = require("textplus")
local playeranim = require("playerAnim")
local rng = require("rng")
local twirl

function dive.onInitAPI()
	registerEvent(dive, "onTick", "onTick")
	registerEvent(dive, "onDraw", "onDraw")
end

dive.showMeDebug = false
local diveSfx = Misc.resolveFile("dive.ogg")

local isDiving = {false,false}
local diveTimeline = {0,0}
local diveCooldown = {0,0}

--The Dive™
dive.impulseY =		4.27
dive.diveCooldown =		0
dive.allowEveryCharacter = false

--Animation
local diveFrames = {41,41,41,2}
local animationSpeed = 7
local diveAnim = playeranim.Anim(diveFrames, animationSpeed)




function dive.onTick() for k, p in ipairs(Player.get()) do



	if p:mem(0x12E,FIELD_BOOL) then
		diveAnim:stop(p)
	end

	local function resetDiving()
		isDiving[k] = false
		diveTimeline[k] = 0
		diveCooldown[k] = 0
	end

	-- Convenience Functions
	local function isOnGround() return(
		p:isOnGround()
		or (p.mount == MOUNT_BOOT and p:mem(0x10C,FIELD_BOOL))		-- Hopping in boot
		or p:mem(0x40,FIELD_WORD) > 0								-- Climbing	
	)end
	local function isOnMount() return(
		 
		p.climbing
	)end
	local function isUnderwater() return(
		p:mem(0x36,FIELD_BOOL)				-- In a liquid
		or p:mem(0x06,FIELD_BOOL)		-- In quicksand
	) end
	local function canDive() return (
			not isDiving[k] and
			not isOnGround() and
			not p:mem(0x50,FIELD_BOOL) and -- Spinning
			not isUnderwater() and
			not isOnMount() and
			not p:mem(0x44, FIELD_BOOL) and -- Riding a rainbow shell
			not p:mem(0x13C, FIELD_BOOL) and -- Is Dead
			not p.holdingNPC and
			not p.isMega and
			p.deathTimer == 0 and
			Level.winState() == 0 and
			p.forcedState == 0 and
			((p.character == 1 or p.character == 2) or dive.allowEveryCharacter)
	) end


	if (package.loaded["twirl"] ~= nil) then
		twirl = require("twirl")

		if diveTimeline[k] ~= 0 then
			twirl.cancelTwirl(k,p)
		end
	end


	dive.controls = p.keys.down and p.keys.altJump
	if dive.controls and diveCooldown[k] > dive.diveCooldown then
		isDiving[k] = true
	elseif canDive() then
		isDiving[k] = false
		diveCooldown[k] = diveCooldown[k] + 1
	else
		diveCooldown[k] = 0
	end

	if isDiving[k] then
		diveTimeline[k] = diveTimeline[k] + 1

		if diveTimeline[k] < animationSpeed*#diveFrames then
			player.keys.down = false
		end
	end


	if diveTimeline[k] == 1 then
		SFX.play(diveSfx)
		diveAnim:play(p)

		if p.powerup ~= 1 then
			local poof = Animation.spawn(10, p.x-10, p.y+p.height/3)
			poof.speedX = 1*-p.direction + math.abs(p.speedX/8)*-p.direction
			poof.speedY = 1
		else
			local poof = Animation.spawn(10, p.x-10, p.y)
			poof.speedX = 1*-p.direction + math.abs(p.speedX/8)*-p.direction
			poof.speedY = 1
		end

		if math.abs(p.speedX) < 2 then
			p.speedX = p.direction * (math.abs(p.speedX)+2.5) * 1.23
		else
			p.speedX = p.direction * (math.abs(p.speedX)+1) * 1.2
		end
		p.speedY = -dive.impulseY
	end

	--Stop Animation
	if diveTimeline[k] >= animationSpeed*#diveFrames or diveTimeline[k] == 0 or isOnMount() then
		diveAnim:stop(p)
	end

	--Reset Diving
	for kn,n in ipairs(NPC.getIntersecting(p.x, p.y, p.x+p.width, p.y+p.height+11)) do
		if n.isValid and (n.id == 26 or n.id == 457) then
			resetDiving()
		end
	end
	if isOnGround() or isOnMount() or isUnderwater() then				
		resetDiving()
	end


--Debug: Prints Variables on Screen — Set ``dive.showMeDebug`` to true in order to activate. (Works with 2 players)
	local function print(line, text, variable,color)
		if dive.showMeDebug == false then return end
		debugFont = textplus.loadFont("scripts/textplus/font/11.ini")
	
		textplus.print{font=debugFont,xscale=1.5,yscale=1.5,x=20^k*1.02,y=(6+line)*15,text=text..": "..tostring(variable),color=color}
	end
	print(1,	"p.speedX",					p.speedX						)
	print(4,	"Is Diving",				isDiving[k]						)
	print(6,	"Can Dive?",				canDive()						)
	print(8,	"Timeline of Dive",			diveTimeline[k]					)
	print(9,	"Is Mounting Something",	isOnMount()						)
	print(13,	"0x12E",					p:mem(0x12E, FIELD_BOOL)		)
	print(14,	"0x06",						p:mem(0x06,FIELD_BOOL)			)
	print(15,	"Twirl is Loaded",			(package.loaded["twirl"] ~= nil	)		)
	
	if diveCooldown[k] < dive.diveCooldown then
		print(7,	"Cooldown",					diveCooldown[k]		,Color(1, 0.4, 0.4))
	else
		print(7,	"Cooldown",					diveCooldown[k]		,Color.green)
	end
end
end


--Déjà Vu!

return dive