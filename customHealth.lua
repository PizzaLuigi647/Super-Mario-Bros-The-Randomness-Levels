--[[
    By Marioman2007

    - better code
    - single player
    - no air meter
]]

local easing = require("ext/easing")
local hudoverride = require("hudoverride")
local npcManager = require("npcManager")
local health = {}

health.VFX = {
    meter_galaxy = Graphics.loadImageResolved("customHealth/healthGalaxy.png"),
    meter_odyssey = Graphics.loadImageResolved("customHealth/healthOdyssey.png"),
    life  = Graphics.loadImageResolved("customHealth/life.png"),
    hurt  = {
        Graphics.loadImageResolved("customHealth/hurtMario.png"),
        Graphics.loadImageResolved("customHealth/hurtLuigi.png"),
        Graphics.loadImageResolved("customHealth/hurtPeach.png"),
        Graphics.loadImageResolved("customHealth/hurtToad.png")
    }
}

health.GALAXY = "galaxy"
health.ODYSSEY = "odyssey"
health.MARIO64 = "mario64"

health.settings   = {
    -- Style to use, can be health.GALAXY or health.ODYSSEY. Visual only
    style = health.ODYSSEY,

    -- Position of the bar
    pos = vector(740, 60),

    -- Gap between two health bars
    gap = {galaxy = vector(-18, 0), odyssey = vector(0, 0)},

    -- Offset of the "Life" icon from the bar
    lifeTextGap = vector(0, -31),

    -- Bar shake intensity
    shakeOffset = 4,

    -- Width & Height of the player hurt frame (only applies if sheet is provided)
    cellSize = 100,

    -- Main health of the player, use health.change to change this value
    mainHealth = 3,

    -- Max health of the player, use health.change to change this value
    maxHealth = 6,

    -- Hurt state duration
    hurtDuration = 50,

    -- Hurt state frames (only applies if sheet is provided)
    hurtFrames = 2,

    -- Hurt animation speed
    hurtSpeed = 5,

    -- Earthquake intensity when getting hurt
    quakePower = 5,

    -- How fast the health gains one segment (used in max health anim)
    animSpeed = 16,

    -- Priority of the health bar
    priority = 5,

    -- Forcedstate of the hurt state
    forcedStateId = 752,

    -- Whether or not powerups are allowed in daredevil mode
    allowPowerups = true,

    -- The player starts at maximum health if set to true
    startAtMax = false,

    -- These powerups restore hp. Use the add/set functions in npc-n.lua files if its a custom NPC
    healingPowers = table.map{9, 184, 185, 249, 250},

    -- Frames for the hurt anim, used if no sheet is provide. One frame per character
    -- nil for current frame, number for a frame on the sprite sheet
    playerHurtFrames = {nil, 1, 1, 1},

    -- For smwMap, doesn't draw the bar if in this level
    mapFilename = "map.lvlx",

    -- The easing effect to use. I prefer: outQuad, outCubic, outSine, outCirc, outQuint
    -- Check "SMBX2/data/scripts/ext/easing.lua" for more functions
    -- Visualization: https://easings.net/
    easeEffect = "outCubic",
}

health.dareActive = false
health.curHealth = health.settings.mainHealth
health.freezeStates = table.map{ -- Forced states in the game will freeze
    FORCEDSTATE_POWERUP_BIG,
    FORCEDSTATE_POWERDOWN_SMALL,
    FORCEDSTATE_POWERUP_FIRE,
    FORCEDSTATE_POWERUP_LEAF,
    FORCEDSTATE_POWERUP_TANOOKI,
    FORCEDSTATE_POWERUP_HAMMER,
    FORCEDSTATE_POWERUP_ICE,
    FORCEDSTATE_POWERDOWN_FIRE,
    FORCEDSTATE_POWERDOWN_ICE,
    FORCEDSTATE_MEGASHROOM
}

local anotherPowerDown
pcall(function() anotherPowerDown = require("anotherPowerDownLibrary") end)

local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)

if not respawnRooms then respawnRooms = {onPreReset = function(a) end} end

local hurtAnimFrame = 0
local countFrame = 0
local animTimer = -1
local barLerp = 0
local offsetLerp = 0
local offset = 0
local lifeLerp = 0
local lifeOffset = 0
local isLerping = false
local counting = false
local animEnded = false
local storedPos = vector(0, 0)
local curPos = vector(0, 0)
local hurtLerp = 0
local hurtValue = 0
local hurtOffset = vector(0, 0)

local function stopAnim()
    Misc.unpause()
    isLerping = false
    animTimer = -1
    barLerp = 0
end

local function getInitHP()
    return (health.settings.startAtMax and health.settings.maxHealth) or health.settings.mainHealth
end

local function drawBar(img, x, y, w, h, frame, p, o)
    o = o or 1
    p = p or 0
    Graphics.drawImageWP(img, x-w/2+hurtOffset.x, y-h/2+hurtOffset.y, 0, h * frame, w, h, o, p)
end

local function setHurtFrame(p)
    local extraH = 0

    if p:mem(0x12E, FIELD_BOOL) then
        local ps = p:getCurrentPlayerSetting()
        extraH = ps.hitboxHeight - ps.hitboxDuckHeight
    else
        extraH = 0
    end

    if health.VFX.hurt[p.character] then
        p.frame = -50 * p.direction

        Graphics.drawBox{
            texture      = health.VFX.hurt[p.character],
            sceneCoords  = true,
            x            = p.x + p.width/2,
            y            = p.y-extraH + (p.height+extraH)/2,
            width        = health.settings.cellSize * p.direction,
            height       = health.settings.cellSize,
            sourceX      = 0,
            sourceY      = health.settings.cellSize * hurtAnimFrame,
            sourceWidth  = health.settings.cellSize,
            sourceHeight = health.settings.cellSize,
            centered     = true,
            priority     = -25,
        }
    elseif type(health.settings.playerHurtFrames[p.character]) == "number" then
        p:setFrame(health.settings.playerHurtFrames[p.character])
    end
end

-- draws the bars
function health.drawHealth()
    if isOverworld or Level.filename() == health.mapFilename then return end

    local settings = health.settings
    local metImg   = health.VFX["meter_"..settings.style]
    local width    = metImg.width
    local height   = metImg.height/(settings.maxHealth + 3)
    local pos      = settings.pos
    local lifeW    = health.VFX.life.width
    local lifeH    = health.VFX.life.height
    local gap      = settings.gap[settings.style]
    local mFrame   = (health.dareActive and settings.maxHealth + 2) or math.min(health.curHealth, settings.mainHealth)
    local useFrame = (player.deathTimer == 0 and mFrame) or 0

    -- "Life" icon
    Graphics.drawImageWP(
        health.VFX.life,
        pos.x - lifeW/2 + lifeOffset+gap.x + hurtOffset.x + settings.lifeTextGap.x,
        pos.y - lifeH/2 + settings.lifeTextGap.y+hurtOffset.y,
        health.settings.priority+0.2
    )

    -- 0 to main health/daredevil health
    drawBar(metImg, pos.x, pos.y, width, height, useFrame, health.settings.priority, 1)

    -- main+1 to max health
    if (counting or isLerping) or (health.curHealth > settings.mainHealth or offsetLerp > 0) then
        local frame = ((counting or isLerping) and settings.mainHealth + math.clamp(countFrame, 1, 4)) or (health.curHealth + 1)

        if not (counting or isLerping) and health.curHealth <= settings.mainHealth and offsetLerp < 1 then
            frame = settings.mainHealth + 1
        end

        drawBar(metImg, curPos.x, curPos.y+offset, width, height, frame, health.settings.priority+0.1, offsetLerp)
    end
end

-- returns true if health is full
function health.isFull()
    return health.curHealth == health.settings.mainHealth or health.curHealth == health.settings.maxHealth
end

-- adds the given amount to current health
function health.add(x)
    local extraHp = health.settings.mainHealth - health.curHealth

    if health.curHealth <= health.settings.mainHealth and x > extraHp then
        x = extraHp
    end

    health.curHealth = math.clamp(health.curHealth + x, 0, health.settings.maxHealth)
end

-- sets health to the given amount
function health.set(x)
    if x > health.settings.mainHealth then
        curPos.x = health.settings.pos.x + health.settings.gap[health.settings.style].x
        curPos.y = health.settings.pos.y + health.settings.gap[health.settings.style].y
        offsetLerp = 1
        lifeLerp = 1
    end

    health.curHealth = math.clamp(x, 0, health.settings.maxHealth)
end

-- changes the main health and max health
function health.change(main, max, dontChangeCurrent)
    local settings = health.settings
    local oldMain, oldMax = settings.mainHealth, settings.maxHealth

    max = max or settings.maxHealth
    settings.mainHealth = main
    settings.maxHealth = max

    if not dontChangeCurrent then
        if settings.startAtMax then
            health.set(math.max(1, health.curHealth + (max - oldMax)))
        else
            health.set(math.max(1, health.curHealth + (main - oldMain)))
        end
    end
end

-- maximizes the health with an animation
function health.setMax()
    Misc.pause()
    barLerp = 0
    animEnded = false
    countFrame = 0
    animTimer = 0
    storedPos = vector(player.x - camera.x, player.y - camera.y)
    curPos = vector(player.x - camera.x, player.y - camera.y)
    counting = true
    offsetLerp = 0
    lifeLerp = 0
end

-- register events
function health.onInitAPI()
    registerEvent(health, "onTick")
    registerEvent(health, "onDraw")
    registerEvent(health, "onPostNPCKill")
    registerEvent(health, "onPlayerHarm")
    registerEvent(health, "onPostPlayerKill")

    registerEvent(health, "onReset")
    registerCustomEvent(health, "onPlayerHurt")
end

-- compatibility with respawnRooms.lua and rooms.lua
function respawnRooms.onPreReset(fromRespawn)
    health.set(getInitHP())
end

function health.onReset(fromRespawn)
    health.set(getInitHP())
end

-- some stuff
function health.onTick()
    local settings = health.settings
    local inFrzState = player.forcedState == health.settings.forcedStateId or health.freezeStates[player.forcedState]

    Defines.levelFreeze = (inFrzState or mem(0x00B2C62E,FIELD_WORD,  0))
    health.curHealth = math.max(health.curHealth, 0)

    if health.curHealth == 0 and player.deathTimer == 0 then
        player:kill()
    end

    if player.forcedState ~= FORCEDSTATE_POWERUP_BIG and player.powerup == 1 then
        player.powerup = 2
    end

    if player.forcedState == settings.forcedStateId then
        local frameCount = (health.VFX.hurt[player.character] and settings.hurtFrames) or 2

        player.forcedTimer = player.forcedTimer + 1
        hurtAnimFrame = math.floor(player.forcedTimer / settings.hurtSpeed) % frameCount

        if player.forcedTimer >= settings.hurtDuration then
            player.forcedState = 0
            player:mem(0x140, FIELD_WORD, 150)
            player.forcedTimer = 0
            hurtAnimFrame = 0
        end
    end

    if health.dareActive then
        if not settings.allowPowerups then
            player.powerup = 2
        end

        if player.deathTimer == 0 then
            health.curHealth = 1
        end
    end
end

-- some calculations and rendering
function health.onDraw()
    local settings = health.settings
    local diff = settings.maxHealth - settings.mainHealth + 2
    local barHeight = health.VFX["meter_"..settings.style].height/(settings.maxHealth + 3)
    local gap = settings.gap[settings.style]

    if animTimer >= 0 then
        animTimer = animTimer + 1
    end

    if counting then
        offsetLerp = math.min(offsetLerp + 0.075, 1)
    elseif health.curHealth <= settings.mainHealth and not isLerping then
        offsetLerp = math.max(offsetLerp - 0.075, 0)
    end

    if health.curHealth > settings.mainHealth then
        lifeLerp = math.min(lifeLerp + 0.05, 1)
    else
        lifeLerp = math.max(lifeLerp - 0.05, 0)
    end

    if hurtValue ~= 0 then
        hurtLerp = math.min(hurtLerp + 0.04, 1)
        hurtOffset.x = math.floor(easing.inOutBack(hurtLerp, hurtValue, -hurtValue, 1, -hurtValue) + 0.5)
        hurtOffset.y = math.floor(easing.inOutBack(hurtLerp, -hurtValue, hurtValue, 1, hurtValue) + 0.5)

        if hurtLerp == 1 then
            hurtLerp = 0
            hurtValue = 0
            hurtOffset = vector(0, 0)
        end
    end

    if countFrame < diff and counting and offsetLerp == 1 then
        countFrame = (math.floor(animTimer / settings.animSpeed) % diff) + 1
    elseif countFrame == diff and not animEnded then
        counting = false
        isLerping = true
        animEnded = true
    end

    if isLerping then
        barLerp = math.min(barLerp + 0.025, 1)

        curPos.x = math.floor(easing[settings.easeEffect](barLerp, storedPos.x, settings.pos.x + gap.x - storedPos.x, 1) + 0.5)
        curPos.y = math.floor(easing[settings.easeEffect](barLerp, storedPos.y, settings.pos.y + gap.y - storedPos.y, 1) + 0.5)

        if barLerp == 1 then
            stopAnim()
            health.set(health.settings.maxHealth)
            lifeLerp = 0
        end
    end

    if not health.dareActive and player.deathTimer == 0 and health.curHealth > 0
    and player.forcedState == settings.forcedStateId then
        setHurtFrame(player)
    end

    -- this needs to stay here until onNPCCollect gets into basegame
    if settings.healingPowers[player.reservePowerup] then
        player.reservePowerup = 0
    end

    player:mem(0x16, FIELD_WORD, 2)
    hudoverride.visible.itembox = (Graphics.getHUDType(player.character) ~= Graphics.HUD_HEARTS)

    offset = math.floor(easing[settings.easeEffect](offsetLerp, barHeight, -barHeight, 1) + 0.5)
    lifeOffset = math.floor(easing[settings.easeEffect](lifeLerp, -gap.x, gap.x, 1) + 0.5)
    health.drawHealth()
end

-- add health if collecting a healing powerup
function health.onPostNPCKill(v, r)
    local p = npcManager.collected(v, r)

    if not p or r ~= HARM_TYPE_VANISH or health.dareActive then
        return
    end

    if health.settings.healingPowers[v.id] and not health.isFull() then
        health.add(1)
    end
end

-- main stuff
function health.onPlayerHarm(e, p)
    if e.cancelled then return end
    if p.powerup > 2 and anotherPowerDown ~= nil then return end -- let anotherPowerDown do its thing

    local eventToken = {cancelled = false}
    health.onPlayerHurt(eventToken, p)

    if eventToken.cancelled then
        e.cancelled = true
        return
    end

    if p.deathTimer == 0 and (p.mount ~= MOUNT_BOOT and p.mount ~= MOUNT_YOSHI) and not p.hasStarman and health.curHealth > 0 then
        if not health.dareActive then
            if p.powerup > 2 then
                p.powerup = 2
            else
                health.add(-1)
            end

            SFX.play(5)
            p.forcedState = health.settings.forcedStateId
        else
            p:kill()
            health.curHealth = 0
        end

        if hurtValue == 0 then
            hurtValue = RNG.irandomEntry{-health.settings.shakeOffset, health.settings.shakeOffset}
        end

        if Defines.earthquake < health.settings.quakePower then -- don't cancel an on-going quake
            Defines.earthquake = health.settings.quakePower
        end
    
        e.cancelled = true
    end
end

-- set health to 0 on death
function health.onPostPlayerKill(p)
    health.curHealth = 0
end

return health