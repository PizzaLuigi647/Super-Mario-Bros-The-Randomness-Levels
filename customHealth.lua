--[[
    By Marioman2007 [v1.2]

    - better code
    - single player
    - no air meter
]]

local easing = require("ext/easing")
local hudoverride = require("hudoverride")

local p = player
local health = {}

health.images = {
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

health.VFX = health.images
health.GALAXY = "galaxy"
health.ODYSSEY = "odyssey"
health.MARIO64 = "mario64"

health.settings   = {
    -- Style to use, can be health.GALAXY or health.ODYSSEY. Visual only
    style = health.GALAXY,

    -- Position of the bar
    pos = vector(740, 60),

    -- Gap between two health bars
    gap = {galaxy = vector(-18, 0), odyssey = vector(0, 0)},

    -- Offset of the "Life" icon from the bar
    lifeTextGap = vector(0, -32),

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
    -- false for current frame, number for a frame on the sprite sheet
    playerHurtFrames = {false, 1, 1, 1},

    -- For smwMap, doesn't draw the bar if in this level
    mapFilename = "map.lvlx",

    -- The easing effect to use. I prefer: outQuad, outCubic, outSine, outCirc, outQuint
    easeEffect = "outCubic",

    -- default powerup of the player, can be a number for vanilla powerup or a string for a powerup made with customPowerups
    defaultPowerup = 2,

    -- if set to false, the game will not freeze when in a hurtState
    freezeGame = true,

    -- set to false to disable drawing the health bars
    drawHealthBar = true,

    -- offset of the 2nd bar when collecting a life-up shroom
    countOffset = vector(0, -60),

    -- SFX to play when getting hurt
    hurtSFX = {id = 5, volume = 1},

    -- SFX to play when getting healed
    healSFX = {id = 6, volume = 1},
}

health.dareActive = false
health.curHealth = health.settings.mainHealth
health.freezeStates = table.map{ -- Forced states in which the game will freeze
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

local settings = health.settings
local oldItemBox = nil

local anotherPowerDown
pcall(function() anotherPowerDown = require("anotherPowerDownLibrary") end)

local GP
pcall(function() GP = require("GroundPound") end)

local cp
pcall(function() cp = require("customPowerups") end)

local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)

respawnRooms = respawnRooms or {respawnSettings = {respawnPowerup = 1}}

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
local hurtValue = vector(0, 0)
local hurtOffset = vector(0, 0)

local function SFXPlay(sfx)
    if sfx and sfx.id then
        SFX.play(sfx.id, sfx.volume)
    end
end

local function stopAnim()
    Misc.unpause()
    isLerping = false
    animTimer = -1
    barLerp = 0
end

local function getInitHP()
    return (settings.startAtMax and settings.maxHealth) or settings.mainHealth
end

local function getPowerup()
    if cp then
        return cp.getCurrentName(p)
    end

    return p.powerup
end

local function setPowerup(id)
    if cp then
        cp.setPowerup(id, p, true)
    else
        p.powerup = id
    end
end

local function drawBar(img, x, y, w, h, frame, pri, o)
    o = o or 1
    pri = pri or 0
    Graphics.drawImageWP(img, x-w/2+hurtOffset.x, y-h/2+hurtOffset.y, 0, h * frame, w, h, o, pri)
end

local function setHurtFrame()
    local extraH = 0

    if p:mem(0x12E, FIELD_BOOL) then
        local ps = p:getCurrentPlayerSetting()
        extraH = ps.hitboxHeight - ps.hitboxDuckHeight
    else
        extraH = 0
    end

    if health.images.hurt[p.character] then
        p.frame = -50 * p.direction

        Graphics.drawBox{
            texture      = health.images.hurt[p.character],
            sceneCoords  = true,
            x            = p.x + p.width/2,
            y            = p.y-extraH + (p.height+extraH)/2,
            width        = settings.cellSize * p.direction,
            height       = settings.cellSize,
            sourceX      = 0,
            sourceY      = settings.cellSize * (math.floor(p.forcedTimer / settings.hurtSpeed) % settings.hurtFrames),
            sourceWidth  = settings.cellSize,
            sourceHeight = settings.cellSize,
            centered     = true,
            priority     = -25,
        }
    elseif type(settings.playerHurtFrames[p.character]) == "number" then
        p:setFrame(settings.playerHurtFrames[p.character])
    end
end

-- draws the bars
function health.drawHealth()
    local metImg   = health.images["meter_"..settings.style]
    local width    = metImg.width
    local height   = metImg.height/(settings.maxHealth + 3)
    local pos      = settings.pos
    local lifeW    = health.images.life.width
    local lifeH    = health.images.life.height
    local gap      = settings.gap[settings.style]
    local mFrame   = (health.dareActive and settings.maxHealth + 2) or math.min(health.curHealth, settings.mainHealth)
    local useFrame = (p.deathTimer == 0 and mFrame) or 0

    -- "Life" icon
    Graphics.drawImageWP(
        health.images.life,
        pos.x - lifeW/2 + lifeOffset+gap.x + hurtOffset.x + settings.lifeTextGap.x,
        pos.y - lifeH/2 + settings.lifeTextGap.y+hurtOffset.y,
        settings.priority+0.2
    )

    -- 0 to main health/daredevil health
    drawBar(metImg, pos.x, pos.y, width, height, useFrame, settings.priority, 1)

    -- main+1 to max health
    if (counting or isLerping) or (health.curHealth > settings.mainHealth or offsetLerp > 0) then
        local frame = ((counting or isLerping) and settings.mainHealth + math.clamp(countFrame, 1, 4)) or (health.curHealth + 1)

        if not (counting or isLerping) and health.curHealth <= settings.mainHealth and offsetLerp < 1 then
            frame = settings.mainHealth + 1
        end

        drawBar(metImg, curPos.x, curPos.y+offset, width, height, frame, settings.priority+0.1, offsetLerp)
    end
end

-- returns true if health is full
function health.isFull()
    return health.curHealth == settings.mainHealth or health.curHealth == settings.maxHealth
end

-- adds the given amount to current health
function health.add(x)
    local extraHp = settings.mainHealth - health.curHealth

    if health.curHealth <= settings.mainHealth and x > extraHp then
        x = extraHp
    end

    health.curHealth = math.clamp(health.curHealth + x, 0, settings.maxHealth)
end

-- sets health to the given amount
function health.set(x)
    if x > settings.mainHealth then
        curPos.x = settings.pos.x + settings.gap[settings.style].x
        curPos.y = settings.pos.y + settings.gap[settings.style].y
        offsetLerp = 1
        lifeLerp = 1
    end

    health.curHealth = math.clamp(x, 0, settings.maxHealth)
end

-- maximizes the health with an animation
function health.setMax()
    local x = p.x + p.width/2 - camera.x + settings.countOffset.x
    local y = p.y + p.height/2 - camera.y + settings.countOffset.y

    Misc.pause()
    barLerp = 0
    animEnded = false
    countFrame = 0
    animTimer = 0
    storedPos = vector(x, y)
    curPos = vector(x, y)
    counting = true
    offsetLerp = 0
    lifeLerp = 0
end

-- register events
function health.onInitAPI()
    registerEvent(health, "onStart")
    registerEvent(health, "onTick")
    registerEvent(health, "onDraw")
    registerEvent(health, "onNPCCollect")
    registerEvent(health, "onPlayerHarm")
    registerEvent(health, "onPostPlayerKill")

    registerCustomEvent(health, "onPlayerHurt")
    registerCustomEvent(health, "onPostPlayerHurt")
end

-- compatibility with respawnRooms.lua and rooms.lua
function respawnRooms.onPostReset(fromRespawn)
    if not fromRespawn then return end

    local power = respawnRooms.respawnSettings.respawnPowerup

    health.set(getInitHP())
    
    if settings.defaultPowerup ~= power and getPowerup() == power then
        setPowerup(settings.defaultPowerup)
    end
end

-- set the powerup on the first frame
function health.onStart()
    health.set(getInitHP())

    if settings.defaultPowerup ~= 1 and getPowerup() == 1 then
        setPowerup(settings.defaultPowerup)
    end
end

-- some stuff
function health.onTick()
    local inFrzState = (p.forcedState == settings.forcedStateId or health.freezeStates[p.forcedState]) and settings.freezeGame

    Defines.levelFreeze = (inFrzState or mem(0x00B2C62E,FIELD_WORD,  0))
    health.curHealth = math.max(health.curHealth, 0)

    if health.curHealth == 0 and p.deathTimer == 0 then
        p:kill()
    end

    if health.dareActive and not settings.allowPowerups and getPowerup() ~= settings.defaultPowerup then
        setPowerup(settings.defaultPowerup)
    end

    if p.forcedState == settings.forcedStateId then
        p.forcedTimer = p.forcedTimer + 1

        if p.forcedTimer >= settings.hurtDuration then
            p.forcedState = 0
            p:mem(0x140, FIELD_WORD, 150)
            p.forcedTimer = 0
        end
    end
end

-- some calculations and rendering
function health.onDraw()
    local diff = settings.maxHealth - settings.mainHealth + 2
    local barHeight = health.images["meter_"..settings.style].height/(settings.maxHealth + 3)
    local gap = settings.gap[settings.style]
    local easeFunc = easing[settings.easeEffect]

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

    if hurtValue.x ~= 0 and hurtValue.y ~= 0 then
        hurtLerp = math.min(hurtLerp + 0.04, 1)
        hurtOffset = easing.inOutBack(hurtLerp, hurtValue, -hurtValue, 1, -hurtValue)

        if hurtLerp == 1 then
            hurtLerp = 0
            hurtValue = vector(0, 0)
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
        curPos = easeFunc(barLerp, storedPos, settings.pos + gap - storedPos, 1)

        if barLerp == 1 then
            stopAnim()
            health.set(settings.maxHealth)
            lifeLerp = 0
        end
    end

    p:mem(0x16, FIELD_WORD, 2)
    offset = easeFunc(offsetLerp, barHeight, -barHeight, 1)
    lifeOffset = easeFunc(lifeLerp, -gap.x, gap.x, 1)

    if not health.dareActive and p.deathTimer == 0 and health.curHealth > 0
    and p.forcedState == settings.forcedStateId and (not GP or GP.getData(p.idx).state == GP.STATE_NONE) then
        setHurtFrame()
    end

    if Graphics.getHUDType(p.character) == Graphics.HUD_HEARTS then
        if oldItemBox == nil then
            oldItemBox = hudoverride.visible.itembox
            hudoverride.visible.itembox = false
        end
    else
        if oldItemBox ~= nil then
            hudoverride.visible.itembox = oldItemBox
            oldItemBox = nil
        end
    end

    if not isOverworld
    and Level.filename() ~= settings.mapFilename
    and Graphics.isHudActivated()
    and settings.drawHealthBar
    then
        health.drawHealth()
    end
end

-- add health if collecting a healing powerup
function health.onNPCCollect(e, v, p)
    if e.cancelled or health.dareActive or not settings.healingPowers[v.id]
    or health.isFull() or v.data._customHealth_preventOverflow or (v.id == 249 and p.powerup > 2)
    then
        return
    end

    local oldReserve = p.reservePowerup
    local oldMuted = Audio.sounds[12].muted

    Audio.sounds[12].muted = true
    v.data._customHealth_preventOverflow = true
    v:collect(p)
    SFXPlay(settings.healSFX)

    p.reservePowerup = oldReserve
    Audio.sounds[12].muted = oldMuted

    health.add(1)
    e.cancelled = true
end

-- main stuff
function health.onPlayerHarm(e, p)
    if e.cancelled then return end
    if p.powerup > 2 and anotherPowerDown then return end

    local eventToken = {cancelled = false}

    health.onPlayerHurt(eventToken, p)

    if eventToken.cancelled then
        e.cancelled = true
        return
    end

    if p.deathTimer == 0 and (p.mount ~= MOUNT_BOOT and p.mount ~= MOUNT_YOSHI) and not p.hasStarman and health.curHealth > 0 then
        if not health.dareActive then
            if getPowerup() ~= settings.defaultPowerup then
                setPowerup(settings.defaultPowerup)
            else
                health.add(-1)
            end

            SFXPlay(settings.hurtSFX)
            p.forcedState = settings.forcedStateId
        else
            p:kill()
            health.curHealth = 0
        end

        if hurtValue.x == 0 and hurtValue.y == 0 then
            hurtValue.x = RNG.irandomEntry{-settings.shakeOffset, settings.shakeOffset}
            hurtValue.y = RNG.irandomEntry{-settings.shakeOffset, settings.shakeOffset}
        end

        Defines.earthquake = math.max(settings.quakePower, Defines.earthquake)
        e.cancelled = true
        health.onPostPlayerHurt(p)
    end
end

-- set health to 0 on death
function health.onPostPlayerKill(p)
    health.curHealth = 0
end

return health