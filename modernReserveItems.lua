--------------------------------------------------
--[[ modernReserveItems.lua v1.3 by KBM-Quine ]]--
--[[    massive amounts of code help from:    ]]--
--[[        rixithechao, Enjl, Hoeloe,        ]]--
--[[         PixelPest, and MrDoubleA         ]]--
--------------------------------------------------
local modernReserveItems = {}

local pm = require("playermanager")

modernReserveItems.enabled = false
modernReserveItems.autoHold = true
modernReserveItems.timeAutoHeld = 32
modernReserveItems.playSounds = true
modernReserveItems.playerXMomentum = 0
modernReserveItems.playerYMomentum = 0
modernReserveItems.spawnLayer = "Spawned NPCs"
modernReserveItems.allowThrownItems = true
modernReserveItems.allowHeldItems = true
modernReserveItems.allowHeldItemsInWarps = true
modernReserveItems.allowContainedItems = true
modernReserveItems.allowAnyItems = true
modernReserveItems.useBuiltInDrop = true
modernReserveItems.offScreenDespawn = mem(0x00B2C85A, FIELD_WORD) * 20 -- https://github.com/smbx/smbx-legacy-source/blob/master/modBlocks.bas#L441

local mriNPCs = {}
local remove = table.remove

local patterns = {
	default = {
		speedX = 0,
		speedY = 0,
		isHeld = true,
        isContained = false,
        isThrown = false,
        containedID = 0,
        isMega = false,
        doesntMove = false,
        isEgg = false,
        SFX = 23,
        yoshiSFX = 50
	},
	thrown = {
		speedX = 5,
		speedY = -6,
		isHeld = false,
        isContained = false,
        isThrown = true,
		containedID = 0,
        isMega = false,
        doesntMove = false,
        isEgg = false,
        SFX = 11,
        yoshiSFX = 50
	},
	stationaryPowerup = {
		speedX = 3.5,
		speedY = -3,
		isHeld = false,
        isContained = false,
        isThrown = true,
		containedID = 0,
		isMega = false,
        doesntMove = false,
        isEgg = false,
        SFX = 11,
        yoshiSFX = 50
	},
	stationary = {
		speedX = 0,
		speedY = -7,
        isHeld = false,
        isContained = false,
        isThrown = true,
		containedID = 0,
		isMega = false,
        doesntMove = false,
        isEgg = false,
        SFX = 11,
        yoshiSFX = 50
	},
	mushroom = {
		speedX = 3,
		speedY = -3,
		isHeld = false,
        isContained = false,
        isThrown = true,
		containedID = 0,
		isMega = false,
        doesntMove = true,
        isEgg = false,
        SFX = 11,
        yoshiSFX = 50
	},
}

local thrownNPCSettings = {
    [95] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 95
        }
    },
    [98] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 98
        }
    },
    [99] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 99
        }
    },
    [100] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 100
        }
    },
    [148] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 148
        }
    },
    [149] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 149
        }
    },
    [150] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 150
        }
    },
    [188] = {
        speedX = 6,
        speedY = 0,
		isHeld = false,
        isThrown = true,
        pattern = default
	},
    [228] = {
		isHeld = true,
        isEgg = true,
        ai = {
            ai1 = 228
        },
        pattern = default
    },
	[240] = {
        speedX = 0,
		speedY = 0,
		isHeld = false,
        isContained = true,
        isThrown = false,
		containedID = 2,
        isMega = false,
        SFX = 11,
        yoshiSFX = 50,
        pattern = default
	},
	[248] = {
        speedX = 0,
		speedY = 0,
		isHeld = false,
        isContained = true,
        isThrown = false,
		containedID = 2,
        isMega = false,
        SFX = 11,
        yoshiSFX = 50,
        pattern = default
	},
	[293] = {
		speedX = 1.5,
		speedY = -3,
		isHeld = false,
        isThrown = true,
        SFX = 11,
        pattern = default
	},
	[425] = {
		speedX = 1,
		speedY = -3,
		isHeld = false,
        isThrown = true,
		isMega = true,
        SFX = 11,
        pattern = default
	}
}

local patternPresets = {
	mushroom = {9, 75, 90, 153, 184, 185, 186, 187, 273, 462},
	thrown = {16, 41, 97},
	stationary = {14, 34, 94, 101, 102, 198},
	stationaryPowerup = {169, 170, 182, 183, 240, 249, 254, 264, 277, 559}
}

for  k,v in pairs(patternPresets)  do
	for  _,v2 in ipairs(v)  do
		if  thrownNPCSettings[v2] == nil  then
			thrownNPCSettings[v2] = {}
		end
		thrownNPCSettings[v2].pattern = patterns[k]
	end
end

function modernReserveItems.onInitAPI()
	registerEvent(modernReserveItems, "onInputUpdate")
	registerEvent(modernReserveItems, "onNPCHarm")
	registerEvent(modernReserveItems, "onPostNPCKill")
	registerEvent(modernReserveItems, "onTickEnd")
end

function modernReserveItems.getThrowSettings(npcID)
    return thrownNPCSettings[npcID]
end

function modernReserveItems.setThrowSettings(npcID, patternTable)
    local settings = thrownNPCSettings[npcID]  or  {}
	thrownNPCSettings[npcID] = table.join(thrownNPCSettings[npcID]  or  {}, patternTable)
end

function modernReserveItems.resolveThrowSettings(npcID, field)
    local pattern
    local key
    if thrownNPCSettings[npcID] ~= nil then
        key = thrownNPCSettings[npcID][field]
        pattern = thrownNPCSettings[npcID].pattern
    end
    if key == nil and pattern ~= nil then
        if pattern[field] ~= nil then
            key = pattern[field]
        else
            key = patterns.default[field]
        end
    elseif key == nil and pattern == nil then
        key = patterns.default[field]
    end
    return key
end

-- P's & Q's checker. made so external sources can optionally check these themselves
function modernReserveItems.validityCheck(ID, p)
    local isHeld = modernReserveItems.resolveThrowSettings(ID, "isHeld")
    local isContained = modernReserveItems.resolveThrowSettings(ID, "isContained") -- this is only used by the reserve box stopwatch
    local isThrown = modernReserveItems.resolveThrowSettings(ID, "isThrown")
    local isEgg = modernReserveItems.resolveThrowSettings(ID, "isEgg") -- disallows yoshi from eating yoshis
    local npcID = ID
    if isEgg then
        npcID = 96
    end
    local bool = true
    for _,v in ipairs(Warp.get()) do -- if the warp doesen't allow items, then don't spawn them 
        if (p.TargetWarpIndex == v.idx+1 or p.TargetWarpIndex == 0) and p.ForcedAnimationTimer > 1 then
            if not v.allowItems then
                bool = false
            end
        end
    end
    if p.ForcedAnimationState == 7 or p.ForcedAnimationState == 3 then
        if p.ForcedAnimationTimer >= 1 and not modernReserveItems.allowHeldItemsInWarps or (isThrown or isContained) then
            bool = false
        end
    end
    for _,v in ipairs({1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 41, 227, 228, 500}) do -- don't allow spawning if the player is in a forced state
        if p.ForcedAnimationState == v then
            bool = false
        end
    end
    if p.MountType == MOUNT_YOSHI and NPC.config[npcID].noyoshi and isHeld then bool = false end -- if on yoshi, don't spawn an item that doesn't allow yoshi to eat it
    if p.MountType == MOUNT_BOOT and isHeld then bool = false end -- can't hold something if your in a boot, silly
    if p:mem(0xB8, FIELD_WORD) ~= 0 and isHeld then bool = false end -- cancel spawn if yoshi is holding something
    if p.holdingNPC ~= nil and isHeld then bool = false end -- you can't hold more then one item, you'd need more arms!
    if p.BlinkTimer == 1 and p.BlinkState then bool = false end -- workaround for launch barrels 
    if p.ClimbingState > 0 and isHeld then bool = false end -- you can't climb AND hold an item, you'd need more arms!
    if not p.TanookiStatueActive and isHeld then bool = false end -- can't hold something if you can't move your hands!
    if p.deathTimer > 0 then bool = false end -- can't use reserve items if your dead
    if mem(0x00B2C59E, FIELD_WORD) > 0 then bool = false end -- don't allow spawning if the game is in a winning state
    if not modernReserveItems.allowThrownItems and isThrown then bool = false end
    if not modernReserveItems.allowHeldItems and isHeld then bool = false end
    if not modernReserveItems.allowContainedItems and isContained then bool = false end
    if not modernReserveItems.allowAnyItems then bool = false end

    return bool
end

--wrappers for external use events
function modernReserveItems.onReserveUse(eventObj, ID, p, throwSettings)
    -- empty
end

function modernReserveItems.onPostReserveUse(npc, p)
    -- empty
end

-- the main act!
function modernReserveItems.drop(ID, p)
    local ps = PlayerSettings.get(pm.getCharacters()[p.character].base, p.powerup)
    local speedX = modernReserveItems.resolveThrowSettings(ID, "speedX")
    local speedY = modernReserveItems.resolveThrowSettings(ID, "speedY")
    local isHeld = modernReserveItems.resolveThrowSettings(ID, "isHeld")
    local isContained = modernReserveItems.resolveThrowSettings(ID, "isContained") -- this is only used by the reserve box stopwatch
    local isThrown = modernReserveItems.resolveThrowSettings(ID, "isThrown")
    local containedID = modernReserveItems.resolveThrowSettings(ID, "containedID") -- this is only used by the reserve box stopwatch
    local isMega = modernReserveItems.resolveThrowSettings(ID, "isMega") -- for larger items when thrown(mega mushroom only uses this so far)
    local doesntMove = modernReserveItems.resolveThrowSettings(ID, "doesntMove")
    local isEgg = modernReserveItems.resolveThrowSettings(ID, "isEgg") -- disallows yoshi from eating yoshis
    local data = modernReserveItems.resolveThrowSettings(ID, "data")
    local ai = modernReserveItems.resolveThrowSettings(ID, "ai")
    local SFX = modernReserveItems.resolveThrowSettings(ID, "SFX")
    local yoshiSFX = modernReserveItems.resolveThrowSettings(ID, "yoshiSFX")
    local npcID = ID
    if isEgg then
        npcID = 96
    end
    local eventObj = {cancelled = false}
    modernReserveItems.onReserveUse(eventObj, ID, p, {speedX=speedX, speedY=speedY, isHeld=isHeld, isContained=isContained, isThrown=isThrown, containedID=containedID, isMega=isMega, doesntMove=doesntMove, isEgg=isEgg, data=data, ai=ai, SFX=SFX, yoshiSFX=yoshiSFX})
    if eventObj.cancelled then return nil end
    local spawnedX = p.x+(p.width*0.5)
    local spawnedY = p.y+(p.height*0.5)
    if not isContained then
        -- y adjustment cases
        if p.MountType == MOUNT_CLOWNCAR then
            spawnedY = p.y + 16 - (NPC.config[npcID].height*0.5)
        else
            if isHeld then
                spawnedY = p.y+ps.grabOffsetY + 32 - NPC.config[npcID].height
            end
        end

        -- x adjustment cases
        if p.MountType == MOUNT_CLOWNCAR and isHeld then
            spawnedX = p.x+(p.width*0.5)+(48*p.direction)
        elseif isHeld then
            spawnedX = p.x+(p.width*0.5)+((p.width*0.25)*p.direction)
        end
    end
    local MRINPC = NPC.spawn(npcID, spawnedX, spawnedY, p.section, false, true)
    MRINPC.despawnTimer = modernReserveItems.offScreenDespawn
    MRINPC.direction = p.direction
    MRINPC.dontMove = doesntMove
    if doesntMove and isThrown then
        MRINPC:mem(0x136, FIELD_BOOL, true) -- Projectile Flag

        -- this it to fix thrown npcs' dieing to contact with other npcs
        MRINPC.data.MRITagged = true
        MRINPC.data.MRIIndex = #mriNPCs+1
        mriNPCs[#mriNPCs+1] = MRINPC
    end
    MRINPC:mem(0x138, FIELD_WORD, containedID) --Forced State/Contained In
    MRINPC:mem(0x132, FIELD_WORD, p.idx) -- Thrown by Player
    if data ~= nil then
        for  k,_ in pairs(data)  do
            MRINPC.data[k] = data[k]
        end
    end
    if ai ~= nil then
        for  k,_ in pairs(ai) do
            MRINPC[k] = ai[k]
        end
    end

    if not isContained then
        MRINPC:mem(0x12E, FIELD_WORD, 30) -- Grab Timer
        MRINPC:mem(0x130, FIELD_WORD, p.idx) -- Grabbing Player
    end
    if isThrown then
        if speedX ~= nil then
            MRINPC.speedX = speedX*MRINPC.direction+(p.speedX*modernReserveItems.playerXMomentum)
        end
        if speedY ~= nil then
            MRINPC.speedY = speedY+(p.speedY*modernReserveItems.playerYMomentum)
        end
    end
    
    if p.MountType == MOUNT_NONE and isHeld and not isContained  then
        p.HeldNPCIndex = MRINPC.idx+1
        MRINPC:mem(0x12C, FIELD_WORD, p.idx) -- Player carrying index
        if modernReserveItems.autoHold then
            p:mem(0x62, FIELD_WORD, modernReserveItems.timeAutoHeld) -- Force Hold Timer
        end
    elseif p.MountType == MOUNT_YOSHI and isHeld and not isContained  then
        p:mem(0xB8, FIELD_WORD, MRINPC.idx+1) -- Tongue contained NPC index
        p:mem(0xB6, FIELD_BOOL, true) -- Tongue retracting flag
        MRINPC:mem(0x138, FIELD_WORD, 6) -- Forced State/Contained In
        MRINPC:mem(0x13C, FIELD_DFLOAT, p.idx) -- Forced State Timer 1
        MRINPC:mem(0x144, FIELD_WORD, 5) -- Forced State Timer 2 https://github.com/smbx/smbx-legacy-source/blob/master/modPlayer.bas#L5790
        MRINPC:mem(0x124, FIELD_BOOL, false) -- "active" flag, has to do with respawning https://github.com/smbx/smbx-legacy-source/blob/master/modPlayer.bas#L5836
        
    elseif p.MountType == MOUNT_CLOWNCAR  and isHeld and not isContained  then
        MRINPC:mem(0x60, FIELD_WORD, p.idx) -- Clown Car Player
        MRINPC:mem(0x62, FIELD_WORD, 32) -- Distance from Clown Car
    end

    if modernReserveItems.spawnLayer then
        MRINPC.layerName = modernReserveItems.spawnLayer
    end

    if p.MountType == MOUNT_YOSHI and isHeld then
        if modernReserveItems.playSounds then
            Audio.playSFX(yoshiSFX)
        end
    elseif not isContained then
        if modernReserveItems.playSounds then
            Audio.playSFX(SFX)
        end
    end

    p.reservePowerup = 0
    modernReserveItems.onPostReserveUse(p, MRINPC)
    return MRINPC
end

function modernReserveItems.onInputUpdate()
    if not isOverworld and modernReserveItems.enabled and modernReserveItems.useBuiltInDrop then
        for _, p in ipairs(Player.get()) do
            p:mem(0x130,FIELD_BOOL,false) -- "DropRelease" from source, via MrDoubleA
            if p.reservePowerup ~= 0 and p.keys.dropItem == KEYS_PRESSED and not Misc.isPaused() and modernReserveItems.validityCheck(p.reservePowerup, p) then
                modernReserveItems.drop(p.reservePowerup, p)
            end
        end
    end
end

-- fix thrown npcs' dieing to contact with other npcs pt.2
local function removeMRINPCs(npc)
    npc.data.MRITagged = nil
    remove(mriNPCs,npc.data.MRIIndex)

    for k,v in ipairs(mriNPCs) do -- reshuffle indexes
        if v.isValid then
            v.data.MRIIndex = k
        end
    end
end

function modernReserveItems.onNPCHarm(eventToken, killedNPC, harmType, culpritOrNil)
    if culpritOrNil ~= nil and type(culpritOrNil) == "NPC" and (killedNPC.data.MRITagged or culpritOrNil.data.MRITagged) then
        eventToken.cancelled = true
    end
end

function modernReserveItems.onPostNPCKill(killedNPC, harmType)
    if killedNPC.data.MRITagged then
        removeMRINPCs(killedNPC)
    end
end

function modernReserveItems.onTickEnd()
    for _,n in ipairs(mriNPCs) do
        if n.isValid then
            if not n:mem(0x136, FIELD_BOOL) then
                removeMRINPCs(n)
            end
        end
    end
end

modernReserveItems.patterns = patterns

return modernReserveItems