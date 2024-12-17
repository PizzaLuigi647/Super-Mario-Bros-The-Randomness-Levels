--                            _ .___     .               --
-- ,  _  /   ___  , __     ___/ /   \    |   ,   .   ___ --
-- |  |  |  /   ` |'  `.  /   | |__-'    |   |   |  /   `--
-- `  ^  ' |    | |    | ,'   | |  \     |   |   | |    |--
--  \/ \/  `.__/| /    | `___,' /   \ / /\__ `._/| `.__/|--
----------------------wandR----------------------                                   
-------------Created by Enjl  - 2017-------------
--------World Map Movement Speed Library---------
--------------For Super Mario Bros X-------------
----------------------v1.0-----------------------

local wandR = {}
local walkDir = {}
walkDir[0] = function(x) return end
walkDir[1] = function(x) world.playerY = world.playerY - x end
walkDir[2] = function(x) world.playerX = world.playerX - x end
walkDir[3] = function(x) world.playerY = world.playerY + x end
walkDir[4] = function(x) world.playerX = world.playerX + x end

function wandR.onInitAPI()
	registerEvent(wandR, "onTick", "onTick", false)
	registerEvent(wandR, "onStart", "onStart", true)
end

local startX, startY

wandR.grid = 32
wandR.speed = 2

function wandR.onStart()
	startX = world.playerX%wandR.grid
	startY = world.playerY%wandR.grid
end

function wandR.onTick()
	if world.playerIsCurrentWalking then
		world.playerWalkingTimer = 5
		for i=1, wandR.speed do
			walkDir[world.playerWalkingDirection](1)
			if (world.playerX % wandR.grid == startX) and (world.playerY % wandR.grid == startY) then --check if the player reached a tile
				world.playerWalkingTimer = 32
				break
			end
		end
		walkDir[world.playerWalkingDirection](-2) --counteract vanilla coordinate change
	else
		world.playerWalkingTimer = 0
	end
end

return wandR