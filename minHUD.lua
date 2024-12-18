local minHUD = {}

-- require('minHUD')
-- You'll need the above code pasted in your luna.lua file.
-- Code made by Blake Izayoi! Please give credit!

local textplus = require("textplus")
local hudoverride = require("hudoverride")
local t = 0

-- Load the shader for animated faceplates
local loopShader = Shader()
loopShader:compileFromFile(nil, Misc.resolveFile("shader_loop.frag"))

-- Star Coin related stuff
local starcoin = require("npcs/ai/starcoin") 
starcoin.getLevelList()

-- Fonts
local minFont = textplus.loadFont("minFont.ini")

local respawnRooms
pcall(function() respawnRooms = require("respawnRooms") end)
respawnRooms = respawnRooms or {}

--------------
-- Settings --
--------------

-- You can tweek some of the HUD settings here, like extra graphics and so on.

-- Set this to 1 for an image HUD bar, 2 for a color value HUD bar, 3 for an animated HUD bar.
-- If you don't have a custom image for the HUD bar, it's a better idea to use option 2.
local hudBarSet = 2

-- If you're using a color value bar, you may choose the color here, or set your own custom color.
-- 1 is black, 2 is transparent black, 3 is red, 4 is blue, 5 is green, 6 is yellow, and 7 is enabling a custom color.
local hudBarColor = 2
-- Below is where you can set a custom color. If the option above isn't 7, you can ignore this setting.
-- Don't edit the "0x". The "000000FF" is the hex value. By default, it's set to solid black.
local customColor = 0x000000FF

-- Set this to 2 or 3 for a border line underneath the HUD. This may potentially look good for certain animated / color elements.
-- 1 disables the border, 2 is for static, 3 is for a texture.
local borderEnable = 1
-- If your border is static, you can define the color of the border line here. Default is black.
local borderColor = 0x000000FF
-- Define the size of the border in pixels. Default is 2.
local borderSize = 2

-- This will determine the placement of visuals (like the death counter) on the HUD.
-- Other than the legacy setting, certain settings only look good / have no overlap with certain elements enabled / disabled.
-- All layouts are made with the drop box in mind.
-- 1 is legacy, 2 is modern.
local iconOri = 2

-- This option will display empty "zeros" for certain elements. 2 enables the feature, 1 keeps it disabled.
-- Some visual layouts are made in mind with these options being enabled.
local deathCountZD = 2
local coinCountZD = 2
local livesCountZD = 1
local scoreZD = 2
local starsZD = 2

-- If you're using an animated bar, the below two functions define how fast the texture should scroll on the X & Y axis.
-- Positive values go left / up, negative values go right / down.
local scrollDirectionX = 1
local scrollDirectionY = 1

-- Enter 2 to alter the uncollected Dragon Coin graphic to white. This is good if your HUD bar is a dark color, especially black.
local dragonAltStyle = 2

-- Enter 2 for more space between Dragon Coin graphics. Useful if you only have 3 Dragon Coins per level as opposed to 5.
local dragonExtra = 1

-- If your episode has coins, enter 1. Otherwise enter 2.
local coinCounterSet = 1

-- If your episode uses score, enter 1. Otherwise enter 2.
local scoreCounterSet = 1

-- If your episode has stars, enter 1. Otherwise enter 2.
local starCounterSet = 1

-- If you're using the built-in SMBX timer, enter 1. Otherwise enter 2.
local timeCounterSet = 2

-- Enter 2 for an alternative style for the timer graphic. Useful if you're using a dark color bar.
local timeAltStyle = 1

-- Set this to 1 for normal lives.
-- Set this to 2 to enable the death counter, a feature that tracks deaths insead of your lives.
-- Set this to 3 to have neither the lives counter or death counter display.
local livesAltStyle = 2

---------------------
-- End of settings --
---------------------

-- Initialise the death counter to 0 if it hasn't been already
SaveData.deathCount = SaveData.deathCount or 0

-- Graphics
local hudBarB = Graphics.loadImage(Misc.resolveFile("hudBarB.png"))
local hudBarA = Graphics.loadImageResolved(("hudBarA.png"))
local coinCounter = Graphics.loadImage(Misc.resolveFile("coinCounter.png"))
local lifeCounter = Graphics.loadImage(Misc.resolveFile("lifeCounter.png"))
local starCounter = Graphics.loadImage(Misc.resolveFile("starCounter.png"))
local deathCounter = Graphics.loadImage(Misc.resolveFile("deathCounter.png"))
local timeCounter = Graphics.loadImage(Misc.resolveFile("timeCounter.png"))
local timeCounterB = Graphics.loadImage(Misc.resolveFile("timeCounterB.png"))
local dragonCoinEmpty = Graphics.loadImage(Misc.resolveFile("dragonCoinEmpty.png"))
local dragonCoinEmptyB = Graphics.loadImage(Misc.resolveFile("dragonCoinEmptyB.png"))
local dragonCoinEmptyW = Graphics.loadImage(Misc.resolveFile("dragonCoinEmptyW.png"))
local dragonCoinCollect = Graphics.loadImage(Misc.resolveFile("dragonCoinCollect.png"))
local reserveBox = Graphics.loadImage(Misc.resolveFile("reserveBox.png"))
local reserveHealth = Graphics.loadImage(Misc.resolveFile("reserveHealth.png"))
local borderTexture = Graphics.loadImage(Misc.resolveFile("borderTexture.png"))

-- Item icon graphics
local reserveItem = {}

reserveItem[0] = Graphics.loadImageResolved("item1.png")

reserveItem[9] = Graphics.loadImageResolved("item2.png")
reserveItem[184] = reserveItem[9]
reserveItem[185] = reserveItem[9]
reserveItem[249] = reserveItem[9]

reserveItem[14] = Graphics.loadImageResolved("item3.png")
reserveItem[182] = reserveItem[14]
reserveItem[183] = reserveItem[14]

reserveItem[264] = Graphics.loadImageResolved("item7.png")
reserveItem[277] = reserveItem[264]

reserveItem[34] = Graphics.loadImageResolved("item4.png")
reserveItem[169] = Graphics.loadImageResolved("item5.png")
reserveItem[170] = Graphics.loadImageResolved("item6.png")

-- Defining the color codes for hudBarSet option 2
local colorStaticTable = {0x000000FF, 0x00000077, 0xFF0000FF, 0x0000FFFF, 0x00FF00FF, 0xFFFF00FF, customColor}

-- Defining if extra zeros are displayed for certain elements or not
local deathCountZeros = {"%.1d", "%.3d"}
local coinCountZeros = {"%.1d", "%.2d"}
local livesCountZeros = {"%.1d", "%.2d"}
local scoreCountZeros = {"%.1d", "%.6d"}
local starsCountZeros = {"%.1d", "%.3d"}

-- Initialize the API
function minHUD.onInitAPI()
    registerEvent(minHUD, "onPostPlayerKill")
end

-- Values for the scrolling animated texture for hudBarSet 3
local function getScrollValue()
    local x = lunatime.tick()/4 - camera.width
    local y = lunatime.tick()/4 - camera.width
    return vector(x, y)
end

function minHUD.drawHUD(camIdx,priority,isSplit)
    -- All HUD rendering goes here

    -- Base HUD Bar
    if hudBarSet == 1 then
        Graphics.drawImageWP(hudBarB, 0, 0, priority)
    elseif hudBarSet == 2 then 
        Graphics.drawBox{
            color = colorStaticTable[hudBarColor],
            x = 0, y = 0,
            width = 800,
            height = 24,
            priority = 0,
        }
    else
        Graphics.drawBox{
            texture = hudBarA,
            x = 0, y = 0,
            sourceX = (lunatime.tick()/4 - camera.width) * scrollDirectionX,
            sourceY = (lunatime.tick()/4 - camera.width) * scrollDirectionY,
            sourceWidth = camera.width,
            sourceHeight = 24,
            priority = 0,
            shader = loopShader,
        }
    end

    -- Border for HUD
    if borderEnable == 2 then
        Graphics.drawBox{
            color = borderColor,
            x = 0, y = 24,
            width = 800,
            height = borderSize,
            priority = 0,
        }
    elseif borderEnable == 3 then
        Graphics.drawBox{
            texture = borderTexture,
            x = 0, y = 24,
            sourceX = 0,
            sourceY = 0,
            sourceWidth = camera.width,
            sourceHeight = borderSize,
            priority = 0,
            shader = loopShader,
        }
    end

    -- Reserve Box / Health
    if (Graphics.getHUDType(player.character) == Graphics.HUD_ITEMBOX) then
        Graphics.drawImageWP(reserveBox, 400 - reserveBox.width*0.5, 4, priority)

        local itemImage = reserveItem[player.reservePowerup] or reserveItem[0]

        if player.reservePowerup > 0 and itemImage ~= nil then
            Graphics.drawImageWP(itemImage, 392, 4, priority)
        end
    elseif (Graphics.getHUDType(player.character) == Graphics.HUD_HEARTS) then
        local hitPoint = player:mem(0x16, FIELD_WORD)

        Graphics.drawImageWP(reserveHealth, 400 - reserveHealth.width*0.5, 4, 0, 0 + (hitPoint * 16), 58, 16, priority)
    end

    -- Coins
    if coinCounterSet == 1 then
        if iconOri == 2 then
            Graphics.drawImageWP(coinCounter, 448, 4, priority)
            textplus.print{text = string.format(coinCountZeros[coinCountZD], mem(0x00B2C5A8, FIELD_WORD)), font = minFont, priority = 5, x = 482, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        else
            Graphics.drawImageWP(coinCounter, 20, 4, priority)
            textplus.print{text = string.format(coinCountZeros[coinCountZD], mem(0x00B2C5A8, FIELD_WORD)), font = minFont, priority = 5, x = 54, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        end
    end

    -- Score
    if scoreCounterSet == 1 then
        if iconOri == 2 then
            textplus.print{text = string.format(scoreCountZeros[scoreZD], SaveData._basegame.hud.score), font = minFont, priority = 5, x = 534, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        else
            textplus.print{text = string.format(scoreCountZeros[scoreZD], SaveData._basegame.hud.score), font = minFont, priority = 5, x = 544, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        end
    end

    -- Lives or Death Counter
    if livesAltStyle == 2 then
        if iconOri == 2 then
            Graphics.drawImageWP(deathCounter, 270, 4, priority)
            textplus.print{text = string.format(deathCountZeros[deathCountZD], SaveData.deathCount), font = minFont, priority = 5, x = 304, y = 4, xscale = 2, yscale = 2}
        else
            Graphics.drawImageWP(deathCounter, 130, 4, priority)
            textplus.print{text = string.format(deathCountZeros[deathCountZD], SaveData.deathCount), font = minFont, priority = 5, x = 164, y = 4, xscale = 2, yscale = 2} 
        end
    elseif livesAltStyle == 1 then
        if iconOri == 2 then 
            Graphics.drawImageWP(lifeCounter, 270, 4, priority)
            textplus.print{text = string.format(livesCountZeros[livesCountZD], mem(0x00B2C5AC, FIELD_FLOAT)), font = minFont, priority = 5, x = 320, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        else
            Graphics.drawImageWP(lifeCounter, 114, 4, priority)
            textplus.print{text = string.format(livesCountZeros[livesCountZD], mem(0x00B2C5AC, FIELD_FLOAT)), font = minFont, priority = 5, x = 164, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        end
    end

    -- Stars
    if starCounterSet == 1 then
        if iconOri == 2 then
            Graphics.drawImageWP(starCounter, 60, 4, priority)
            textplus.print{text = string.format(starsCountZeros[starsZD],mem(0x00B251E0, FIELD_WORD)), font = minFont, priority = 5, x = 94, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        else
            Graphics.drawImageWP(starCounter, 450, 4, priority)
            textplus.print{text = string.format(starsCountZeros[starsZD],mem(0x00B251E0, FIELD_WORD)), font = minFont, priority = 5, x = 484, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        end
    end

    -- Time [SMBX Built In]
    if timeCounterSet == 1 then
        if iconOri == 2 then
            if timeAltStyle == 2 then
                Graphics.drawImageWP(timeCounterB, 650, 4, priority)
            else
                Graphics.drawImageWP(timeCounter, 650, 4, priority)
            end
            textplus.print{text = tostring(Timer.getValue()), font = minFont, priority = 5, x = 682, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        else
            if timeAltStyle == 2 then
                Graphics.drawImageWP(timeCounterB, 670, 4, priority)
            else
                Graphics.drawImageWP(timeCounter, 670, 4, priority)
            end
            textplus.print{text = tostring(Timer.getValue()), font = minFont, priority = 5, x = 702, y = 4, xscale = 2, yscale = 2, color = Color.fromHexRGBA(0xFFFFFFFF)}
        end
    end    

    -- Dragon Coins tracking
    for index,value in ipairs(starcoin.getLevelList()) do
        if value == 0 then
            if dragonAltStyle == 2 then
                if iconOri == 2 then
                    if dragonExtra == 2 then
                        Graphics.drawImageWP(dragonCoinEmptyW, 126 + (index * 36), 4, priority)
                    else
                        Graphics.drawImageWP(dragonCoinEmptyW, 144 + (index * 18), 4, priority)
                    end
                else
                    if dragonExtra == 2 then
                        Graphics.drawImageWP(dragonCoinEmptyW, 204 + (index * 36), 4, priority)
                    else
                        Graphics.drawImageWP(dragonCoinEmptyW, 204 + (index * 18), 4, priority)
                    end
                end
            else
                if iconOri == 2 then 
                    if dragonExtra == 2 then
                        Graphics.drawImageWP(dragonCoinEmptyB, 126 + (index * 36), 4, priority)
                    else
                        Graphics.drawImageWP(dragonCoinEmptyB, 144 + (index * 18), 4, priority)
                    end
                else
                    if dragonExtra == 2 then
                        Graphics.drawImageWP(dragonCoinEmptyB, 204 + (index * 36), 4, priority)
                    else
                        Graphics.drawImageWP(dragonCoinEmptyB, 204 + (index * 18), 4, priority)
                    end
                end
            end
        else
            if iconOri == 2 then
                if dragonExtra == 2 then
                    Graphics.drawImageWP(dragonCoinCollect, 126 + (index * 36), 4, priority)
                else
                    Graphics.drawImageWP(dragonCoinCollect, 144 + (index * 18), 4, priority)
                end
            else
                if dragonExtra == 2 then
                    Graphics.drawImageWP(dragonCoinCollect, 204 + (index * 36), 4, priority)
                else
                    Graphics.drawImageWP(dragonCoinCollect, 204 + (index * 18), 4, priority)
                end
            end
        end
    end
end

Graphics.overrideHUD(minHUD.drawHUD)

-- Track if the player is dying during a level exit
function minHUD.onPostPlayerKill(p) 
    SaveData.deathCount = SaveData.deathCount + 1
end

function respawnRooms.onPreReset(fromRespawn)
    if fromRespawn then
        SaveData.deathCount = SaveData.deathCount + 1
    end
end

return minHUD