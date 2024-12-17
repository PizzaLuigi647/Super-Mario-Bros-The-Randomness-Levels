--   __                   __      __           --
--  / /__________ __   __/ /     / /_  ______ _--
-- / __/ ___/ __ `/ | / / /     / / / / / __ `/--
--/ /_/ /  / /_/ /| |/ / /____ / / /_/ / /_/ / --
--\__/_/   \__,_/ |___/_____(_)_/\__,_/\__,_/  --
----------------------travL----------------------                                   
-------------Created by Enjl  - 2017-------------
-----Super Mario World Map Movement Library------
--------------For Super Mario Bros X-------------
----------------------v1.1-----------------------
---------------REQUIRES WANDR.lua----------------

local travL = {}
travL.settings = require("wandR")

local map3d;

--helper constants
local UP = 1
local LEFT = 2
local DOWN = 3
local RIGHT = 4

--offset for getIntersecting checks
local boxOffset = {}
boxOffset[UP] = {x=0, y=-32}
boxOffset[LEFT] = {x=-32, y=0}
boxOffset[DOWN] = {x=0, y=32}
boxOffset[RIGHT] = {x=32, y=0}

--initialise arrow sprite
local arrowSprite = Graphics.sprites.hardcoded[56]
travL.showArrows = true

travL.position = vector.v2(400, 320);
local vtTable = {}
for i=1, 4 do
	vtTable[i] = {	boxOffset[i].x - 0.5 * arrowSprite.img.width, boxOffset[i].y - 0.5 * arrowSprite.img.height,
					boxOffset[i].x + 0.5 * arrowSprite.img.width, boxOffset[i].y - 0.5 * arrowSprite.img.height,
					boxOffset[i].x - 0.5 * arrowSprite.img.width, boxOffset[i].y + 0.5 * arrowSprite.img.height,
					boxOffset[i].x + 0.5 * arrowSprite.img.width, boxOffset[i].y + 0.5 * arrowSprite.img.height}
end

local txTable = {}
txTable[UP] = {0,0,1,0,0,1,1,1}
txTable[LEFT] = {1,0,1,1,0,0,0,1}
txTable[DOWN] = {1,1,0,1,1,0,0,0}
txTable[RIGHT] = {0,1,0,0,1,1,1,0}

--movement related
local walkTo = {}
walkTo[UP] = function() player.upKeyPressing = true end
walkTo[LEFT] = function() player.leftKeyPressing = true end
walkTo[DOWN] = function() player.downKeyPressing = true end
walkTo[RIGHT] = function() player.rightKeyPressing = true end

local getInput = {}
getInput[UP] = function() return player.upKeyPressing end
getInput[LEFT] = function() return player.leftKeyPressing end
getInput[DOWN] = function() return player.downKeyPressing end
getInput[RIGHT] = function() return player.rightKeyPressing end

--table containing number of adjacent levels in directions ULDR
local adjacentFields = {0,0,0,0}

--arrow display delay (to prevent flickering)
local isStanding = 8

--helper functions
local function isMoving()
	return world.playerIsCurrentWalking
end

local function getDirection()
	return world.playerCurrentDirection
end

local function isOnLevel()
	for k,v in pairs(Level.get()) do
		if v.x == world.playerX and v.y == world.playerY then
			return true
		end
	end
	return false
end

--inserts visible tiles into the table
local function insertTiles(idx, tableToCheck)
	for k,v in pairs(tableToCheck) do
		if v.visible then
			adjacentFields[idx] = 1
			break
		end
	end
end

local function checkSurroundings()
	adjacentFields = {0,0,0,0}
	for i=1, 4 do
		local x = world.playerX + boxOffset[i].x
		local y = world.playerY + boxOffset[i].y
		insertTiles(i, Path.getIntersecting(x + 15, y + 15, x + 17, y + 17))
		--
		local levelList = {}
		for k,v in pairs(Level.get()) do
			if x + 16 > v.x and x + 16 < v.x + 32 and y + 16 > v.y and y + 16 < v.y + 32 then
				table.insert(levelList, v)
			end
		end
		insertTiles(i, levelList)
		--
		--insertTiles(i, Level.getIntersecting(x + 15, y + 15, x + 17, y + 17))
	end
end

--override arrow sprite
function travL.setSprite(newSprite)
	Graphics.sprites.hardcoded[56].img = newSprite
	for i=1, 4 do
		vtTable[i] = {	boxOffset[i].x - 0.5 * arrowSprite.img.width, boxOffset[i].y - 0.5 * arrowSprite.img.height,
						boxOffset[i].x + 0.5 * arrowSprite.img.width, boxOffset[i].y - 0.5 * arrowSprite.img.height,
						boxOffset[i].x - 0.5 * arrowSprite.img.width, boxOffset[i].y + 0.5 * arrowSprite.img.height,
						boxOffset[i].x + 0.5 * arrowSprite.img.width, boxOffset[i].y + 0.5 * arrowSprite.img.height}
	end
end

local map3d_offset = vector.zero2;

--------------------------

function travL.onInitAPI()
	registerEvent(travL, "onTick", "onTick", false)
	registerEvent(travL, "onDraw", "onDraw", false)
	registerEvent(travL, "onStart", "onStart", false)
end

function travL.onStart()
	checkSurroundings()
end

function travL.onTick()
	isStanding = isStanding + 1
	
	if world.playerWalkingTimer ~= 0 then
		isStanding = 0
	end
	
	if not isOnLevel() then
		if isMoving() then
			local playerDir = (getDirection() + 2)%4
			if playerDir == 0 then playerDir = 4 end
			local input = getInput[playerDir]()
			
			--lock inputs to prevent cancelling
			player.upKeyPressing = false
			player.downKeyPressing = false
			player.leftKeyPressing = false
			player.rightKeyPressing = false
			
			checkSurroundings()
			
			if input then
				--however, allow turning around
				walkTo[playerDir]()
			else
				local targetDirection = 0
				local adjacentTiles = 0
				for k,v in pairs(adjacentFields) do
					if k ~= playerDir and v == 1 then --exclude direction from where player came
						adjacentTiles = adjacentTiles + v
						targetDir = k
					end
				end
				--if we find more than one adjacent tile we're at an intersection
				if adjacentTiles == 1 then
					walkTo[targetDir]()
				end
			end
		end
	end
end

function travL.onDraw()
	if(isAPILoaded("map3d")) then
		if(map3d == nil) then
			map3d = require("map3d");
		end
		
		map3d_offset = map3d.project(vector.v4(world.playerX + 16, map3d.GetHeight(world.playerX + 16, world.playerY + 16), world.playerY + 16, 1)):tov2() - vector.v2(0,32);
		
	elseif(map3d ~= nil) then
		map3d_offset = vector.zero2;
		map3d = nil;
	end
	--draw
	if isStanding >= 8 and travL.showArrows then
		for k,v in pairs(adjacentFields) do
			local t = {};
			for i = 1,8,2 do
				t[i] = travL.position.x + map3d_offset.x + vtTable[k][i];
				t[i+1] = travL.position.y + map3d_offset.y + vtTable[k][i+1];
			end
			if v == 1 then
				Graphics.glDraw{vertexCoords = t, textureCoords = txTable[k], texture = arrowSprite.img, primitive = Graphics.GL_TRIANGLE_STRIP}
			end
		end
	end
end

return travL