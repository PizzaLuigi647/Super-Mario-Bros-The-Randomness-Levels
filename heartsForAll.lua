--[[

	Hearts for All: v2.4.0.2
	Put together by AppleTheTomato
	
	Shoutout to Saric, as their question of 'how to remove the reserve box?' basically 
	started the domino effect that was creating this
	
	Shoutout to MrDoubleA, as his response to the above question is what really made me think this was possible.
	I even used a few of his methods for this
	
	Shoutouts to Marioman and AToMIC, as after I worked on this, Marioman worked on reserveItems (here: https://www.supermariobrosx.org/forums/viewtopic.php?p=394730#p394730),
	and due to a request in that forum by AToMIC, I decided to try and make this NOT mess with reserve items for v2.4
	
	MASSIVE thank you to KBM-Quine, who helped me understand how to use the 'onSomethingSomething' events
	
	
	:Things you can set:
	pC.enabled - Set this to true to enable the lua, and false to disable it. You can enable and disable the library mid level too, if you want
	pC.boxOffset - Change this for any custom HUD changes to the itembox. It's set to -100 to hide the items, and the default is 16, like in the basegame
	pC.itemOffset - Change this to determine where the item goes. It's set to -100 by default to hide the items
	
	
	:Changelog:
	-v1.0- 
	*First release
	
	-v1.0.1- 
	*Forgot to account for checkpoints, now those are accounted for. 
	*onPostBlockHit code is SLIGHTLY better optimized
	
	-v1.0.1.1-
	*Super small change to line 175 that makes it so that trying to manually set the health for a smol guy doesn't work
	
	-v2.0-
	*The X2 characters that also use item boxes use the heart system now. Code and comments were adjusted to acomodate for this
	*Added a shoutout to Saric, who's question caused the domino effect that led me to creating this
	
	-v2.1-
	*Added the ability to disable the lua or not
	
	-v2.2-
	*Fixes to the changelog lol
	*Additions / changes to certain comments
	*Slightly better code
	*The enable and disable functions were removed cause they literally aren't needed lol
	*The megashroom and SMB2 hearts from X2 were added to the powerup table
	*Much better way to enable / disable the library now
	
	-v2.3-
	*Megashroom is now handled differently
	*Fixed powerup blocks, and in process, removed onPostBlockHit and onCheckpoint
	
	-v2.4-
	*A boxoffset is used to change the box offset back to the default. You can also manipulate it to fit your custom itembox placement
	*An itemOffset can be used to determine the position of the items. Good for if you use the below
	*You can now decide whether you want to constantly delete the reserve or keep it.
	*Different way of adjusting health now
	
	-v.2.4.0.1-
	*Tiny bit of cleanup
	*Fixed a bug with onNPCKill where the one player would get extra health for a split second if the other player got a powerup
	
	-v2.4.0.2-
	*Fixed a bug where collecting the same powerup again wouldn't increase health
	*Changed onNPCKill to onPostNPCKill, cause IDK
	
	
]]

local hudo = require("hudoverride")
local pC = {} --fun fact: this is called pC cause this lua is edited off my playerChanges for an episode of mine


--Things you can mess with
pC.enabled = true
pC.boxOffset = 16
pC.itemOffset = -100 --don't confuse these two. One is where you want the box to be if the library gets disabled. The other is where the items will go if the library is enabled.


--itembox users
local boxUsers = {

	1,
	2,
	7,
	13,
	15
	
}


--powerUPS
local powerUPS = {

	34,
	169,
	170,
	9,
	184,
	185,
	249,
	250,
	462,
	14,
	182,
	183,
	264,
	277
	
}


--powerup STATES
local powerSTATES = {

	1,
	4,
	5,
	11,
	12,
	41
	
}


--To remove the reserve
local function removeReserve()
	for k,p in ipairs(Player.get()) do
		if p.reservePowerup > 0 then
			p.reservePowerup = 0
		end
	end
end


--Registered things
function pC.onInitAPI()

	registerEvent(pC, "onStart")
	registerEvent(pC, "onPostNPCKill")
	registerEvent(pC, "onDraw")
	registerEvent(pC, "onTick")
	
end


--If you aren't small on the level start, set your health to 2
function pC.onStart()
	if pC.enabled == true then
		for k,p in ipairs(Player.get()) do
			if p.powerup > 1 and p:mem(0x16, FIELD_WORD) <= 0 then
				p:mem(0x16, FIELD_WORD, 2)
			end
		end
	end
end


--Powerups will properly give box users health
function pC.onPostNPCKill(npc, harm)
	if pC.enabled == true then
		for a,b in ipairs(powerUPS) do
			for k,p in ipairs(Player.get()) do
				for c,u in ipairs(boxUsers) do
					for w,s in ipairs(powerSTATES) do
					
						if npc.id == b and npc.despawnTimer > 0 and harm == HARM_TYPE_VANISH and p.character == u then
							if p.reservePowerup <= 0 then
								p:mem(0x16, FIELD_WORD, 2)
							elseif p.reservePowerup > 0 then
								p:mem(0x16, FIELD_WORD, 3)
								Routine.setFrameTimer(1, removeReserve, false, true)
							end
						end
						
					end
				end	
			end
		end
	end
end


--Applies heart change for box users GRAPHICALLY
function pC.onDraw()
	if pC.enabled == true then
		hudo.offsets.itembox.y = pC.itemOffset
		for b,u in ipairs(boxUsers) do
			Graphics.registerCharacterHUD(u, Graphics.HUD_HEARTS)
		end
	
	elseif pC.enabled ~= true then
		hudo.offsets.itembox.y = pC.boxOffset
		for b,u in ipairs(boxUsers) do
			Graphics.registerCharacterHUD(u, Graphics.HUD_ITEMBOX)
		end
	end	
end
Graphics.addHUDElement(pC.onDraw)


--The stuff that constantly runs
function pC.onTick()
	if pC.enabled == true then
	
		--If Player 2 is an X2 character, turn them into Luigi, since the X2 characters aren't always 2-Player compatible
		if Player.count() > 1 then
			if player2.character > 5 then
				player2.character = 2
			end
		end
	
		--Loop for players
		for k,p in ipairs(Player.get()) do
			
			--If the health is greater than 3 (somehow, IDK), set it to 3
			if p:mem(0x16, FIELD_WORD) > 3 then
				p:mem(0x16, FIELD_WORD, 3)
			end
			
			--Only do the below for the box users
			for b,u in ipairs(boxUsers) do
				if p.character == u then
					
					--Can't drop the reserve if you have something in it (Thanks, Enjl)
					if p.reservePowerup > 1 then
						p.keys.dropItem = false
					end

					--If you have 0 health, are small, aren't in a special state, and are not dead (lol), set the health to 1 
					if (p:mem(0x16, FIELD_WORD) <= 0 or p:mem(0x16, FIELD_WORD) >= 2) and p.powerup == 1 and p:mem(0x13C, FIELD_BOOL) == false and p.forcedState == 0 then
						p:mem(0x16, FIELD_WORD, 1)
					
					--Similar to the above, but for 2 Hearts (have to have this for the stupid mushroom block and the cool megashroom to work)
					elseif p.powerup == 2 and p:mem(0x16, FIELD_WORD) <= 1 and p:mem(0x13C, FIELD_BOOL) == false and p.forcedState == 0 then
						p:mem(0x16, FIELD_WORD, 2)
					end
					
					--Lose health
					if p.forcedState == 2 then
						
						--Mimicks how Peach and Toad deal with this at 3 hearts
						if p:mem(0x16, FIELD_WORD) == 3 then
							p:mem(0x16, FIELD_WORD, 2)
							
							--Applies certain state with certain powerups
							if p.powerup == 3 then
								p.forcedState = 227
							elseif p.powerup == 7 then
								p.forcedState = 228
							else
								p.forcedState = 0
								p:mem(0x140, FIELD_WORD, 150)
								p.powerup = 2
							end
						
						--For 2 health
						elseif p:mem(0x16, FIELD_WORD) == 2 and p:mem(0x140, FIELD_WORD) <= 0 then 
							p:mem(0x16, FIELD_WORD, 1)
						end
						
					end
					
					--You are dead lol
					if p.deathTimer > 0 or p:mem(0x13C, FIELD_BOOL) == true then
						p:mem(0x16, FIELD_WORD, 0)
					end
					
				end
			end
			
		end	
	
	end
end


return pC