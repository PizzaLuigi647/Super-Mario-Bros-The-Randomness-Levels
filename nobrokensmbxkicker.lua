--nobrokensmbxkicker.lua
--by Spencer Everly
--This is to prevent getting kicked to the broken SMBX lancher, such as when dying at 0 lives, opening the credits, etc.
--Use pausemenu13.lua as well to also include the pause menu, and for a full experience when playing SMBX 1.3 episodes!
--You can't require this on the map, by the way. It's not compatible with it.

local nobrokensmbxkicker = {}

local killed = false
local killed2 = false
local player2 = Player(2) --To make sure that player2 also redirects to Player(2)

function nobrokensmbxkicker.onInitAPI()
	registerEvent(nobrokensmbxkicker,"onTick")
	registerEvent(nobrokensmbxkicker,"onExit")
end

function nobrokensmbxkicker.onTick()
	for _,p in ipairs(Player.get()) do --Make sure all players are counted if i.e. using supermario128...
		if mem(0x00B2C5AC,FIELD_FLOAT) == 0 then --If 0, do these things...
			if(not killed and p:mem(0x13E,FIELD_BOOL)) then --Checks to see if the player actually died...
				killed = true --If so, this is true.
				mem(0x00B2C5AC,FIELD_FLOAT, 1) --Increase the life to 1 to prevent being kicked to the broken SMBX launcher after dying
			end
			if Player(2) and Player(2).isValid then --Player(2) compability! This one is a bit of a mess, but I tried
				if(not killed2 and p.deathTimer >= 1 and p:mem(0x13C, FIELD_BOOL)) then --Because 0X13E doesn't check in multiplayer, use the death timer instead.
					killed2 = true --This one has a different variable set for player2
					mem(0x00B2C5AC,FIELD_FLOAT, 1) --Also same as above
					if p.deathTimer >= 199 then --If player2's death timer is almost 200, load the game over level
						Level.load("gameover.lvlx")
					end
				end
			end
		end
	end
end

function nobrokensmbxkicker.onExit()
	if mem(0x00B2C5AC,FIELD_FLOAT) == 0 then --This is to exit to the right level when actually on 0 lives
		if killed == true or killed2 == true then
			Level.load("gameover.lvlx", nil, nil)
		end
	end
	if mem(0x00B2C89C, FIELD_BOOL) then --Let's prevent the credits from execution by loading a sample credits level. It can be modifiable by the user.
		Level.load("credits.lvlx", nil, nil)
	end
end

return nobrokensmbxkicker