--------------------------------------------------
--[[ modernReserveItems.lua v2.0 by KBM-Quine ]]--
--[[    massive amounts of code help from:    ]]--
--[[        rixithechao, Enjl, Hoeloe,        ]]--
--[[    PixelPest, MrDoubleA, and Rednaxela.  ]]--
--[[    credit to Hoeloe, and Rednaxela       ]]--
--[[  for code taken from npcconfig_core.lua. ]]--
--------------------------------------------------
local modernReserveItems = {}

local pm = require("playermanager")
local configTypes = require("configtypes")

modernReserveItems.enabled = true                                      -- toggle for library functionality
modernReserveItems.autoHold = true                                     -- whether held items get automatically held after dropping
modernReserveItems.timeAutoHeld = 32                                   -- duration autohold lasts
modernReserveItems.playSounds = true                                   -- whether the library should play sounds on drop
modernReserveItems.playerXMomentum = 0                                 -- amount of X speed thrown items inhert from the player
modernReserveItems.playerYMomentum = 0                                 -- amount of Y speed thrown items inhert from the player
modernReserveItems.spawnLayer = "Spawned NPCs"                         -- layer name items get spawned to
modernReserveItems.allowThrownItems = true                             -- whether thrown items can be dropped at all
modernReserveItems.allowHeldItems = true                               -- whether held items can be dropped at all
modernReserveItems.allowHeldItemsInWarps = true                        -- whether items can be dropped while warping (should the warp allow it)
modernReserveItems.allowForcedStateItems = true                        -- whether any forcedstate items can be dropped at all
modernReserveItems.allowAnyItems = true                                -- whether any items can be dropped at all
modernReserveItems.useBuiltInDrop = true                               -- whether modernReserveItems.lua should handle droping or not
modernReserveItems.offScreenDespawn = Defines.npc_despawntimer * 20    -- amount despawn timer is set to for dropped items

local mriNPCs = {}
local remove = table.remove

modernReserveItems.config = {}

-- start of things taken from npcconfig_core.lua

local configTables = {
    speedX          = {t="number", default=0},
    speedY          = {t="number", default=0},
    isHeld          = {t="boolean", default=true},
    isThrown        = {t="boolean", default=false},
    forcedState     = {t="number", default=0},
    doesntMove      = {t="boolean", default=false},
    idOverwrite     = {t="number", default=0},
    sfx             = {t="sound", default=23},
    yoshiSFX        = {t="sound", default=50},
    ai1             = {t="number", default=0},
    ai2             = {t="number", default=0},
    ai3             = {t="number", default=0},
    ai4             = {t="number", default=0},
    ai5             = {t="number", default=0},
    ai6             = {t="number", default=0},
    data            = {t="table", default=configTypes.asArray{}},
}

local function getDefaultFromType(t)
	if t == "number" then
		return 0
	elseif t == "boolean" then
		return false
	end
end

local escapeName
do
	local string_lower, string_gsub = string.lower, string.gsub
	function escapeName(name)
		return string_lower(name)
	end
end

local extraProperties, extraTypes, propsNextMap
do
    extraProperties = {}
    extraTypes = {}
    propsNextMap = {}
    
    local standardPropsNextMap = {}
    local standardPropsList = table.unmap(configTables)
    for k,v in ipairs(standardPropsList) do
        standardPropsNextMap[v] = standardPropsList[k+1]
        standardPropsNextMap[0] = v
    end
    standardPropsNextMap[""] = standardPropsList[1]
    for i = 1, NPC_MAX_ID do
        extraProperties[i] = {}
        extraTypes[i] = {}
        propsNextMap[i] = table.clone(standardPropsNextMap)
    end
end

local function nextProp(t, k)
	local nextKey = propsNextMap[t.id][k]
	if nextKey ~= nil then
		return nextKey, t[nextKey]
	end
end

metaConfig = {
    __newindex = function (tbl, key, value)
		local config = configTables[key]
	
        local configType;
        if config ~= nil then
            configType = config.t
        else
            configType = extraTypes[tbl.id][key]
        end
        if configType == "sound" then
            if type(value) == "number" then
                configType = type(value)
            elseif type(value) == "string" then
                configType = type(value)
            end
        end
        if configType == nil  then
            error("Config " .. key .. " not registered for NPC " .. tbl.id)
        elseif configType ~= type(value) then

            value = configTypes.convertconfigType(value, configType)

            if (config ~= nil and config.set ~= nil) then
                value = config.set(value, extraProperties[tbl.id][key])
            end
        end
        local ov = extraProperties[tbl.id][key]
        if config ~= nil and ov == nil then
            ov = config.default
        end
        extraProperties[tbl.id][key] = value
	end,
	__index = function (tbl, key)
		local config = configTables[key]

        if config ~= nil then
            if (config.get ~= nil) then
                return config.get(extraProperties[tbl.id], extraProperties[tbl.id][key])
            end

            if extraProperties[tbl.id][key] == nil then
                if config.default == nil then
                    return getDefaultFromType(config.t)
                else
                    return config.default
                end
            else
                return extraProperties[tbl.id][key]
            end
        else
            return extraProperties[tbl.id][key]
        end
	end,
	__pairs = function (tbl)
		return nextProp, tbl, ""
	end
}

setmetatable(modernReserveItems.config, {
	__newindex = function (tbl, key, value)
		error("Cannot assign directly to NPC's config. Try assigning to a field instead.", 2)
	end,
	__index = function (tbl, key)
		if type(key) == "number" and key >= 1 and key <= NPC_MAX_ID then
			local val = {id = key}
			setmetatable(val, metaConfig)
			rawset(tbl,key,val)
			return val
		else
			error("NPC ID was not a number or outside of ID range.", 2)
		end
	end
})
-- end of things taken from npcconfig_core.lua

-- helper function; makes setting alot of configs at once easier
function modernReserveItems.setConfigs(id, table)
    for k, v in pairs(table) do
        modernReserveItems.config[id][k] = v
    end
end
-- set up defaults for items
do   
    for k,v in ipairs({9, 75, 90, 153, 184, 185, 186, 187, 273, 462}) do -- npcs that need "don't move" set to move horizontally (mushrooms mostly)
        modernReserveItems.setConfigs(v, {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
    end
    for k,v in ipairs({16, 41, 97}) do -- exits? i don't know why their are here honestly (maybe for The Reservatorium?)
        modernReserveItems.setConfigs(v, {speedX = 5, speedY = -6, isHeld = false, isThrown = true, forcedState = 0, doesntMove = false, sfx = 11})
    end
    for k,v in ipairs({14, 34, 94, 101, 102, 198} ) do -- powerups that can only move upwards for redigt reasons
        modernReserveItems.setConfigs(v, {speedX = 0, speedY = -7, isHeld = false, isThrown = true, forcedState = 0, doesntMove = false, sfx = 11})
    end
    for k,v in ipairs({169, 170, 182, 183, 240, 249, 254, 264, 277, 559}) do -- powerups
        modernReserveItems.setConfigs(v, {speedX = 0, speedY = -7, isHeld = false, isThrown = true, forcedState = 0, doesntMove = false, sfx = 11})
    end
    for k,v in ipairs({95, 98, 99, 100, 148, 149, 150, 228}) do -- yoshis
        modernReserveItems.setConfigs(v, {idOverwrite = 96, ai1 = v})
    end
    for k,v in ipairs({240, 248}) do -- stop watches
        modernReserveItems.setConfigs(v, {isHeld = false, forcedState = 2, doesntMove = false, sfx = 11})
    end
    -- 3-up moon
    modernReserveItems.setConfigs(150, {speedX = 6, speedY = 0, isHeld = false, isThrown = true, sfx = 11})
    -- starman
    modernReserveItems.setConfigs(293, {speedX = 1.5, speedY = -3, isHeld = false, isThrown = true, sfx = 11})
    -- mega mushroom
    modernReserveItems.setConfigs(425, {speedX = 1, speedY = -3, isHeld = false, isThrown = true, sfx = 11})
end

function modernReserveItems.onInitAPI()
	registerEvent(modernReserveItems, "onInputUpdate")
	registerEvent(modernReserveItems, "onNPCHarm")
	registerEvent(modernReserveItems, "onPostNPCKill")
	registerEvent(modernReserveItems, "onTickEnd")
    registerCustomEvent(modernReserveItems,"onReserveUse")
    registerCustomEvent(modernReserveItems,"onPostReserveUse")
end
-- P's & Q's checker. made so external sources can optionally check these themselves
function modernReserveItems.validityCheck(ID, p)
    local config = modernReserveItems.config[ID]
    local npcID = ID
    if config.idOverwrite ~= 0 then
        npcID = config.idOverwrite
    end
    local bool = true
    if p.ForcedAnimationState == 7 or p.ForcedAnimationState == 3 then -- items in warps/clearpipes handling
        if  Warp.get()[p.TargetWarpIndex] ~= nil and not Warp.get()[p.TargetWarpIndex].allowItems then bool = false end
        if not modernReserveItems.allowHeldItemsInWarps or (config.isThrown or config.forcedState > 0) then
            bool = false
        end
    end
    for _,v in ipairs({1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 41, 227, 228, 500}) do -- don't allow spawning if the player is in a forced state
        if p.ForcedAnimationState == v then
            bool = false
        end
    end
    if p.MountType == MOUNT_YOSHI and NPC.config[npcID].noyoshi and config.isHeld then bool = false end     -- if on yoshi, don't spawn an item that doesn't allow yoshi to eat it
    if p.MountType == MOUNT_BOOT and config.isHeld then bool = false end                                    -- cancel spawn if your in a boot. can't hold something if your in a boot afterall
    if p:mem(0xB8, FIELD_WORD) ~= 0 and config.isHeld then bool = false end                                 -- cancel spawn if yoshi is holding something
    if p.holdingNPC ~= nil and config.isHeld then bool = false end                                          -- cancel spawn if your already holding somehing. you can't hold more then one item afterall
    if p.inLaunchBarrel then bool = false end                                                               -- cancel spawn if your  can't hold things in a launch barrel.  can't hold things in a launch barrel afterall 
    if p.ClimbingState > 0 and config.isHeld then bool = false end                                          -- cancel spawn if your climbing. you can't climb and hold an item afterall
    if not p.TanookiStatueActive and config.isHeld then bool = false end                                    -- cancel spawn if your a statue. can't hold something if you can't move your hands afterall
    if p.deathTimer > 0 then bool = false end                                                               -- cancel spawn if your dead. would be a waste of an item otherwise
    if Level.endState() > 0 then bool = false end                                                           -- don't allow spawning if the game is in a winning state. would be a waste of an item otherwise
    if not modernReserveItems.allowThrownItems and config.isThrown then bool = false end                    -- if the library is set to not allow thrown items, cancel spawn
    if not modernReserveItems.allowHeldItems and config.isHeld then bool = false end                        -- if the library is set to not allow holding items, cancel spawn
    if not modernReserveItems.allowForcedStateItems and config.forcedState > 0 then bool = false end        -- if the library is set to not allow items with forcedstates, cancel spawn
    if not modernReserveItems.allowAnyItems then bool = false end                                           -- if the library is set to not allow any items, cancel spawn

    return bool
end
-- heart & soul of the library
function modernReserveItems.drop(ID, p)
    local ps = PlayerSettings.get(pm.getCharacters()[p.character].base, p.powerup)
    local config = modernReserveItems.config[ID]
    local npcID = ID
    if config.idOverwrite ~= 0 then
        npcID = config.idOverwrite
    end
    -- event caller; allows external libraries & code to mess with drops 
    local eventObj = {cancelled = false}
    EventManager.callEvent("onReserveUse", eventObj, ID, p)
    if eventObj.cancelled then return nil end
    -- X/Y handling
    local spawnedX = p.x+(p.width*0.5)
    local spawnedY = p.y+(p.height*0.5)
    if config.forcedState == 0 then
        -- y adjustment cases
        if p.MountType == MOUNT_CLOWNCAR then
            spawnedY = p.y + 16 - (NPC.config[npcID].height*0.5)
        else
            if config.isHeld then
                spawnedY = p.y+ps.grabOffsetY + 32 - NPC.config[npcID].height
            end
        end
        -- x adjustment cases
        if p.MountType == MOUNT_CLOWNCAR and config.isHeld then
            spawnedX = p.x+(p.width*0.5)+(48*p.direction)
        elseif config.isHeld then
            spawnedX = p.x+(p.width*0.5)+((p.width*0.25)*p.direction)
        end
    end
    -- spawn the npc
    local MRINPC = NPC.spawn(npcID, spawnedX, spawnedY, p.section, false, true)
    MRINPC.despawnTimer = modernReserveItems.offScreenDespawn
    MRINPC.direction = p.direction
    MRINPC.dontMove = config.doesntMove
    -- thrown behaviour
    if config.doesntMove and config.isThrown then
        MRINPC.isProjectile = true -- Projectile Flag

        -- fix for thrown npcs' dieing to contact with other npcs pt.1
        MRINPC.data.MRITagged = true
        MRINPC.data.MRIIndex = #mriNPCs+1
        mriNPCs[#mriNPCs+1] = MRINPC
    end
    MRINPC.forcedState = config.forcedState --Forced State
    MRINPC:mem(0x132, FIELD_WORD, p.idx) -- Thrown by Player
    -- copy the data config to the npc's .data table
    for  k,v in pairs(config.data)  do
        MRINPC.data[k] = v
    end
    -- ai# setting; useful for containers
    MRINPC.ai1 = config.ai1
    MRINPC.ai2 = config.ai2
    MRINPC.ai3 = config.ai3
    MRINPC.ai4 = config.ai4
    MRINPC.ai5 = config.ai5
    MRINPC.ai6 = config.ai6
    --if not put in a forced state, set things so items won't hurt player on drop
    if config.forcedState == 0 then
        MRINPC:mem(0x12E, FIELD_WORD, Defines.npc_throwfriendlytimer) -- Grab Timer
        MRINPC:mem(0x130, FIELD_WORD, p.idx) -- Grabbing Player
    end
    -- speed handling for thrown items
    if config.isThrown then
        if config.speedX ~= nil then
            MRINPC.speedX = config.speedX*MRINPC.direction+(p.speedX*modernReserveItems.playerXMomentum)
        end
        if config.speedY ~= nil then
            MRINPC.speedY = config.speedY+(p.speedY*modernReserveItems.playerYMomentum)
        end
    end
    -- holding handling; determines how being held works between mounts
    if p.MountType == MOUNT_NONE and config.isHeld and config.forcedState == 0  then
        p.HeldNPCIndex = MRINPC.idx+1
        MRINPC:mem(0x12C, FIELD_WORD, p.idx) -- Player carrying index
        if modernReserveItems.autoHold then
            p:mem(0x62, FIELD_WORD, modernReserveItems.timeAutoHeld) -- Force Hold Timer
        end
    elseif p.MountType == MOUNT_YOSHI and config.isHeld and config.forcedState == 0  then
        p:mem(0xB8, FIELD_WORD, MRINPC.idx+1) -- Tongue contained NPC index
        p:mem(0xB6, FIELD_BOOL, true) -- Tongue retracting flag
        MRINPC.forcedState = 6 -- Forced State/Contained In
        forcedCounter1 = p.idx -- Forced State Timer 1
        forcedCounter2 = 5 -- Forced State Timer 2 https://github.com/smbx/smbx-legacy-source/blob/master/modPlayer.bas#L5790
        MRINPC:mem(0x124, FIELD_BOOL, false) -- "active" flag, has to do with respawning https://github.com/smbx/smbx-legacy-source/blob/master/modPlayer.bas#L5836
        
    elseif p.MountType == MOUNT_CLOWNCAR  and config.isHeld and config.forcedState == 0  then
        MRINPC:mem(0x60, FIELD_WORD, p.idx) -- Clown Car Player
        MRINPC:mem(0x62, FIELD_WORD, 32) -- Distance from Clown Car
    end
    -- set the layer items are dropped on
    if modernReserveItems.spawnLayer ~= "" then
        MRINPC.layerName = modernReserveItems.spawnLayer
    end
    -- if allowed, play the sound given in the items config
    if modernReserveItems.playSounds then
        if p.MountType == MOUNT_YOSHI and config.isHeld then
            SFX.play(config.yoshiSFX)
        else
            SFX.play(config.sfx)
        end
    end

    p.reservePowerup = 0
    EventManager.callEvent("onPostReserveUse", MRINPC, p) -- event caller; allows external libraries & code to mess with drops after successfully dropping
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
-- check that either the dieing or killing npc is tagged and cancel the harm event
function modernReserveItems.onNPCHarm(eventToken, killedNPC, harmType, culpritOrNil)
    if culpritOrNil ~= nil and type(culpritOrNil) == "NPC" and (killedNPC.data.MRITagged or culpritOrNil.data.MRITagged) then
        eventToken.cancelled = true
    end
end
-- if the npc is successfully killed and has been tagged, remove it from the list
function modernReserveItems.onPostNPCKill(killedNPC, harmType)
    if killedNPC.data.MRITagged then
        removeMRINPCs(killedNPC)
    end
end
-- if the npc has become invalid between ticks, remove it from the list
function modernReserveItems.onTickEnd()
    for _,n in ipairs(mriNPCs) do
        if n.isValid then
            if not n.isProjectile then
                removeMRINPCs(n)
            end
        end
    end
end

return modernReserveItems